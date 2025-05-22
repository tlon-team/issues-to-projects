#!/bin/bash
# You can get a list of all repos for your owner (organization or user) with a command like:
# gh repo list YOUR_GITHUB_OWNER --limit 1000 --json nameWithOwner -q '.[].nameWithOwner'

# !!! IMPORTANT: Configure these variables !!!
OWNER_NAME="YOUR_GITHUB_OWNER"      # Replace with your GitHub organization or user name. Used if PROCESS_ALL_REPOS is true.
PAT_VALUE="YOUR_GITHUB_PAT"         # Replace with your GitHub Personal Access Token (PAT)
                                    # This PAT needs 'repo' and 'project' scopes. If the workflow you intend to use
                                    # (which this PAT might be for) modifies workflow files itself, also add 'workflow' scope.
                                    # The secret name "ADD_TO_PROJECT_PAT" is a common convention for actions like `actions/add-to-project`.
                                    # If your workflow uses a different secret name, update it here and in the workflow file.

# REPO_LIST: Define specific repositories to process.
# If REPO_LIST is empty, the script will attempt to process all repositories for the OWNER_NAME.
REPO_LIST=(
  # "YOUR_GITHUB_OWNER/YOUR_EXAMPLE_REPO_1"
  # "YOUR_GITHUB_OWNER/YOUR_EXAMPLE_REPO_2"
  # Add more repositories here, e.g., "YOUR_GITHUB_OWNER/ANOTHER_REPO"
)

# --- Initial Checks and Repo List Population ---
if [ ${#REPO_LIST[@]} -eq 0 ]; then
    if [ "$OWNER_NAME" == "YOUR_GITHUB_OWNER" ] || [ -z "$OWNER_NAME" ]; then
        echo "Error: REPO_LIST is empty and OWNER_NAME is not configured or is set to the placeholder 'YOUR_GITHUB_OWNER'." >&2
        echo "Please configure OWNER_NAME to process all its repositories, or populate REPO_LIST." >&2
        exit 1
    fi
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
        REPO_LIST=("${TEMP_REPO_LIST[@]}") # Overwrite REPO_LIST with all fetched repos
        echo "Successfully fetched ${#REPO_LIST[@]} repositories for owner $OWNER_NAME."
    fi
elif [ ${#REPO_LIST[@]} -gt 0 ]; then
    echo "Processing ${#REPO_LIST[@]} repositories specified in REPO_LIST."
    # No error if REPO_LIST is populated, OWNER_NAME is not strictly needed for this path,
    # but it's good practice to have it set if one might switch between modes.
fi
# If REPO_LIST was initially empty and fetching failed to populate it, it will be caught by the loop or subsequent commands.

for repo in "${REPO_LIST[@]}"; do
  echo "Setting secret ADD_TO_PROJECT_PAT for repository: $repo"
  if gh secret set ADD_TO_PROJECT_PAT -b"$PAT_VALUE" --repo "$repo"; then
    echo "Successfully set secret for $repo"
  else
    echo "Failed to set secret for $repo. Check permissions or if the repo exists."
  fi
done

echo "Finished setting secrets for all specified repositories."
