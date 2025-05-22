#!/opt/homebrew/bin/bash

set -e # Exit on most errors
# set -x # Uncomment for detailed debugging

# --- Configuration ---
# !!! IMPORTANT: Configure these variables to match your project's setup !!!
ORG_NAME="YOUR_GITHUB_ORGANIZATION" # Replace with your GitHub organization name
PROJECT_NUMBER="YOUR_PROJECT_NUMBER"     # Replace with your GitHub project number (the number, not the Node ID)
STATUS_FIELD_NAME="Status"         # Replace with the exact name of your project's status field
TODO_OPTION_NAME="Todo"            # Replace with the exact name of the option for 'To Do' items in your status field
DONE_OPTION_NAME="Done"            # Replace with the exact name of the option for 'Done' items in your status field

# --- Get Project and Field Details ---
echo "Fetching Project Node ID for $ORG_NAME/projects/$PROJECT_NUMBER..."
PROJECT_NODE_ID=$(gh project list --owner "$ORG_NAME" --format json | jq -r ".projects[] | select(.number == $PROJECT_NUMBER) | .id")

if [ -z "$PROJECT_NODE_ID" ]; then
    echo "Error: Project $ORG_NAME/$PROJECT_NUMBER (Node ID) not found." >&2
    exit 1
fi
echo "Using Project Node ID (for item-edit): $PROJECT_NODE_ID"
echo "Using Project Number (for field-list, item-list): $PROJECT_NUMBER"

echo "Fetching Status field details from Project $PROJECT_NUMBER..."
FIELDS_JSON=$(gh project field-list "$PROJECT_NUMBER" --owner "$ORG_NAME" --format json)
STATUS_FIELD_JSON=$(echo "$FIELDS_JSON" | jq -c --arg NAME "$STATUS_FIELD_NAME" '.fields[]? | select(.name == $NAME)')

if [ -z "$STATUS_FIELD_JSON" ] || [ "$STATUS_FIELD_JSON" == "null" ]; then
    echo "Error: Status field named '$STATUS_FIELD_NAME' not found in project $PROJECT_NUMBER." >&2
    echo "Available fields:"
    echo "$FIELDS_JSON" | jq '.fields[]?.name'
    exit 1
fi
STATUS_FIELD_ID=$(echo "$STATUS_FIELD_JSON" | jq -r '.id')
echo "Status Field ID ('$STATUS_FIELD_NAME'): $STATUS_FIELD_ID"

TODO_OPTION_ID=$(echo "$STATUS_FIELD_JSON" | jq -r --arg NAME "$TODO_OPTION_NAME" '.options[]? | select(.name == $NAME) | .id')
DONE_OPTION_ID=$(echo "$STATUS_FIELD_JSON" | jq -r --arg NAME "$DONE_OPTION_NAME" '.options[]? | select(.name == $NAME) | .id')

if [ -z "$TODO_OPTION_ID" ]; then echo "Error: Todo option '$TODO_OPTION_NAME' not found." >&2; exit 1; fi
if [ -z "$DONE_OPTION_ID" ]; then echo "Error: Done option '$DONE_OPTION_NAME' not found." >&2; exit 1; fi
echo "Todo Option ID: $TODO_OPTION_ID, Done Option ID: $DONE_OPTION_ID"
echo "Initial setup complete. Pausing for 3 seconds..."
sleep 3

# --- Process Project Items ---
echo "Fetching all items from project $PROJECT_NUMBER..."
# Increase limit if your project has more than 2000 items.
# Using jq to iterate over items to handle potentially large JSON better than mapfile here.
gh project item-list "$PROJECT_NUMBER" --owner "$ORG_NAME" --format json --limit 2000 | \
    jq -c '.items[]? | select(.content.url != null and .content.type == "Issue")' | \
while IFS= read -r item_json; do
    PROJECT_ITEM_ID=$(echo "$item_json" | jq -r '.id')
    ISSUE_URL=$(echo "$item_json" | jq -r '.content.url')
    ITEM_TITLE=$(echo "$item_json" | jq -r '.content.title // .title') # Fallback to item title if content title is missing

    echo "---"
    echo "Processing Project Item ID: $PROJECT_ITEM_ID (Title: \"$ITEM_TITLE\", Linked Issue URL: $ISSUE_URL)"

    if [ -z "$ISSUE_URL" ] || [ "$ISSUE_URL" == "null" ]; then
        echo "  Skipping item $PROJECT_ITEM_ID as it has no linked issue URL."
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
        TARGET_OPTION_ID="$TODO_OPTION_ID"
        TARGET_STATUS_NAME="$TODO_OPTION_NAME"
    elif [ "$ISSUE_STATE" == "CLOSED" ]; then
        TARGET_OPTION_ID="$DONE_OPTION_ID"
        TARGET_STATUS_NAME="$DONE_OPTION_NAME"
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
