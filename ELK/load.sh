#!/bin/bash

# Load environment variables from .env file if present (copy .env.example to .env to get started)
if [ -f .env ]; then
    set -a
    source .env
    set +a
fi

# ============================================================================
# CONFIGURATION SECTION - Modify these variables according to your environment
# All variables can be overridden by environment variables with the same name
# ============================================================================

# Elasticsearch connection settings
ES_URL="${ES_URL:-https://localhost:9200}"

# Authentication method: "user" or "apikey"
AUTH_METHOD="${AUTH_METHOD:-user}"

# User/Password authentication (used when AUTH_METHOD="user")
ES_USERNAME="${ES_USERNAME:-elastic}"
ES_PASSWORD="${ES_PASSWORD:-changeme}"

# API Key authentication (used when AUTH_METHOD="apikey")
ES_API_KEY="${ES_API_KEY:-}"

# SSL certificate validation: "true" to bypass SSL validation, "false" to validate
INSECURE="${INSECURE:-false}"

# What to load - Set each component to "true" to load, "false" to skip
LOAD_ECS="${LOAD_ECS:-true}"
LOAD_COMPONENT="${LOAD_COMPONENT:-true}"
LOAD_ILM="${LOAD_ILM:-true}"
LOAD_INDEX_TEMPLATES="${LOAD_INDEX_TEMPLATES:-true}"
LOAD_INGEST_PIPELINES="${LOAD_INGEST_PIPELINES:-false}"
LOAD_TRANSFORMS="${LOAD_TRANSFORMS:-false}"

# ECS version settings (only relevant if loading ECS templates)
# Leave empty to use latest version, or specify a version like "8.11.0"
ECS_VERSION="${ECS_VERSION:-}"
# Set to "true" to use existing cloned ECS repo if available
USE_EXISTING_ECS="${USE_EXISTING_ECS:-true}"

# Continue on errors - Set to "true" to continue loading other components if one fails
CONTINUE_ON_ERROR="${CONTINUE_ON_ERROR:-true}"

# Verbose mode - Set to "true" for detailed output
VERBOSE="${VERBOSE:-false}"

# ============================================================================
# END OF CONFIGURATION SECTION
# ============================================================================

echo "Welcome to the FortiDragon!"
echo -e "\nThe best analytics tool for threat hunting with Fortinet logs"

echo -e "\nHere's what this script does:"
echo "1. Clones the ECS repository from GitHub (or uses an existing clone) and loads ECS component templates into Elasticsearch."
echo "2. Loads custom component templates from 'index_templates/component_templates/' folder into Elasticsearch."
echo "3. Loads ILM (Index Lifecycle Policy) from 'index_templates/ilm/' folder into Elasticsearch."
echo "4. Loads index templates from 'index_templates/index_templates/' folder into Elasticsearch."
echo "5. Loads ingest pipelines from the 'ingest_pipelines/' folder into Elasticsearch."
echo "6. Loads transforms from the 'transforms/' folder into Elasticsearch."

# Initialize counters
TOTAL_OPERATIONS=0
SUCCESSFUL_OPERATIONS=0
FAILED_OPERATIONS=0

# Normalize boolean values to lowercase
INSECURE=$(echo "$INSECURE" | tr '[:upper:]' '[:lower:]')
LOAD_ECS=$(echo "$LOAD_ECS" | tr '[:upper:]' '[:lower:]')
LOAD_COMPONENT=$(echo "$LOAD_COMPONENT" | tr '[:upper:]' '[:lower:]')
LOAD_ILM=$(echo "$LOAD_ILM" | tr '[:upper:]' '[:lower:]')
LOAD_INDEX_TEMPLATES=$(echo "$LOAD_INDEX_TEMPLATES" | tr '[:upper:]' '[:lower:]')
LOAD_INGEST_PIPELINES=$(echo "$LOAD_INGEST_PIPELINES" | tr '[:upper:]' '[:lower:]')
LOAD_TRANSFORMS=$(echo "$LOAD_TRANSFORMS" | tr '[:upper:]' '[:lower:]')
USE_EXISTING_ECS=$(echo "$USE_EXISTING_ECS" | tr '[:upper:]' '[:lower:]')
CONTINUE_ON_ERROR=$(echo "$CONTINUE_ON_ERROR" | tr '[:upper:]' '[:lower:]')
VERBOSE=$(echo "$VERBOSE" | tr '[:upper:]' '[:lower:]')
AUTH_METHOD=$(echo "$AUTH_METHOD" | tr '[:upper:]' '[:lower:]')

# Validate configuration
if [ "$AUTH_METHOD" != "user" ] && [ "$AUTH_METHOD" != "apikey" ]; then
  echo "Error: AUTH_METHOD must be 'user' or 'apikey' (got: '$AUTH_METHOD')"
  exit 1
fi

if [ "$AUTH_METHOD" == "user" ] && ([ -z "$ES_USERNAME" ] || [ -z "$ES_PASSWORD" ]); then
  echo "Error: ES_USERNAME and ES_PASSWORD must be set when using user authentication"
  exit 1
fi

if [ "$AUTH_METHOD" == "apikey" ] && [ -z "$ES_API_KEY" ]; then
  echo "Error: ES_API_KEY must be set when using apikey authentication"
  exit 1
fi

# Set insecure flag
if [ "$INSECURE" == "true" ]; then
  insecure_flag="--insecure"
else
  insecure_flag=""
fi

# ============================================================================
# FUNCTION DEFINITIONS
# ============================================================================

# Pretty-print a JSON body, falling back to raw output if jq is unavailable
print_body() {
  local body=$1
  if command -v jq &> /dev/null && echo "$body" | jq . &> /dev/null; then
    echo "$body" | jq .
  else
    echo "$body"
  fi
}

# Build the curl auth arguments for the configured auth method
curl_auth_args() {
  if [ "$AUTH_METHOD" == "user" ]; then
    echo "--user $ES_USERNAME:$ES_PASSWORD"
  else
    echo "-H \"Authorization: ApiKey $ES_API_KEY\""
  fi
}

# Run a curl request against Elasticsearch; sets $response, $http_status, $body, $curl_exit_code
es_request() {
  local method=$1
  local endpoint=$2
  local extra_args="${@:3}"

  if [ "$AUTH_METHOD" == "user" ]; then
    response=$(curl $insecure_flag --silent --show-error --write-out "HTTPSTATUS:%{http_code}" \
      --user "$ES_USERNAME:$ES_PASSWORD" -X"$method" "$ES_URL/$endpoint" $extra_args 2>&1)
  else
    response=$(curl $insecure_flag --silent --show-error --write-out "HTTPSTATUS:%{http_code}" \
      -H "Authorization: ApiKey $ES_API_KEY" -X"$method" "$ES_URL/$endpoint" $extra_args 2>&1)
  fi
  curl_exit_code=$?

  http_status=$(echo "$response" | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
  body=$(echo "$response" | sed -e 's/HTTPSTATUS:.*//')
}

# Function to verify Elasticsearch connection
verify_connection() {
  echo "Attempting to connect to: $ES_URL"

  es_request GET ""

  if [ $curl_exit_code -ne 0 ]; then
    echo "ERROR: curl command failed with exit code: $curl_exit_code"
    echo "This usually indicates a network error, DNS resolution failure, or connection timeout."
    echo "Raw curl output:"
    echo "$response"
    exit 1
  fi

  if ! [[ "$http_status" =~ ^[0-9]+$ ]]; then
    echo "ERROR: Failed to parse HTTP status code from response"
    echo "Raw response:"
    echo "$response"
    exit 1
  fi

  if [ "$http_status" -ne 200 ]; then
    echo "Failed to connect to Elasticsearch."
    echo "HTTP Status: $http_status"
    echo -e "\nResponse body:"
    print_body "$body"
    exit 1
  else
    echo -e "Successfully connected to Elasticsearch."
    echo "HTTP Status: $http_status"
    echo -e "\nResponse body:"
    print_body "$body"
  fi
}

# Function to get the latest ECS release version
get_latest_release() {
  curl --silent "https://api.github.com/repos/elastic/ecs/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/'
}

# Function to check if the ECS repository is already cloned
check_repo_cloned() {
  if [ -d "ecs" ]; then
    echo "The ECS repository is already cloned."
    current_version=$(git -C ecs describe --tags)
    echo "Currently cloned version: $current_version"

    if [ "$USE_EXISTING_ECS" == "true" ]; then
      echo "Using existing ECS repository (USE_EXISTING_ECS=true)"
      return 0
    else
      rm -rf ecs
      echo "Existing ECS repository deleted (USE_EXISTING_ECS=false)"
      return 1
    fi
  else
    return 1
  fi
}

# Function to upload a JSON template to Elasticsearch
upload_template() {
  local file=$1
  local component_name=$2
  local api=$3
  local template_type=$4

  TOTAL_OPERATIONS=$((TOTAL_OPERATIONS + 1))

  if [ "$VERBOSE" == "true" ]; then
    echo -e "\n=========================================="
    echo "Processing: $component_name"
    echo "File: $file"
    echo "API endpoint: $ES_URL/$api"
    echo "=========================================="
  else
    echo -e "\n[$TOTAL_OPERATIONS] Processing $template_type: $component_name"
  fi

  # Check if file exists
  if [ ! -f "$file" ]; then
    echo "ERROR: File not found: $file"
    FAILED_OPERATIONS=$((FAILED_OPERATIONS + 1))
    if [ "$CONTINUE_ON_ERROR" != "true" ]; then exit 1; fi
    return 1
  fi

  # Check if file is valid JSON
  if command -v jq &> /dev/null; then
    if ! jq empty "$file" 2>/dev/null; then
      echo "ERROR: Invalid JSON in file: $file"
      FAILED_OPERATIONS=$((FAILED_OPERATIONS + 1))
      if [ "$CONTINUE_ON_ERROR" != "true" ]; then exit 1; fi
      return 1
    fi
  fi

  es_request PUT "$api" --header "Content-Type: application/json" -d @"$file"

  if [ $curl_exit_code -ne 0 ]; then
    echo "ERROR: curl command failed with exit code: $curl_exit_code"
    echo "This usually indicates a network error, DNS resolution failure, or connection timeout."
    if [ "$VERBOSE" == "true" ]; then
      echo "Raw curl output:"
      echo "$response"
    fi
    FAILED_OPERATIONS=$((FAILED_OPERATIONS + 1))
    if [ "$CONTINUE_ON_ERROR" != "true" ]; then exit 1; fi
    return 1
  fi

  if ! [[ "$http_status" =~ ^[0-9]+$ ]]; then
    echo "ERROR: Failed to parse HTTP status code from response"
    if [ "$VERBOSE" == "true" ]; then
      echo "Raw response:"
      echo "$response"
    fi
    FAILED_OPERATIONS=$((FAILED_OPERATIONS + 1))
    if [ "$CONTINUE_ON_ERROR" != "true" ]; then exit 1; fi
    return 1
  fi

  if [ "$VERBOSE" == "true" ]; then
    echo "HTTP Status: $http_status"
  fi

  if [ "$http_status" -eq 200 ]; then
    echo "✓ Successfully loaded $template_type: $component_name"
    if [ "$VERBOSE" == "true" ]; then
      print_body "$body"
    fi
    SUCCESSFUL_OPERATIONS=$((SUCCESSFUL_OPERATIONS + 1))
  else
    echo "✗ Failed to load $template_type: $component_name"
    echo "  HTTP Status: $http_status"
    echo "  Response body:"
    print_body "$body"
    FAILED_OPERATIONS=$((FAILED_OPERATIONS + 1))
    if [ "$CONTINUE_ON_ERROR" != "true" ]; then exit 1; fi
    return 1
  fi
}

# Upload all *.json files from a directory to an Elasticsearch API endpoint
# Usage: upload_dir <dir> <api_prefix> <type_label>
upload_dir() {
  local dir=$1
  local api_prefix=$2
  local type_label=$3

  if [ ! -d "$dir" ]; then
    echo "WARNING: Directory '$dir' not found. Skipping $type_label."
    return 0
  fi

  local file_count
  file_count=$(find "$dir" -maxdepth 1 -name "*.json" 2>/dev/null | wc -l)
  if [ "$file_count" -eq 0 ]; then
    echo "INFO: No JSON files found in '$dir'. Skipping."
    return 0
  fi

  for file in "$dir"/*.json; do
    local component_name
    component_name=$(basename "$file" .json)
    upload_template "$file" "$component_name" "${api_prefix}/${component_name}" "$type_label"
  done
}

# Function to upload ECS component templates
upload_ecs_templates() {
  if ! check_repo_cloned; then
    local version
    if [ -z "$ECS_VERSION" ]; then
      version=$(get_latest_release)
      echo "Latest ECS version is $version"
    else
      version="$ECS_VERSION"
    fi

    echo "Cloning the ECS repository from GitHub (version: $version)..."
    git clone --branch "$version" https://github.com/elastic/ecs.git
    if [ $? -ne 0 ]; then
      echo "Failed to clone the ECS repository. Exiting."
      exit 1
    fi
  fi

  local version
  version=$(git -C ecs describe --tags)
  echo -e "\nStarting the loading process with version: $version"

  for file in ecs/generated/elasticsearch/composable/component/*.json; do
    local fieldset
    fieldset=$(basename "$file" .json | tr '[:upper:]' '[:lower:]')
    local component_name="ecs-${fieldset}"
    upload_template "$file" "$component_name" "_component_template/${component_name}" "component template"
  done
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

echo -e "\n=== Configuration ==="
echo "Elasticsearch URL: $ES_URL"
echo "Authentication method: $AUTH_METHOD"
echo "Insecure mode: $INSECURE"
echo "Continue on error: $CONTINUE_ON_ERROR"
echo "Verbose mode: $VERBOSE"
echo "Components to load:"
echo "  - ECS templates: $LOAD_ECS"
echo "  - Component templates: $LOAD_COMPONENT"
echo "  - ILM policies: $LOAD_ILM"
echo "  - Index templates: $LOAD_INDEX_TEMPLATES"
echo "  - Ingest pipelines: $LOAD_INGEST_PIPELINES"
echo "  - Transforms: $LOAD_TRANSFORMS"
echo "====================="
echo ""

# Test credentials before proceeding
echo "=== Testing Elasticsearch Connection ==="
verify_connection
echo "========================================"
echo ""

# Check if any component is enabled for loading
if [ "$LOAD_ECS" == "false" ] && \
   [ "$LOAD_COMPONENT" == "false" ] && \
   [ "$LOAD_ILM" == "false" ] && \
   [ "$LOAD_INDEX_TEMPLATES" == "false" ] && \
   [ "$LOAD_INGEST_PIPELINES" == "false" ] && \
   [ "$LOAD_TRANSFORMS" == "false" ]; then
  echo "INFO: All LOAD_* options are set to false."
  echo "Credentials test completed successfully. Nothing to load."
  echo -e "\nBye!"
  exit 0
fi

# Load components based on configuration
if [ "$LOAD_ECS" == "true" ]; then
  echo -e "\nLoading ECS component templates..."
  upload_ecs_templates
fi

if [ "$LOAD_COMPONENT" == "true" ]; then
  echo -e "\nLoading custom component templates..."
  upload_dir "index_templates/component_templates" "_component_template" "component template"
fi

if [ "$LOAD_ILM" == "true" ]; then
  echo -e "\nLoading ILM policies..."
  upload_dir "index_templates/ilm" "_ilm/policy" "ILM policy"
fi

if [ "$LOAD_INDEX_TEMPLATES" == "true" ]; then
  echo -e "\nLoading index templates..."
  upload_dir "index_templates/index_templates" "_index_template" "index template"
fi

if [ "$LOAD_INGEST_PIPELINES" == "true" ]; then
  echo -e "\nLoading ingest pipelines..."
  upload_dir "ingest_pipelines" "_ingest/pipeline" "ingest pipeline"
fi

if [ "$LOAD_TRANSFORMS" == "true" ]; then
  echo -e "\nLoading transforms..."
  upload_dir "transforms" "_transform" "transform"
fi

echo -e "\nBye!"

# Print summary
echo -e "\n=========================================="
echo "=== EXECUTION SUMMARY ==="
echo "=========================================="
echo "Total operations attempted: $TOTAL_OPERATIONS"
echo "Successful: $SUCCESSFUL_OPERATIONS"
echo "Failed: $FAILED_OPERATIONS"
if [ $FAILED_OPERATIONS -gt 0 ]; then
  echo -e "\n⚠️  Some operations failed. Check the output above for details."
  exit 1
else
  echo -e "\n✓ All operations completed successfully!"
  exit 0
fi
