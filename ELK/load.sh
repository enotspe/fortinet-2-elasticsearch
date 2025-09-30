#!/bin/bash

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

# Test mode - Set to "true" to only test credentials without loading anything
TEST_CREDENTIALS="${TEST_CREDENTIALS:-false}"

# What to load - Set each component to "true" to load, "false" to skip
# Note: These are ignored if TEST_CREDENTIALS="true"
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
TEST_CREDENTIALS=$(echo "$TEST_CREDENTIALS" | tr '[:upper:]' '[:lower:]')
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

echo -e "\n=== Configuration ==="
echo "Elasticsearch URL: $ES_URL"
echo "Authentication method: $AUTH_METHOD"
echo "Insecure mode: $INSECURE"
echo "Continue on error: $CONTINUE_ON_ERROR"
echo "Verbose mode: $VERBOSE"
if [ "$TEST_CREDENTIALS" == "true" ]; then
  echo "Mode: TEST CREDENTIALS ONLY"
else
  echo "Components to load:"
  echo "  - ECS templates: $LOAD_ECS"
  echo "  - Component templates: $LOAD_COMPONENT"
  echo "  - ILM policies: $LOAD_ILM"
  echo "  - Index templates: $LOAD_INDEX_TEMPLATES"
  echo "  - Ingest pipelines: $LOAD_INGEST_PIPELINES"
  echo "  - Transforms: $LOAD_TRANSFORMS"
fi
echo "=====================\n"

# Function to verify Elasticsearch connection
verify_connection() {
  echo "Attempting to connect to: $ES_URL"

  if [ "$AUTH_METHOD" == "user" ]; then
    response=$(curl $insecure_flag --silent --show-error --write-out "HTTPSTATUS:%{http_code}" --user "$ES_USERNAME:$ES_PASSWORD" -XGET "$ES_URL" 2>&1)
    curl_exit_code=$?
  elif [ "$AUTH_METHOD" == "apikey" ]; then
    response=$(curl $insecure_flag --silent --show-error --write-out "HTTPSTATUS:%{http_code}" -H "Authorization: ApiKey $ES_API_KEY" -XGET "$ES_URL" 2>&1)
    curl_exit_code=$?
  fi

  # Check if curl command itself failed
  if [ $curl_exit_code -ne 0 ]; then
    echo "ERROR: curl command failed with exit code: $curl_exit_code"
    echo "This usually indicates a network error, DNS resolution failure, or connection timeout."
    echo "Raw curl output:"
    echo "$response"
    exit 1
  fi

  http_status=$(echo $response | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
  body=$(echo $response | sed -e 's/HTTPSTATUS:.*//')

  # Check if we got a valid HTTP status code
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
    if command -v jq &> /dev/null && echo "$body" | jq . &> /dev/null; then
      echo "$body" | jq .
    else
      echo "$body"
    fi
    exit 1
  else
    echo -e "Successfully connected to Elasticsearch."
    echo "HTTP Status: $http_status"
    echo -e "\nResponse body:"
    if command -v jq &> /dev/null && echo "$body" | jq . &> /dev/null; then
      echo "$body" | jq .
    else
      echo "$body"
    fi
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
    if [ "$CONTINUE_ON_ERROR" != "true" ]; then
      exit 1
    fi
    return 1
  fi

  # Check if file is valid JSON
  if command -v jq &> /dev/null; then
    if ! jq empty "$file" 2>/dev/null; then
      echo "ERROR: Invalid JSON in file: $file"
      FAILED_OPERATIONS=$((FAILED_OPERATIONS + 1))
      if [ "$CONTINUE_ON_ERROR" != "true" ]; then
        exit 1
      fi
      return 1
    fi
  fi

  if [ "$AUTH_METHOD" == "user" ]; then
    response=$(curl $insecure_flag --silent --show-error --write-out "HTTPSTATUS:%{http_code}" --user "$ES_USERNAME:$ES_PASSWORD" -XPUT "$ES_URL/$api" --header "Content-Type: application/json" -d @"$file" 2>&1)
    curl_exit_code=$?
  elif [ "$AUTH_METHOD" == "apikey" ]; then
    response=$(curl $insecure_flag --silent --show-error --write-out "HTTPSTATUS:%{http_code}" -H "Authorization: ApiKey $ES_API_KEY" -XPUT "$ES_URL/$api" --header "Content-Type: application/json" -d @"$file" 2>&1)
    curl_exit_code=$?
  fi

  # Check if curl command itself failed
  if [ $curl_exit_code -ne 0 ]; then
    echo "ERROR: curl command failed with exit code: $curl_exit_code"
    echo "This usually indicates a network error, DNS resolution failure, or connection timeout."
    if [ "$VERBOSE" == "true" ]; then
      echo "Raw curl output:"
      echo "$response"
    fi
    FAILED_OPERATIONS=$((FAILED_OPERATIONS + 1))
    if [ "$CONTINUE_ON_ERROR" != "true" ]; then
      exit 1
    fi
    return 1
  fi

  http_status=$(echo $response | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
  body=$(echo $response | sed -e 's/HTTPSTATUS:.*//')

  # Check if we got a valid HTTP status code
  if ! [[ "$http_status" =~ ^[0-9]+$ ]]; then
    echo "ERROR: Failed to parse HTTP status code from response"
    if [ "$VERBOSE" == "true" ]; then
      echo "Raw response:"
      echo "$response"
    fi
    FAILED_OPERATIONS=$((FAILED_OPERATIONS + 1))
    if [ "$CONTINUE_ON_ERROR" != "true" ]; then
      exit 1
    fi
    return 1
  fi

  if [ "$VERBOSE" == "true" ]; then
    echo "HTTP Status: $http_status"
  fi

  if [ "$http_status" -eq 200 ]; then
    if echo $body | grep -q '"acknowledged":true'; then
      echo "✓ Successfully loaded $template_type: $component_name"
      if [ "$VERBOSE" == "true" ]; then
        echo "  Acknowledgment: true"
      fi
    else
      echo "✓ Successfully loaded $template_type: $component_name"
      if [ "$VERBOSE" == "true" ]; then
        echo "  Acknowledgment: false"
        echo "  Response body:"
        if command -v jq &> /dev/null && echo "$body" | jq . &> /dev/null; then
          echo "$body" | jq .
        else
          echo "$body"
        fi
      fi
    fi
    SUCCESSFUL_OPERATIONS=$((SUCCESSFUL_OPERATIONS + 1))
  else
    echo "✗ Failed to load $template_type: $component_name"
    echo "  HTTP Status: $http_status"
    echo "  Response body:"
    if command -v jq &> /dev/null && echo "$body" | jq . &> /dev/null; then
      echo "$body" | jq .
    else
      echo "$body"
    fi
    FAILED_OPERATIONS=$((FAILED_OPERATIONS + 1))
    if [ "$CONTINUE_ON_ERROR" != "true" ]; then
      exit 1
    fi
    return 1
  fi
}

# Function to upload ECS component templates
upload_ecs_templates() {
  # Check if the ECS repository is already cloned
  check_repo_cloned
  if [ $? -ne 0 ]; then
    # Get the version to use
    if [ -z "$ECS_VERSION" ]; then
      latest_version=$(get_latest_release)
      echo "Latest ECS version is $latest_version"
      version="$latest_version"
    else
      version="$ECS_VERSION"
    fi

    # Clone the ECS repository
    echo "Cloning the ECS repository from GitHub (version: $version)..."
    git clone --branch "$version" https://github.com/elastic/ecs.git
    if [ $? -ne 0 ]; then
      echo "Failed to clone the ECS repository. Exiting."
      exit 1
    fi
  fi

  version=$(git -C ecs describe --tags)
  echo -e "\nStarting the loading process with version: $version"

  for file in ecs/generated/elasticsearch/composable/component/*.json
  do
    fieldset=$(basename "$file" .json | tr '[:upper:]' '[:lower:]')
    component_name="ecs-${fieldset}"
    api="_component_template/${component_name}"
    upload_template "$file" "$component_name" "$api" "component template"
  done
}

# Upload additional component templates from index_templates/component_templates/
upload_component_templates() {
  if [ ! -d "index_templates/component_templates" ]; then
    echo "WARNING: Directory 'index_templates/component_templates' not found. Skipping component templates."
    return 0
  fi

  local file_count=$(find index_templates/component_templates -maxdepth 1 -name "*.json" 2>/dev/null | wc -l)
  if [ "$file_count" -eq 0 ]; then
    echo "INFO: No JSON files found in 'index_templates/component_templates'. Skipping."
    return 0
  fi

  for file in index_templates/component_templates/*.json
  do
    component_name=$(basename "$file" .json)
    api="_component_template/${component_name}"
    upload_template "$file" "$component_name" "$api" "component template"
  done
}

# Upload ilm policies from index_templates/ilm/
upload_ilm() {
  if [ ! -d "index_templates/ilm" ]; then
    echo "WARNING: Directory 'index_templates/ilm' not found. Skipping ILM policies."
    return 0
  fi

  local file_count=$(find index_templates/ilm -maxdepth 1 -name "*.json" 2>/dev/null | wc -l)
  if [ "$file_count" -eq 0 ]; then
    echo "INFO: No JSON files found in 'index_templates/ilm'. Skipping."
    return 0
  fi

  for file in index_templates/ilm/*.json
  do
    component_name=$(basename "$file" .json)
    api="_ilm/policy/${component_name}"
    upload_template "$file" "$component_name" "$api" "ILM policy"
  done
}

# Upload index templates from index_templates/index_templates/
upload_index_templates() {
  if [ ! -d "index_templates/index_templates" ]; then
    echo "WARNING: Directory 'index_templates/index_templates' not found. Skipping index templates."
    return 0
  fi

  local file_count=$(find index_templates/index_templates -maxdepth 1 -name "*.json" 2>/dev/null | wc -l)
  if [ "$file_count" -eq 0 ]; then
    echo "INFO: No JSON files found in 'index_templates/index_templates'. Skipping."
    return 0
  fi

  for file in index_templates/index_templates/*.json
  do
    component_name=$(basename "$file" .json)
    api="_index_template/${component_name}"
    upload_template "$file" "$component_name" "$api" "index template"
  done
}

# Upload ingest pipelines from ingest_pipelines/
upload_ingest_pipelines() {
  if [ ! -d "ingest_pipelines" ]; then
    echo "WARNING: Directory 'ingest_pipelines' not found. Skipping ingest pipelines."
    return 0
  fi

  local file_count=$(find ingest_pipelines -maxdepth 1 -name "*.json" 2>/dev/null | wc -l)
  if [ "$file_count" -eq 0 ]; then
    echo "INFO: No JSON files found in 'ingest_pipelines'. Skipping."
    return 0
  fi

  for file in ingest_pipelines/*.json
  do
    component_name=$(basename "$file" .json)
    api="_ingest/pipeline/${component_name}"
    upload_template "$file" "$component_name" "$api" "ingest pipeline"
  done
}

# Upload transforms from transforms/
upload_transforms() {
  if [ ! -d "transforms" ]; then
    echo "WARNING: Directory 'transforms' not found. Skipping transforms."
    return 0
  fi

  local file_count=$(find transforms -maxdepth 1 -name "*.json" 2>/dev/null | wc -l)
  if [ "$file_count" -eq 0 ]; then
    echo "INFO: No JSON files found in 'transforms'. Skipping."
    return 0
  fi

  for file in transforms/*.json
  do
    component_name=$(basename "$file" .json)
    api="_transform/${component_name}"
    upload_template "$file" "$component_name" "$api" "transforms"
  done
}

# Test credentials mode - skip all loading if enabled
if [ "$TEST_CREDENTIALS" == "true" ]; then
  echo -e "\n=== TEST CREDENTIALS MODE ==="
  echo "Testing connection to Elasticsearch..."
  verify_connection
  echo -e "\nCredentials test completed. Exiting without loading any components."
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
  upload_component_templates
fi

if [ "$LOAD_ILM" == "true" ]; then
  echo -e "\nLoading ILM policies..."
  upload_ilm
fi

if [ "$LOAD_INDEX_TEMPLATES" == "true" ]; then
  echo -e "\nLoading index templates..."
  upload_index_templates
fi

if [ "$LOAD_INGEST_PIPELINES" == "true" ]; then
  echo -e "\nLoading ingest pipelines..."
  upload_ingest_pipelines
fi

if [ "$LOAD_TRANSFORMS" == "true" ]; then
  echo -e "\nLoading transforms..."
  upload_transforms
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
