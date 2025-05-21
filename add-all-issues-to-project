#!/opt/homebrew/bin/bash

# --- Configuration ---
# !!! IMPORTANT: Configure these variables !!!
ORG_NAME="YOUR_GITHUB_ORGANIZATION" # Replace with your GitHub organization name
PROJECT_NUMBER="YOUR_PROJECT_NUMBER"     # Replace with your GitHub project number (the number, not the Node ID)

# Define the list of repositories to process.
# You can get a list of all repos for your organization with a command like:
# gh repo list YOUR_GITHUB_ORGANIZATION --limit 1000 --json nameWithOwner -q '.[].nameWithOwner'
REPO_LIST=(
    "YOUR_GITHUB_ORGANIZATION/YOUR_EXAMPLE_REPO_1"
    "YOUR_GITHUB_ORGANIZATION/YOUR_EXAMPLE_REPO_2"
    # Add more repositories here, in the format "OWNER/REPO_NAME"
    # e.g., "YOUR_GITHUB_ORGANIZATION/ANOTHER_REPO"
)
# Maximum number of item-add operations before the script suggests a longer pause.
# This is to help manage GitHub API rate limits. Adjust as needed.
# GitHub's API rate limit for authenticated users is typically 5000 requests per hour.
# Adding an item is one request. Listing issues also consumes requests.
MAX_OPERATIONS_BEFORE_LONG_PAUSE=200 # Adjusted to a more conservative default
OPERATIONS_COUNT=0

echo "--- Starting script to add issues to project ---"
echo "Processing repos in this batch: ${REPO_LIST[*]}"
echo "Will suggest a longer pause after approximately $MAX_OPERATIONS_BEFORE_LONG_PAUSE item additions."
sleep 3

# --- Process Repositories ---
for repo_full_name in "${REPO_LIST[@]}"; do
    if (( OPERATIONS_COUNT >= MAX_OPERATIONS_BEFORE_LONG_PAUSE )); then
        echo "INFO: Reached $MAX_OPERATIONS_BEFORE_LONG_PAUSE operations. Suggesting a longer pause (e.g., 15-30 mins) before processing more repos to avoid rate limits."
        echo "Current repo to process next would be: $repo_full_name"
        exit 0
    fi

    echo "-----------------------------------------------------"
    echo "Processing repository for adding issues: $repo_full_name (Operation count: $OPERATIONS_COUNT)"
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

    mapfile -t ISSUE_URLS < <(echo "$ISSUE_URLS_OUTPUT" | jq -r ".[]? | .url // empty") # Handle empty results gracefully

    if [ ${#ISSUE_URLS[@]} -eq 0 ] || [[ "${ISSUE_URLS[0]}" == "" && ${#ISSUE_URLS[@]} -eq 1 ]]; then
        echo "No issues (open or closed) found in $repo_full_name to add."
        sleep 1
        continue
    fi

    echo "Found ${#ISSUE_URLS[@]} issues in $repo_full_name. Attempting to add to project $PROJECT_NUMBER..."

    for issue_url in "${ISSUE_URLS[@]}"; do
        if (( OPERATIONS_COUNT >= MAX_OPERATIONS_BEFORE_LONG_PAUSE )); then
            echo "INFO: Reached $MAX_OPERATIONS_BEFORE_LONG_PAUSE operations during issue processing. Suggesting a longer pause."
            echo "Next issue to process would be: $issue_url from $repo_full_name"
            exit 0
        fi

        echo -n "  Attempting to add issue (URL: $issue_url)... "
        # Increased sleep BEFORE each item-add call
        # For a 5000 limit/hour, roughly 1 operation every 0.72 seconds.
        # Let's be much more conservative: 1 op every 3-5 seconds.
        sleep 4

        ADD_CMD_OUTPUT=""
        if ADD_CMD_OUTPUT=$(gh project item-add "$PROJECT_NUMBER" --owner "$ORG_NAME" --url "$issue_url" 2>&1); then
            echo "Successfully added."
            ((OPERATIONS_COUNT++))
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
echo "Finished adding all issues from the current batch of repositories. Total operations: $OPERATIONS_COUNT"
