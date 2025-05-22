#!/opt/homebrew/bin/bash

set -e # Exit on most errors
# set -x # Uncomment for detailed debugging

# Source the central configuration file
CONFIG_FILE_PATH="$(dirname "$0")/config.sh"
if [ -f "$CONFIG_FILE_PATH" ]; then
    source "$CONFIG_FILE_PATH"
else
    echo "Error: Configuration file config.sh not found in the script's directory." >&2
    echo "Please create it (e.g., from config.sh.example) and configure your variables." >&2
    exit 1
fi

# The name of the project status field is typically "Status". This is assumed by the script.
STATUS_FIELD_NAME="Status" # This remains hardcoded as per previous decision.

# --- Initial Checks ---
# Variables are now sourced from config.sh

# OWNER_NAME must be set correctly in config.sh
if [ "$OWNER_NAME" == "YOUR_GITHUB_OWNER" ] || [ -z "$OWNER_NAME" ]; then
    echo "Error: OWNER_NAME is not configured in config.sh or is still set to the placeholder 'YOUR_GITHUB_OWNER'." >&2
    echo "Please update config.sh." >&2
    exit 1
fi

# PROJECT_NUMBER must be set correctly in config.sh
if [ "$PROJECT_NUMBER" == "YOUR_PROJECT_NUMBER" ] || [ -z "$PROJECT_NUMBER" ]; then
    echo "Error: PROJECT_NUMBER is not configured in config.sh or is still set to the placeholder 'YOUR_PROJECT_NUMBER'." >&2
    echo "Please update config.sh." >&2
    exit 1
fi

# OPEN_ISSUE_STATUS and CLOSED_ISSUE_STATUS must be set (they have defaults in config.sh, but check they are not empty)
if [ -z "$OPEN_ISSUE_STATUS" ]; then
    echo "Error: OPEN_ISSUE_STATUS is not configured (or is empty) in config.sh." >&2
    echo "Please update config.sh." >&2
    exit 1
fi
if [ -z "$CLOSED_ISSUE_STATUS" ]; then
    echo "Error: CLOSED_ISSUE_STATUS is not configured (or is empty) in config.sh." >&2
    echo "Please update config.sh." >&2
    exit 1
fi

# If REPO_LIST (from config.sh) is populated for filtering, the OWNER_NAME check above already covers its requirement.

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
