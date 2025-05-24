# Scripts to automatically add issues from multiple repos to a GitHub project

The purpose of this repository is to share a few scripts that together provide an answer to the following question:

> How the hell can I set up GitHub so that whenever a new issue is created in any of my repositories (or a subset thereof), it is automatically added to a project‽

GitHub [does not support this functionality natively](https://github.com/orgs/community/discussions/47803), hence the need for these scripts.

> [!CAUTION]
> These scripts were developed for personal use and are shared in the hope that they might be useful to others. They have not been thoroughly tested in all environments or scenarios. Users should review the scripts and test them carefully before running them in a production environment. Contributions, bug fixes, and improvements are welcome—see [Contributing](#contributing) below.

## Prerequisites

Before using these scripts, ensure you have the following installed and configured:

1.  **GitHub CLI (`gh`)**:
    *   Installation instructions: [cli.github.com](https://cli.github.com/)
    *   Authenticate with `gh auth login`. You'll need permissions to read repository data, read/write project data, and potentially `workflow` scope if you're using `add-issues-to-project-batch` to manage workflow files (this scope is needed for the PAT used by the workflow if it modifies workflow files or requires elevated permissions).
2.  **`jq`**:
    *   A lightweight and flexible command-line JSON processor.
    *   Installation instructions: [stedolan.github.io/jq/download/](https://stedolan.github.io/jq/download/)
3.  **Bash Shell**: These scripts are written for Bash.
    *   The shebang (first line, e.g., `#!/opt/homebrew/bin/bash` or `#!/bin/bash`) in the scripts might need adjustment based on your system's Bash location. `#!/usr/bin/env bash` is often a more portable option.
4.  **Git**: Required by `batch-deploy-add-new-issues-workflow.sh` for cloning repositories.

## Configuration

1.  **Configure `config.sh`**:
    *   Open `config.sh` in a text editor and replace all placeholder values (e.g., `YOUR_GITHUB_OWNER`, `YOUR_PROJECT_NUMBER`, `YOUR_GITHUB_PAT`, `YOUR_EXAMPLE_REPO_1`, `YOUR_PATH_TO/add-issues-to-project.yml`) with your actual data.
2.  **Make scripts executable**: `chmod +x *.sh`.

## Usage

**Part 1: Initial setup (for automating *new* issues)**

This part focuses on configuring GitHub Actions to automatically add newly created issues to your project. These steps are typically done only once.

1.  **`automate-github-secrets.sh`**
    *   **Purpose**: Securely provides the necessary GitHub Personal Access Token (PAT) to your repositories. This PAT allows the GitHub Action (deployed in the next step) to add issues to your project.
    *   **Action**:
        1.  **Generate a GitHub Personal Access Token (PAT classic)**:
            *   Go to GitHub > Your Profile (top right) > Settings > Developer settings (bottom left) > Personal access tokens > Tokens (classic).
            *   Click "Generate new token" and select "Generate new token (classic)".
            *   Give your token a descriptive name (e.g., "multi-repo-project-automation").
            *   Set an expiration date.
            *   **Required scopes**:
                *   `repo`: Full control of private repositories (needed to add workflow files, set secrets in target repos, list repos if processing all).
                *   `project`: Read and write projects (to allow the `actions/add-to-project` action to manage project items).
                *   `workflow`: Update GitHub Action workflows (needed by the `actions/add-to-project` workflow if it needs to make changes that require this scope, or if you are deploying workflows that modify other workflows).
            *   Click "Generate token".
            *   **Copy the token immediately.** You will not be able to see it again.
        2.  Ensure `OWNER_NAME`, `PAT_VALUE`, and optionally `REPO_LIST` are correctly set in `config.sh` as per its comments.
        3.  Run the script: `bash ./automate-github-secrets.sh`.
    *   **Notes**:
        *   **Security**: Be very careful with your PAT. Once you've run this script to set the secrets in your repositories, you might want to clear the `PAT_VALUE` from the script file or delete the script if you don't need to run it again soon, to avoid accidentally exposing the PAT if the script is shared or committed.
        *   The secret name `ADD_TO_PROJECT_PAT` is a common convention for the `actions/add-to-project` action, but can be changed if your workflow uses a different secret name (you'd need to change it in this script and in your workflow YAML).

2.  **`batch-deploy-add-new-issues-workflow.sh`** (using the provided `add-issues-to-project.yml`)
    *   **Purpose**: Deploys the GitHub Actions workflow (`add-issues-to-project.yml`) to all specified repositories. This workflow will automatically add any *newly created* issues in these repositories to your designated project.
    *   **Action**:
        1.  Locate the `add-issues-to-project.yml` file provided in *this* automation scripts repository.
        2.  **Customize it**: Open this YAML file. You **must** change the `project-url` to point to your project.
            *   For an organization project: `https://github.com/orgs/YOUR_ORG_NAME/projects/YOUR_PROJECT_NUMBER`
            *   For a user project: `https://github.com/users/YOUR_USER_NAME/projects/YOUR_PROJECT_NUMBER`
        3.  By default, this action will add all issues to the project board, regardless of their status, tag, etc. If you want to filter issues based on specific criteria (e.g., only open issues), you can modify the script accordingly.
        3.  Save this customized `add-issues-to-project.yml` file somewhere on your local system.
        4.  Ensure `OWNER_NAME`, `WORKFLOW_FILE_PATH`, and optionally `REPO_LIST` are correctly set in `config.sh`. The `WORKFLOW_FILE_PATH` should be the correct path to your customized `add-issues-to-project.yml`.
        5.  Run the script: `bash ./batch-deploy-add-new-issues-workflow.sh`.
    *   **Notes**:
        *   This script performs `git clone`, `git commit`, and `git push` operations. Ensure your `gh` CLI is authenticated with rights to push to these repositories, or that your Git credential manager is set up.
        *   The commit message is predefined in the script.
        *   It creates a temporary directory for cloning, which is removed afterward.
        *   If the workflow file in the repository is identical to the one being deployed, it will skip committing and pushing for that repository.
    *   **Result**: After these two steps, any new issues created in the configured repositories will be automatically added to your GitHub project by the GitHub Action.

**Part 2 (optional): Handling existing issues (one-time population)**

The GitHub Action set up above only works for *newly created* issues. If you have existing issues in your repositories that you want to add to the project, use the following scripts.

3.  **`add-all-existing-issues-to-project.sh`**
    *   **Purpose**: Adds all existing issues (both open and closed) from specified repositories to the project.
    *   **Action**:
        1.  Ensure `OWNER_NAME`, `PROJECT_NUMBER`, and optionally `REPO_LIST` are correctly set in `config.sh`.
        2.  Run the script: `bash ./add-all-existing-issues-to-project.sh`. This can take a significant amount of time.
    *   **Notes**:
        *   It includes `sleep` commands to help manage GitHub API rate limits. If you hit rate limits, you might need to wait (often an hour) and resume, possibly by commenting out already processed repositories from `REPO_LIST`.
        *   The script will skip issues that are already in the project.

4.  **`categorize-project-items.sh`**
    *   **Purpose**: Updates the status of items in your project based on the current state (open/closed) of their linked issues. Can operate on all items in the project or be filtered to items from specific repositories. The script assumes your project's status field is named "Status".
    *   **Action**:
        1.  Ensure `OWNER_NAME`, `PROJECT_NUMBER`, `OPEN_ISSUE_STATUS`, `CLOSED_ISSUE_STATUS`, and optionally `REPO_LIST` are correctly set in `config.sh`.
        2.  Run the script: `bash ./categorize-project-items.sh`.
    *   **Notes**:
        *   This script can also be run periodically to ensure project item statuses reflect the actual issue states if they are changed manually or by other processes outside the project board.
        *   It helps synchronize the project board status with the actual status of linked issues.
        *   It fetches project field and option IDs dynamically. If field or option names are incorrect, or if the script cannot find them, it will fail with an error message.

## Troubleshooting

*   **Rate Limits**: The GitHub API has rate limits (typically 5000 requests per hour for authenticated `gh` users). Scripts that iterate over many items or repositories (like `add-all-issues-to-project`) can hit these limits.
    *   The scripts include `sleep` commands to mitigate this.
    *   If you hit a limit, you'll usually need to wait an hour for it to reset.
    *   For `add-all-existing-issues-to-project.sh`, you can comment out already processed repositories in the `REPO_LIST` and restart the script.
*   **Permissions**: Ensure your `gh` CLI is authenticated with sufficient permissions for the operations being performed (reading repos, reading/writing projects, writing secrets, pushing code). For `batch-deploy-add-new-issues-workflow.sh`, ensure your Git setup allows pushing to the target repositories (e.g., via HTTPS with a PAT or SSH keys).
*   **`jq: command not found`**: Install `jq`.
*   **`gh: command not found`**: Install the GitHub CLI.
*   **Script execution permission denied**: Use `chmod +x ./script-name.sh`.
*   **`No such file or directory` for workflow file**: Double-check the `WORKFLOW_FILE_PATH` in `batch-deploy-add-new-issues-workflow.sh`.
*   **Git clone/push issues**: Ensure your Git credentials are set up correctly and you have push access to the repositories.

## Contributing

Feel free to fork this repository, suggest improvements, or submit pull requests. If you find bugs or have feature requests, please open an issue.

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details.
