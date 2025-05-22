#!/bin/bash

# --- Configuration ---
# !!! IMPORTANT: Configure these variables !!!

# Path to the GitHub Actions workflow file you want to add to each repository.
# This script assumes the workflow file is located relative to where you run this script,
# or you can provide an absolute path.
# Example: WORKFLOW_FILE_PATH="./.github/workflows/add-issues-to-project.yml"
# Example: WORKFLOW_FILE_PATH="$HOME/gh_actions_workflows/add-issues-to-project.yml"
WORKFLOW_FILE_PATH="YOUR_PATH_TO/add-issues-to-project.yml" # Replace with the actual path

# Define the list of repositories to process.
# You can get a list of all repos for your owner (organization or user) with a command like:
# gh repo list YOUR_GITHUB_OWNER --limit 1000 --json nameWithOwner -q '.[].nameWithOwner'
REPO_LIST=(
  "YOUR_GITHUB_OWNER/YOUR_EXAMPLE_REPO_1"
  "YOUR_GITHUB_OWNER/YOUR_EXAMPLE_REPO_2"
  # Add more repositories here, e.g., "YOUR_GITHUB_OWNER/ANOTHER_REPO"
)
# --- End Configuration ---

if [ ! -f "$WORKFLOW_FILE_PATH" ]; then
    echo "Error: Workflow file not found at '$WORKFLOW_FILE_PATH'"
    echo "Please update the WORKFLOW_FILE_PATH variable in this script."
    exit 1
fi

WORKFLOW_FILE_BASENAME=$(basename "$WORKFLOW_FILE_PATH")
WORKFLOW_FILE_CONTENT=$(cat "$WORKFLOW_FILE_PATH")
WORKFLOW_DESTINATION_DIR=".github/workflows"
WORKFLOW_DESTINATION_FILE="$WORKFLOW_DESTINATION_DIR/$WORKFLOW_FILE_BASENAME"

for repo in "${REPO_LIST[@]}"; do
  echo "Processing $repo..."
  TEMP_DIR=$(mktemp -d -t ci-workflow-adder-XXXXXX)
  echo "  Cloning $repo into $TEMP_DIR..."
  # Clone only the default branch with minimal history
  if ! git clone --depth 1 "https://github.com/$repo.git" "$TEMP_DIR"; then
    echo "  Error: Failed to clone $repo. Skipping."
    rm -rf "$TEMP_DIR" # Clean up temp directory
    continue
  fi

  mkdir -p "$TEMP_DIR/$WORKFLOW_DESTINATION_DIR"
  echo "$WORKFLOW_FILE_CONTENT" > "$TEMP_DIR/$WORKFLOW_DESTINATION_FILE"
  echo "  Added/Updated workflow file at $TEMP_DIR/$WORKFLOW_DESTINATION_FILE"

  (
    cd "$TEMP_DIR" || exit # Exit subshell if cd fails

    git add "$WORKFLOW_DESTINATION_FILE"
    echo "  Staging workflow file..."

    # Check if there are changes to commit to avoid empty commits
    if ! git diff --staged --quiet; then
      COMMIT_MESSAGE="CI: Add/Update workflow '$WORKFLOW_FILE_BASENAME' to manage project issues"
      echo "  Committing with message: '$COMMIT_MESSAGE'..."
      git commit -m "$COMMIT_MESSAGE"
      echo "  Pushing changes to $repo..."
      if ! git push; then
        echo "  Error: Failed to push changes to $repo. Check permissions or remote status."
      else
        echo "  Successfully pushed changes to $repo."
      fi
    else
      echo "  No changes to commit for workflow file in $repo. It might be identical or already staged."
    fi
  )

  echo "  Cleaning up temporary directory $TEMP_DIR..."
  rm -rf "$TEMP_DIR"
  echo "  Finished processing $repo."
  echo "---"
done

echo "Batch script finished."
