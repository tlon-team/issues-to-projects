#!/bin/bash
# You can get a list of all repos for your owner (organization or user) with a command like:
# gh repo list YOUR_GITHUB_OWNER --limit 1000 --json nameWithOwner -q '.[].nameWithOwner'

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

# PAT_VALUE must be set correctly in config.sh
if [ "$PAT_VALUE" == "YOUR_GITHUB_PAT" ] || [ -z "$PAT_VALUE" ]; then
    echo "Error: PAT_VALUE is not configured in config.sh or is still set to the placeholder 'YOUR_GITHUB_PAT'." >&2
    echo "Please update config.sh." >&2
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

for repo_full_name in "${ACTUAL_REPO_LIST[@]}"; do
  echo "Setting secret ADD_TO_PROJECT_PAT for repository: $repo_full_name"
  if gh secret set ADD_TO_PROJECT_PAT -b"$PAT_VALUE" --repo "$repo_full_name"; then
    echo "Successfully set secret for $repo_full_name"
  else
    echo "Failed to set secret for $repo_full_name. Check permissions or if the repo exists."
  fi
done

echo "Finished setting secrets for all specified repositories."
