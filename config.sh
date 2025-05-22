#!/bin/bash

# -----------------------------------------------------------------------------
# Central Configuration for GitHub Project Automation Scripts
# -----------------------------------------------------------------------------
# Instructions:
# 1. After this file is created, consider copying it to `config.sh.example`
#    to serve as a template (config.sh.example should be committed,
#    config.sh should be in .gitignore).
# 2. Replace the placeholder values below with your actual GitHub information.
# -----------------------------------------------------------------------------

# --- General GitHub Settings ---

# Your GitHub username or organization name.
# Example: OWNER_NAME="my-github-username"
# Example: OWNER_NAME="my-cool-organization"
OWNER_NAME="YOUR_GITHUB_OWNER"

# The project number (not the Node ID) of your GitHub project.
# Used by: add-all-existing-issues-to-project.sh, categorize-project-items.sh
# Example: PROJECT_NUMBER="123"
PROJECT_NUMBER="YOUR_PROJECT_NUMBER"

# --- Repository List ---

# The list of repos that you want the scripts to operate on. If empty, all repos in OWNER_NAME will be considered.
# List repos by their name only, e.g. if the URL is https://github.com/OWNER_NAME/my-repo, you should use "my-repo".
# Example: REPO_LIST=("my-first-repo" "another-project-repo")
REPO_LIST=(
  # "YOUR_EXAMPLE_REPO_1"
  # "YOUR_EXAMPLE_REPO_2"
  # Add more repository names here
)

# --- automate-github-secrets.sh Specific ---

# Your GitHub Personal Access Token (PAT) with 'repo', 'project', and 'workflow' scopes.
# This is used to set secrets in your repositories for GitHub Actions.
# Example: PAT_VALUE="ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
PAT_VALUE="YOUR_GITHUB_PAT"

# --- batch-deploy-add-new-issues-workflow.sh Specific ---

# Path to the GitHub Actions workflow file (e.g., add-issues-to-project.yml) you want to deploy.
# Example: WORKFLOW_FILE_PATH="./add-issues-to-project.yml" # If in the same directory
# Example: WORKFLOW_FILE_PATH="$HOME/gh_actions_workflows/add-issues-to-project.yml"
WORKFLOW_FILE_PATH="YOUR_PATH_TO/add-issues-to-project.yml"

# --- categorize-project-items.sh Specific ---

# The name of the status option in your project for OPEN issues.
# Example: OPEN_ISSUE_STATUS="To Do"
# Example: OPEN_ISSUE_STATUS="Backlog"
OPEN_ISSUE_STATUS="Todo"

# The name of the status option in your project for CLOSED issues.
# Example: CLOSED_ISSUE_STATUS="Done"
# Example: CLOSED_ISSUE_STATUS="Completed"
CLOSED_ISSUE_STATUS="Done"

# --- End of Configuration ---

# Ensure script is being sourced.
# This check prevents direct execution of the config file.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This script (config.sh) is meant to be sourced, not executed directly." >&2
    exit 1
fi
