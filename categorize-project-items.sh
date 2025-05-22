#!/opt/homebrew/bin/bash

set -e # Exit on most errors
# set -x # Uncomment for detailed debugging

# --- Configuration ---
# !!! IMPORTANT: Configure these variables to match your project's setup !!!
OWNER_NAME="YOUR_GITHUB_OWNER" # Replace with your GitHub organization or user name
PROJECT_NUMBER="YOUR_PROJECT_NUMBER"     # Replace with your GitHub project number (the number, not the Node ID)
# The name of the project status field is typically "Status". This is assumed by the script.
STATUS_FIELD_NAME="Status"
OPEN_ISSUE_STATUS="Todo"            # Replace with the name of the status option in your project for OPEN issues (e.g., "Todo", "Backlog")
CLOSED_ISSUE_STATUS="Done"          # Replace with the name of the status option in your project for CLOSED issues (e.g., "Done", "Completed")

# REPO_LIST: Define specific repository names (not full paths, e.g., "my-repo") to filter project items by.
# If REPO_LIST is empty (default), the script considers items linked to issues from *any* repository within the project.
# If REPO_LIST is populated, OWNER_NAME must be configured, and only items linked to issues from
# repositories matching OWNER_NAME/REPO_NAME_FROM_LIST will be processed.
REPO_LIST=(
    # "YOUR_EXAMPLE_REPO_1"
    # "YOUR_EXAMPLE_REPO_2"
)

# --- Initial Checks ---
if [ ${#REPO_LIST[@]} -gt 0 ]; then
    # If REPO_LIST is used for filtering, OWNER_NAME (of the repositories) must be correctly set.
    # Note: The script's OWNER_NAME variable is also used for the project owner.
    # This assumes the project owner is the same as the repository owner when filtering.
    if [ "$OWNER_NAME" == "YOUR_GITHUB_OWNER" ] || [ -z "$OWNER_NAME" ]; then
        echo "Error: REPO_LIST is populated for filtering, but OWNER_NAME (repository owner) is not configured or is set to the placeholder 'YOUR_GITHUB_OWNER'." >&2
        echo "Please configure OWNER_NAME." >&2
        exit 1
    fi
fi

# --- Get Project and Field Details ---
echo "Fetching Project Node ID for $OWNER_NAME/projects/$PROJECT_NUMBER..."
PROJECT_NODE_ID=$(gh project list --owner "$OWNER_NAME" --format json | jq -r ".projects[] | select(.number == $PROJECT_NUMBER) | .id")

if [ -z "$PROJECT_NODE_ID" ]; then
    echo "Error: Project $OWNER_NAME/$PROJECT_NUMBER (Node ID) not found." >&2
    exit 1
fi
echo "Using Project Node ID (for item-edit): $PROJECT_NODE_ID"
echo "Using Project Number (for field-list, item-list): $PROJECT_NUMBER"

echo "Fetching Status field details from Project $PROJECT_NUMBER..."
FIELDS_JSON=$(gh project field-list "$PROJECT_NUMBER" --owner "$OWNER_NAME" --format json)
STATUS_FIELD_JSON=$(echo "$FIELDS_JSON" | jq -c --arg NAME "$STATUS_FIELD_NAME" '.fields[]? | select(.name == $NAME)')

if [ -z "$STATUS_FIELD_JSON" ] || [ "$STATUS_FIELD_JSON" == "null" ]; then
    echo "Error: Status field named '$STATUS_FIELD_NAME' not found in project $PROJECT_NUMBER." >&2
    echo "Available fields:"
    echo "$FIELDS_JSON" | jq '.fields[]?.name'
    exit 1
fi
STATUS_FIELD_ID=$(echo "$STATUS_FIELD_JSON" | jq -r '.id')
echo "Status Field ID ('$STATUS_FIELD_NAME'): $STATUS_FIELD_ID"

OPEN_ISSUE_STATUS_OPTION_ID=$(echo "$STATUS_FIELD_JSON" | jq -r --arg NAME "$OPEN_ISSUE_STATUS" '.options[]? | select(.name == $NAME) | .id')
CLOSED_ISSUE_STATUS_OPTION_ID=$(echo "$STATUS_FIELD_JSON" | jq -r --arg NAME "$CLOSED_ISSUE_STATUS" '.options[]? | select(.name == $NAME) | .id')

if [ -z "$OPEN_ISSUE_STATUS_OPTION_ID" ]; then echo "Error: Option for OPEN issues ('$OPEN_ISSUE_STATUS') not found in Status field." >&2; exit 1; fi
if [ -z "$CLOSED_ISSUE_STATUS_OPTION_ID" ]; then echo "Error: Option for CLOSED issues ('$CLOSED_ISSUE_STATUS') not found in Status field." >&2; exit 1; fi
echo "Option ID for OPEN issues ('$OPEN_ISSUE_STATUS'): $OPEN_ISSUE_STATUS_OPTION_ID"
echo "Option ID for CLOSED issues ('$CLOSED_ISSUE_STATUS'): $CLOSED_ISSUE_STATUS_OPTION_ID"
echo "Initial setup complete. Pausing for 3 seconds..."
sleep 3

# --- Process Project Items ---
echo "Fetching all items from project $PROJECT_NUMBER..."
# Increase limit if your project has more than 2000 items.
# Using jq to iterate over items to handle potentially large JSON better than mapfile here.
gh project item-list "$PROJECT_NUMBER" --owner "$OWNER_NAME" --format json --limit 2000 | \
    jq -c '.items[]? | select(.content.url != null and .content.type == "Issue")' | \
while IFS= read -r item_json; do
    PROJECT_ITEM_ID=$(echo "$item_json" | jq -r '.id')
    ISSUE_URL=$(echo "$item_json" | jq -r '.content.url')
    ITEM_TITLE=$(echo "$item_json" | jq -r '.content.title // .title') # Fallback to item title if content title is missing

    echo "---"
    echo "Processing Project Item ID: $PROJECT_ITEM_ID (Title: \"$ITEM_TITLE\", Linked Issue URL: $ISSUE_URL)"

    # Repository filtering logic
    process_this_item=true
    if [ ${#REPO_LIST[@]} -gt 0 ]; then # Only filter if REPO_LIST is populated
        if [ -n "$ISSUE_URL" ] && [ "$ISSUE_URL" != "null" ]; then
            # Extract owner/repo from issue URL (e.g., https://github.com/owner/repo/issues/123)
            repo_full_name_from_issue=$(echo "$ISSUE_URL" | sed -n 's|https://github.com/\([^/]*\)/\([^/]*\)/issues/.*|\1/\2|p')

            if [ -n "$repo_full_name_from_issue" ]; then
                is_repo_in_list=false
                for listed_repo_short_name in "${REPO_LIST[@]}"; do
                    # Construct the full name from REPO_LIST entry using the script's configured OWNER_NAME
                    full_listed_repo_name_to_match="$OWNER_NAME/$listed_repo_short_name"
                    if [[ "$full_listed_repo_name_to_match" == "$repo_full_name_from_issue" ]]; then
                        is_repo_in_list=true
                        break
                    fi
                done
                if ! $is_repo_in_list; then
                    process_this_item=false
                    echo "  Skipping item: Repository '$repo_full_name_from_issue' does not match any in the specified REPO_LIST for owner '$OWNER_NAME'."
                fi
            else
                process_this_item=false
                echo "  Skipping item: Could not determine repository from URL '$ISSUE_URL' for REPO_LIST filtering."
            fi
        else
            process_this_item=false
            echo "  Skipping item: No issue URL to check against REPO_LIST."
        fi
    fi

    if ! $process_this_item; then
        continue
    fi

    # Original check for issue URL validity before fetching state (still useful even if repo filtering passed or wasn't active)
    if [ -z "$ISSUE_URL" ] || [ "$ISSUE_URL" == "null" ]; then
        echo "  Skipping item $PROJECT_ITEM_ID as it has no linked issue URL (this check is redundant if filtering was already applied, but kept for safety)."
        continue
    fi

    echo -n "  Fetching state for issue $ISSUE_URL... "
    ISSUE_STATE=$(gh issue view "$ISSUE_URL" --json state -q '.state' 2>/dev/null)

    if [ -z "$ISSUE_STATE" ]; then
        echo "Failed to fetch state for issue $ISSUE_URL. Skipping."
        # This could happen if the issue was deleted or gh couldn't access it
        continue
    fi
    echo "State: $ISSUE_STATE"

    TARGET_OPTION_ID=""
    TARGET_STATUS_NAME=""
    if [ "$ISSUE_STATE" == "OPEN" ]; then
        TARGET_OPTION_ID="$OPEN_ISSUE_STATUS_OPTION_ID"
        TARGET_STATUS_NAME="$OPEN_ISSUE_STATUS"
    elif [ "$ISSUE_STATE" == "CLOSED" ]; then
        TARGET_OPTION_ID="$CLOSED_ISSUE_STATUS_OPTION_ID"
        TARGET_STATUS_NAME="$CLOSED_ISSUE_STATUS"
    else
        echo "  Unknown issue state '$ISSUE_STATE' for $ISSUE_URL. Skipping status update."
        continue
    fi

    echo -n "  Setting status of Item $PROJECT_ITEM_ID to '$TARGET_STATUS_NAME'... "
    EDIT_CMD_OUTPUT=""
    if EDIT_CMD_OUTPUT=$(gh project item-edit --id "$PROJECT_ITEM_ID" --project-id "$PROJECT_NODE_ID" --field-id "$STATUS_FIELD_ID" --single-select-option-id "$TARGET_OPTION_ID" 2>&1); then
        echo "Successfully set status."
    else
        echo "Failed to set status. Output: $EDIT_CMD_OUTPUT"
        # Log but continue, as some failures might be "already set" or transient.
    fi
    sleep 0.8 # Rate limiting
done

echo "-----------------------------------------------------"
echo "Project item categorization process finished."
