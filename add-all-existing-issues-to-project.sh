#!/opt/homebrew/bin/bash

# --- Configuration ---
# !!! IMPORTANT: Configure these variables !!!
OWNER_NAME="GITHUB_OWNER" # Replace with your GitHub organization or user name
PROJECT_NUMBER="PROJECT_NUMBER"     # Replace with your GitHub project number (the number, not the Node ID)

# Define the list of repositories to process.
# You can get a list of all repos for your owner (organization or user) with a command like:
# gh repo list YOUR_GITHUB_OWNER --limit 1000 --json nameWithOwner -q '.[].nameWithOwner'
REPO_LIST=(
    "YOUR_GITHUB_OWNER/YOUR_EXAMPLE_REPO_1"
    "YOUR_GITHUB_OWNER/YOUR_EXAMPLE_REPO_2"
    # Add more repositories here, in the format "OWNER/REPO_NAME"
    # e.g., "YOUR_GITHUB_OWNER/ANOTHER_REPO"
)

# Control repository scope:
# If REPO_LIST is empty, the script will attempt to process all repositories for the OWNER_NAME.
# Otherwise, only repositories in REPO_LIST will be processed.

# --- Initial Checks and Repo List Population ---
if [ ${#REPO_LIST[@]} -eq 0 ]; then
    if [ "$OWNER_NAME" == "GITHUB_OWNER" ] || [ -z "$OWNER_NAME" ]; then
        echo "Error: REPO_LIST is empty and OWNER_NAME is not configured or is set to the placeholder 'GITHUB_OWNER'." >&2
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
fi

if [ ${#REPO_LIST[@]} -eq 0 ]; then
    echo "Error: No repositories to process. REPO_LIST is empty and could not be populated." >&2
    exit 1
fi

echo "--- Starting script to add issues to project ---"
echo "Processing repos in this batch: ${REPO_LIST[*]}"
sleep 3

# --- Process Repositories ---
for repo_full_name in "${REPO_LIST[@]}"; do
    echo "-----------------------------------------------------"
    echo "Processing repository for adding issues: $repo_full_name"
    echo "Pausing for 5 seconds before fetching issues for $repo_full_name..."
    sleep 5 # Pause before even listing issues for a repo

    ISSUE_URLS_OUTPUT=""
    ISSUE_URLS_OUTPUT=$(gh issue list -R "$repo_full_name" --state all --json url --limit 2000 2>&1) # Limit to 2000 issues per repo for now

    if [[ "$ISSUE_URLS_OUTPUT" == *"API rate limit exceeded"* ]]; then
        echo "  ERROR: API rate limit exceeded while listing issues for $repo_full_name. Stopping script."
        echo "    Please wait for the rate limit to reset (usually 1 hour) and then try again, possibly with a smaller batch or after a longer wait."
        exit 1
    elif ! echo "$ISSUE_URLS_OUTPUT" | jq -e . > /dev/null 2>&1; then
        echo "  ERROR: Failed to fetch or parse issues for $repo_full_name. Output: $ISSUE_URLS_OUTPUT. Skipping this repo."
        sleep 5
        continue
    fi

    ISSUE_URLS=()
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then # Ensure non-empty lines are added
            ISSUE_URLS+=("$line")
        fi
    done < <(echo "$ISSUE_URLS_OUTPUT" | jq -r ".[]? | .url // empty") # Handle empty results gracefully

    if [ ${#ISSUE_URLS[@]} -eq 0 ]; then # Simplified condition as empty lines are skipped
        echo "No issues (open or closed) found in $repo_full_name to add."
        sleep 1
        continue
    fi

    echo "Found ${#ISSUE_URLS[@]} issues in $repo_full_name. Attempting to add to project $PROJECT_NUMBER..."

    for issue_url in "${ISSUE_URLS[@]}"; do
        echo -n "  Attempting to add issue (URL: $issue_url)... "
        # Increased sleep BEFORE each item-add call
        # For a 5000 limit/hour, roughly 1 operation every 0.72 seconds.
        # Let's be much more conservative: 1 op every 3-5 seconds.
        sleep 4

        ADD_CMD_OUTPUT=""
        if ADD_CMD_OUTPUT=$(gh project item-add "$PROJECT_NUMBER" --owner "$OWNER_NAME" --url "$issue_url" 2>&1); then
            echo "Successfully added."
        else
            if [[ "$ADD_CMD_OUTPUT" == *"API rate limit exceeded"* ]]; then
                echo "ERROR: API rate limit exceeded while adding issue $issue_url."
                echo "    Stopping script. Please wait for reset and re-run (consider smaller batches or longer waits)."
                exit 1
            elif [[ "$ADD_CMD_OUTPUT" == *"already in project"* || "$ADD_CMD_OUTPUT" == *"already exists"* ]]; then
                echo "Issue already in project (expected)."
            else
                echo "Failed to add issue. Error: $ADD_CMD_OUTPUT"
            fi
        fi
    done
    echo "Finished processing issues for $repo_full_name."
    echo "Pausing for 15 seconds before next repository..."
    sleep 15 # Sleep longer between processing repositories
done

echo "-----------------------------------------------------"
echo "Finished adding all issues from the current batch of repositories."
