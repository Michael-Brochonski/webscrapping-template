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

# Function to check if a branch is within the 3-month range
is_branch_within_range() {
    local branch_date="$1"
    local recent_date="$2"
    local max_diff=$((60*60*24*30*3)) # 3 months in seconds
    local diff=$((recent_date - branch_date))
    [ $diff -le $max_diff ]
}

# Clone or update projects and find PDFs
echo "$PROJECTS" | jq -r '.[].http_url_to_repo' | while read repo; do
    # Modify the HTTPS URL to include the access token for authentication
    repo_with_token=$(echo $repo | sed "s|https://|https://oauth2:$ACCESS_TOKEN@|")

    # Extract project name
    project_name=$(basename $repo .git)

    # Check if the project directory exists
    if [ -d "$project_name" ]; then
        # Update the repository
        (cd "$project_name" && git pull)
    else
        # Clone the project using the modified HTTPS URL with disabled SSL verification
        GIT_SSL_NO_VERIFY=true git clone $repo_with_token $project_name
    fi

    # Check if git operation was successful
    if [ $? -ne 0 ]; then
        echo "Failed to operate on repository: $repo"
        continue
    fi

    # Get the most recent branch date in Unix timestamp
    recent_branch_date=$(cd "$project_name" && git for-each-ref --sort=-committerdate --format='%(committerdate:unix)' refs/heads | head -n 1)

    # Get all branches up to 3 months older than the most recent branch
    branches=$(cd "$project_name" && git for-each-ref --sort=-committerdate --format='%(committerdate:unix) %(refname:short)' refs/heads | while read branch_date branch_name; do
        if is_branch_within_range "$branch_date" "$recent_branch_date"; then
            echo "$branch_name"
        fi
    done)

    # Checkout each branch and copy PDF files
    for branch in $branches; do
        (cd "$project_name" && git checkout "$branch" && find . -name '*.pdf' -exec cp {} "$DEST_FOLDER" \;)
    done
done

echo "PDF extraction complete. Check your destination folder: $DEST_FOLDER"