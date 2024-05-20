#!/bin/bash

echo "This script clones the ECS (Elastic Common Schema) repository and loads component templates into your Elasticsearch instance."

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
  fi
}


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

# Proceed with updating component templates
version=$(git -C ecs describe --tags)
echo -e "\nStarting the update process with version: $version"
# Add the update process here...

# Get user input
get_user_input

version="$(cat ecs/version)"
echo -e "\nStarting the update process with version: $version"

for file in ecs/generated/elasticsearch/composable/component/*.json
do
  fieldset=$(basename "$file" .json | tr '[:upper:]' '[:lower:]')
  component_name="ecs-${fieldset}"
  api="_component_template/${component_name}"

  echo -e "\nProcessing file: $file"
  echo "Target API endpoint: $url/$api"

  if [ "$auth_choice" == "u" ]; then
    response=$(curl --silent --write-out "HTTPSTATUS:%{http_code}" --user "$username:$password" -XPUT "$url/$api" --header "Content-Type: application/json" -d @"$file")
  elif [ "$auth_choice" == "a" ]; then
    response=$(curl --silent --write-out "HTTPSTATUS:%{http_code}" -H "Authorization: ApiKey $api_key" -XPUT "$url/$api" --header "Content-Type: application/json" -d @"$file")
  fi

  http_status=$(echo $response | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
  body=$(echo $response | sed -e 's/HTTPSTATUS:.*//')

  if [ "$http_status" -eq 200 ]; then
    if echo $body | grep -q '"acknowledged":true'; then
      echo -e "Successfully updated component template: $component_name\nAcknowledgment: true"
    else
      echo -e "Successfully updated component template: $component_name\nAcknowledgment: false"
    fi
  else
    echo -e "Failed to update component template: $component_name\nHTTP status: $http_status\nResponse body: $body"
  fi
done

echo -e "\nUpdate process completed."


