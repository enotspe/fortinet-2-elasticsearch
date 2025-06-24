#!/bin/bash

echo "Welcome to the FortiDragon!"
echo -e "\nThe best analytics tool for threat hunting with Foritnet logs"

echo -e "\nHere's what this script does:"
echo "1. Clones the ECS repository from GitHub (or uses an existing clone) and loads ECS component templates into Elasticsearch."
echo "2. Loads custom Fortinet component templates from 'index_templates/component_templates/' folder into Elasticsearch."
echo "3. Loads ILM (Index Lyfecycle Policy) from 'index_templates/ilm/' folder into Elasticsearch."
echo "4. Loads index templates from 'index_templates/index_templates/' folder into Elasticsearch."
echo "5. Loads ingest pipelines from the 'index_templates/component_templates/' folder into Elasticsearch."
echo "6. Loads transforms from the 'index_templates/component_templates/' folder into Elasticsearch."

echo -e "\nPlease choose an option from the menu:"
echo "1. Load all components."
echo "2. Load only ECS component templates."
echo "3. Load only custom Fortinet component templates."
echo "4. Load only ILM (Index Lyfecycle Policy)."
echo "5. Load only index templates."
echo "6. Load only ingest pipelines."
echo "7. Load only transforms."
echo "8. Test ES credentials."


read -p "Enter your choice (1/2/3/4/5/6/7/8): " load_choice

# Function to get input from the user
get_user_input() {
  echo "Enter the details for Elasticsearch connection."
  read -p "Elasticsearch URL: " url

  echo "Choose the authentication method:"
  echo "  u) User/Password"
  echo "  a) API Key"
  read -p "Authentication method (u/a): " auth_choice
  auth_choice=$(echo "$auth_choice" | tr '[:upper:]' '[:lower:]')


  if [ "$auth_choice" == "u" ]; then
    read -p "Username: " username
    read -sp "Password: " password
    echo
  elif [ "$auth_choice" == "a" ]; then
    read -p "Please enter your API key: " api_key
  else
    echo "Invalid choice. Please enter 'u' for user/pass or 'a' for API key."
    exit 1
  fi

  echo "Do you want to add the --insecure flag to bypass SSL certificate validation? (y/n)"
  read -p "Enter your choice: " insecure_choice
  insecure_choice=$(echo "$insecure_choice" | tr '[:upper:]' '[:lower:]')

  if [ "$insecure_choice" == "y" ]; then
    insecure_flag="--insecure"
  else
    insecure_flag=""
  fi
}

# Function to verify Elasticsearch connection
verify_connection() {
  if [ "$auth_choice" == "u" ]; then
    response=$(curl $insecure_flag --silent --write-out "HTTPSTATUS:%{http_code}" --user "$username:$password" -XGET "$url")
  elif [ "$auth_choice" == "a" ]; then
    response=$(curl $insecure_flag --silent --write-out "HTTPSTATUS:%{http_code}" -H "Authorization: ApiKey $api_key" -XGET "$url")
  fi

  http_status=$(echo $response | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
  body=$(echo $response | sed -e 's/HTTPSTATUS:.*//')

  if [ "$http_status" -ne 200 ]; then
    echo "Failed to connect to Elasticsearch. Please check your credentials and try again."
    echo -e "Response body:"
    echo "$body" | jq .
    exit 1
  else
    echo -e "Successfully connected to Elasticsearch."
    echo -e "Response body:"
    echo "$body" | jq .
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
    read -p "Do you want to use this version? (y/n): " use_current_version
    use_current_version=$(echo "$use_current_version" | tr '[:upper:]' '[:lower:]')

    if [ "$use_current_version" != "y" ]; then
      rm -rf ecs
      echo "Existing ECS repository deleted."
      return 1
    else
      return 0
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

  echo -e "\nProcessing file: $file"
  echo "Target API endpoint: $url/$api"

  if [ "$auth_choice" == "u" ]; then
    response=$(curl $insecure_flag --silent --write-out "HTTPSTATUS:%{http_code}" --user "$username:$password" -XPUT "$url/$api" --header "Content-Type: application/json" -d @"$file")
  elif [ "$auth_choice" == "a" ]; then
    response=$(curl $insecure_flag --silent --write-out "HTTPSTATUS:%{http_code}" -H "Authorization: ApiKey $api_key" -XPUT "$url/$api" --header "Content-Type: application/json" -d @"$file")
  fi

  http_status=$(echo $response | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
  body=$(echo $response | sed -e 's/HTTPSTATUS:.*//')

  if [ "$http_status" -eq 200 ]; then
    if echo $body | grep -q '"acknowledged":true'; then
      echo -e "Successfully loaded $template_type: $component_name\nAcknowledgment: true"
    else
      echo -e "Successfully loaded $template_type: $component_name\nAcknowledgment: false"
    fi
  else
    echo -e "Failed to load $template_type: $component_name"
    echo -e "HTTP status: $http_status"
    echo -e "Response body:"
    echo "$body" | jq .
  fi
}

# Function to upload ECS component templates
upload_ecs_templates() {

# Check if the ECS repository is already cloned
check_repo_cloned
if [ $? -ne 0 ]; then
  # Get the latest release version
  latest_version=$(get_latest_release)
  echo "Latest ECS version is $latest_version"
  read -p "Enter the ECS version to clone (default is latest): " version
  version=${version:-$latest_version}

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
upload_fortinet_templates() {
for file in index_templates/component_templates/*.json
do
  component_name=$(basename "$file" .json)
  api="_component_template/${component_name}"
  upload_template "$file" "$component_name" "$api" "component template"
done
}

# Upload ilm policies from index_templates/ilm/
upload_ilm() {
for file in index_templates/ilm/*.json
do
  component_name=$(basename "$file" .json)
  api="_ilm/policy/${component_name}"
  upload_template "$file" "$component_name" "$api" "ILM policy"
done
}

# Upload index templates from index_templates/index_templates/
upload_index_templates() {
for file in index_templates/index_templates/*.json
do
  component_name=$(basename "$file" .json)
  api="_index_template/${component_name}"
  upload_template "$file" "$component_name" "$api" "index template"
done
}

# Upload ingest pipelines from ingest_pipelines/
upload_ingest_pipelines() {
for file in ingest_pipelines/*.json
do
  component_name=$(basename "$file" .json)
  api="_ingest/pipeline/${component_name}"
  upload_template "$file" "$component_name" "$api" "ingest pipeline"
done
}

# Upload transforms from transforms/
upload_transforms() {
for file in transforms/*.json
do
  component_name=$(basename "$file" .json)
  api="_transform/${component_name}"
  upload_template "$file" "$component_name" "$api" "transforms"
done
}


# Get user input
get_user_input

# Verify Elasticsearch connection
#verify_connection

# Load templates based on user choice
case $load_choice in
  1)
    echo -e "\nLoading all components"
    upload_ecs_templates
    upload_fortinet_templates
    upload_ilm
    upload_index_templates
    upload_ingest_pipelines
    upload_transforms
    ;;
  2)
    echo -e "\nLoading only ECS component templates..."
    upload_ecs_templates
    ;;
  3)
    echo -e "\nLoading only custom Fortinet component templates..."
    upload_fortinet_templates
    ;;
  4)
    echo -e "\nLoading only ILM..."
    upload_ilm
    ;;
  5)
    echo -e "\nLoading only index templates..."
    upload_index_templates
    ;;
  6)
    echo -e "\nLoading only ingest pipelines..."
    upload_ingest_pipelines
    ;;
  7)
    echo -e "\nLoading only transforms..."
    upload_transforms
    ;;
  8)
    echo -e "\nVerifying credentials..."
    verify_connection
    ;;
  *)
    echo "Invalid choice. Exiting."
    exit 1
    ;;
esac

echo -e "\Bye!"

