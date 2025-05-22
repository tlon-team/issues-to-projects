#!/bin/bash

# --- Configuration ---
# !!! IMPORTANT: Configure these variables !!!

# Path to the GitHub Actions workflow file you want to add to each repository.
# This script assumes the workflow file is located relative to where you run this script,
# or you can provide an absolute path.
# Example: WORKFLOW_FILE_PATH="./.github/workflows/add-issues-to-project.yml"
# Source the central configuration file
CONFIG_FILE_PATH="$(dirname "$0")/config.sh"
if [ -f "$CONFIG_FILE_PATH" ]; then
    source "$CONFIG_FILE_PATH"
else
    echo "Error: Configuration file config.sh not found in the script's directory." >&2
    echo "Please create it (e.g., from config.sh.example) and configure your variables." >&2
    exit 1
fi

# --- Initial Checks and Repo List Population ---
# Variables are now sourced from config.sh

# OWNER_NAME must be set correctly in config.sh
if [ "$OWNER_NAME" == "YOUR_GITHUB_OWNER" ] || [ -z "$OWNER_NAME" ]; then
    echo "Error: OWNER_NAME is not configured in config.sh or is still set to the placeholder 'YOUR_GITHUB_OWNER'." >&2
    echo "Please update config.sh." >&2
    exit 1
fi

# WORKFLOW_FILE_PATH must be set correctly in config.sh and the file must exist
if [ "$WORKFLOW_FILE_PATH" == "YOUR_PATH_TO/add-issues-to-project.yml" ] || [ -z "$WORKFLOW_FILE_PATH" ]; then
    echo "Error: WORKFLOW_FILE_PATH is not configured in config.sh or is still set to the placeholder." >&2
    echo "Please update config.sh." >&2
    exit 1
elif [ ! -f "$WORKFLOW_FILE_PATH" ]; then
    echo "Error: Workflow file specified in config.sh not found at: '$WORKFLOW_FILE_PATH'" >&2
    exit 1
fi

ACTUAL_REPO_LIST=()

if [ ${#REPO_LIST[@]} -eq 0 ]; then
    echo "REPO_LIST is empty. Fetching all repositories for owner $OWNER_NAME..."
    ALL_REPOS_OUTPUT=$(gh repo list "$OWNER_NAME" --limit 2000 --json nameWithOwner -q '.[] | .nameWithOwner' 2>&1)
    GH_EXIT_CODE=$?
    if [ $GH_EXIT_CODE -ne 0 ] || [[ "$ALL_REPOS_OUTPUT" == *"Could not resolve"* || "$ALL_REPOS_OUTPUT" == *"HTTP"* ]]; then
        echo "  ERROR: Failed to fetch repositories for owner '$OWNER_NAME'. Exit code: $GH_EXIT_CODE. Output: $ALL_REPOS_OUTPUT" >&2
        exit 1
    fi

    TEMP_REPO_LIST=()
    while IFS= read -r repo_line; do
        if [[ -n "$repo_line" ]]; then
            TEMP_REPO_LIST+=("$repo_line")
        fi
    done < <(echo "$ALL_REPOS_OUTPUT")

    if [ ${#TEMP_REPO_LIST[@]} -eq 0 ]; then
        echo "No repositories found for owner $OWNER_NAME. Exiting."
        exit 0
    else
        ACTUAL_REPO_LIST=("${TEMP_REPO_LIST[@]}") # These are already full names
        echo "Successfully fetched ${#ACTUAL_REPO_LIST[@]} repositories for owner $OWNER_NAME."
    fi
else # REPO_LIST is not empty, user provided short names
    echo "Processing ${#REPO_LIST[@]} repository names specified in REPO_LIST for owner $OWNER_NAME."
    for short_repo_name in "${REPO_LIST[@]}"; do
        ACTUAL_REPO_LIST+=("$OWNER_NAME/$short_repo_name")
    done
fi

if [ ${#ACTUAL_REPO_LIST[@]} -eq 0 ]; then
    echo "Error: No repositories to process after checking REPO_LIST and fetching." >&2
    exit 1
fi

# The check for WORKFLOW_FILE_PATH existence is now part of the initial checks above.

WORKFLOW_FILE_BASENAME=$(basename "$WORKFLOW_FILE_PATH")
WORKFLOW_FILE_CONTENT=$(cat "$WORKFLOW_FILE_PATH")
WORKFLOW_DESTINATION_DIR=".github/workflows"
WORKFLOW_DESTINATION_FILE="$WORKFLOW_DESTINATION_DIR/$WORKFLOW_FILE_BASENAME"

for repo_full_name in "${ACTUAL_REPO_LIST[@]}"; do
  echo "Processing $repo_full_name..."
  TEMP_DIR=$(mktemp -d -t ci-workflow-adder-XXXXXX)
  echo "  Cloning $repo_full_name into $TEMP_DIR..."
  # Clone only the default branch with minimal history
  if ! git clone --depth 1 "https://github.com/$repo_full_name.git" "$TEMP_DIR"; then
    echo "  Error: Failed to clone $repo_full_name. Skipping."
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
      echo "  Pushing changes to $repo_full_name..."
      if ! git push; then
        echo "  Error: Failed to push changes to $repo_full_name. Check permissions or remote status."
      else
        echo "  Successfully pushed changes to $repo_full_name."
      fi
    else
      echo "  No changes to commit for workflow file in $repo_full_name. It might be identical or already staged."
    fi
  )

  echo "  Cleaning up temporary directory $TEMP_DIR..."
  rm -rf "$TEMP_DIR"
  echo "  Finished processing $repo_full_name."
  echo "---"
done

echo "Batch script finished."
