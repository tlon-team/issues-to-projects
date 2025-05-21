#!/bin/bash
# You can get a list of all repos for your organization with a command like:
# gh repo list YOUR_GITHUB_ORGANIZATION --limit 1000 --json nameWithOwner -q '.[].nameWithOwner'

# !!! IMPORTANT: Configure these variables !!!
PAT_VALUE="YOUR_GITHUB_PAT" # Replace with your GitHub Personal Access Token (PAT)
                            # This PAT needs 'repo' and 'project' scopes. If the workflow you intend to use
                            # (which this PAT might be for) modifies workflow files itself, also add 'workflow' scope.
                            # The secret name "ADD_TO_PROJECT_PAT" is a common convention for actions like `actions/add-to-project`.
                            # If your workflow uses a different secret name, update it here and in the workflow file.

REPO_LIST=(
  "YOUR_GITHUB_ORGANIZATION/YOUR_EXAMPLE_REPO_1"
  "YOUR_GITHUB_ORGANIZATION/YOUR_EXAMPLE_REPO_2"
  # Add more repositories here, e.g., "YOUR_GITHUB_ORGANIZATION/ANOTHER_REPO"
)

for repo in "${REPO_LIST[@]}"; do
  echo "Setting secret ADD_TO_PROJECT_PAT for repository: $repo"
  if gh secret set ADD_TO_PROJECT_PAT -b"$PAT_VALUE" --repo "$repo"; then
    echo "Successfully set secret for $repo"
  else
    echo "Failed to set secret for $repo. Check permissions or if the repo exists."
  fi
done

echo "Finished setting secrets for all specified repositories."
