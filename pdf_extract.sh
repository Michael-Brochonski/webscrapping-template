#!/bin/bash

# GitLab Instance, Group ID, and Access Token
GITLAB_INSTANCE="gratgl01.dev.global-intra.net"
GROUP_ID="78" # Group ID for the 'Documentation' group
ACCESS_TOKEN="my-token" # Replace with your actual access token

# Correct the destination folder path
DEST_FOLDER="/c/gitlab/pdf_extract/kb" # Replace with your destination folder path

# Create the destination folder if it does not exist
mkdir -p "$DEST_FOLDER"

# API Call to get list of projects in the group
PROJECTS=$(curl --insecure --header "PRIVATE-TOKEN: $ACCESS_TOKEN" "https://$GITLAB_INSTANCE/api/v4/groups/$GROUP_ID/projects")

# Check if curl command was successful
if [ $? -ne 0 ]; then
    echo "Failed to fetch projects. Please check your GitLab instance URL and access token."
    exit 1
fi

# Clone projects and find PDFs
echo "$PROJECTS" | jq -r '.[].http_url_to_repo' | while read repo; do
    # Modify the HTTPS URL to include the access token for authentication
    repo_with_token=$(echo $repo | sed "s|https://|https://oauth2:$ACCESS_TOKEN@|")

    # Extract project name
    project_name=$(basename $repo .git)

    # Clone the project using the modified HTTPS URL with disabled SSL verification
    GIT_SSL_NO_VERIFY=true git clone $repo_with_token $project_name

    # Check if git clone was successful
    if [ $? -ne 0 ]; then
        echo "Failed to clone repository: $repo"
        continue
    fi

    # Find and copy PDF files
    find $project_name -name '*.pdf' -exec cp {} "$DEST_FOLDER" \;
done

echo "PDF extraction complete. Check your destination folder: $DEST_FOLDER"