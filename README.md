# GitHub Multi-Repo to Project Automation Scripts

This repository contains a collection of shell scripts designed to help manage GitHub issues across multiple repositories and consolidate them into a GitHub Project. This is a common challenge, as highlighted in discussions like [this GitHub Community thread](https://github.com/orgs/community/discussions/47803).

These scripts leverage the GitHub CLI (`gh`) and `jq` to automate tasks such as adding all existing issues from multiple repositories to a project, categorizing items in a project based on linked issue status, and deploying GitHub Actions workflows to multiple repositories.

**Important Notice:** These scripts were developed for personal use and are shared in the hope that they might be useful to others. They have not been thoroughly tested in all environments or scenarios. Users should review the scripts and test them carefully before running them in a production environment. Contributions, bug fixes, and improvements are welcome! Please feel free to open a pull request.

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
4.  **Git**: Required by `add-issues-to-project-batch` for cloning repositories.
5.  **GitHub Personal Access Token (PAT)** (Recommended for some operations, especially GitHub Actions):
    *   If you're using the `automate_github_secrets` script or the `add-issues-to-project-batch` script with a workflow that relies on a PAT (e.g., `actions/add-to-project` often uses a PAT stored in `ADD_TO_PROJECT_PAT`), you'll need to generate one.
    *   Go to GitHub > Settings > Developer settings > Personal access tokens (Tokens (classic) or Fine-grained tokens).
    *   **Required scopes for PAT (classic)**:
        *   `repo`: Full control of private repositories (needed to add workflow files, set secrets).
        *   `project`: Read and write projects.
        *   `workflow` (if the PAT is used by a workflow that modifies other workflows or needs to bypass branch protections for workflow changes): Update GitHub Action workflows.
    *   **Fine-grained tokens**: Configure access to specific repositories and grant `Read and Write` access for `Actions`, `Contents`, `Issues`, `Metadata`, `Projects`, and `Secrets`.
    *   **Important**: Keep your PAT secure. Do not hardcode it directly into scripts you commit publicly if avoidable. The `automate_github_secrets` script is designed to help you set this PAT as a secret in multiple repositories.

## Scripts Overview and Usage

**Important General Configuration:**

*   Before running any script, open it in a text editor.
*   Locate the "Configuration" section near the top.
*   Replace placeholder values (e.g., `YOUR_GITHUB_ORGANIZATION`, `YOUR_PROJECT_NUMBER`, `YOUR_GITHUB_PAT`, `YOUR_REPO_1`, `YOUR_PATH_TO/add-issues-to-project.yml`) with your actual data.
*   Make scripts executable: `chmod +x script-name.sh` (e.g., `chmod +x add-all-existing-issues-to-project.sh`).

---

### 1. `add-all-existing-issues-to-project.sh`

*   **Purpose**: Adds all existing issues (both open and closed) from a list of specified repositories to a designated GitHub Project.
*   **How to use**:
    1.  Configure `ORG_NAME`, `PROJECT_NUMBER`, and `REPO_LIST` in the script.
    2.  Run: `bash ./add-all-existing-issues-to-project.sh`
*   **Notes**:
    *   This script can take a long time if you have many repositories or issues.
    *   It includes `sleep` commands and a `MAX_OPERATIONS_BEFORE_LONG_PAUSE` variable to help manage GitHub API rate limits. If you hit rate limits, you might need to wait (often an hour) and resume, possibly by commenting out already processed repositories from `REPO_LIST`.
    *   The script will skip issues that are already in the project.

---

### 2. `categorize-project-items.sh`

*   **Purpose**: Iterates through items in a GitHub Project. If an item is linked to an issue, this script checks the issue's state (Open/Closed) and updates a specified "Status" field in the project accordingly (e.g., sets to "Todo" if issue is open, "Done" if issue is closed).
*   **How to use**:
    1.  Configure `ORG_NAME`, `PROJECT_NUMBER`, `STATUS_FIELD_NAME`, `TODO_OPTION_NAME`, and `DONE_OPTION_NAME` in the script. Ensure these names *exactly* match your project's setup (case-sensitive).
    2.  Run: `bash ./categorize-project-items.sh`
*   **Notes**:
    *   This script helps synchronize the project board status with the actual status of linked issues.
    *   It fetches project field and option IDs dynamically. If field or option names are incorrect, it will fail.

---

### 3. `batch-deploy-add-new-issues-workflow.sh`

*   **Purpose**: Deploys a GitHub Actions workflow file (e.g., one that uses `actions/add-to-project` to automatically add new issues to a project) to multiple repositories. It clones each repository, adds/updates the workflow file, commits, and pushes the change.
*   **How to use**:
    1.  **Prepare your workflow file using the provided `add-issues-to-project.yml`**:
        *   This repository includes a sample GitHub Actions workflow file named `add-issues-to-project.yml`.
        *   **Customize it**:
            1.  Open the `add-issues-to-project.yml` file (from *this* repository).
            2.  Modify the `project-url` to point to your specific GitHub project. The original file contains `project-url: https://github.com/orgs/tlon-team/projects/9`. You **must** change this to your organization and project number:
                ```yaml
                # Inside your copy of add-issues-to-project.yml
                # ...
                with:
                  project-url: https://github.com/orgs/YOUR_GITHUB_ORGANIZATION/projects/YOUR_PROJECT_NUMBER
                  github-token: ${{ secrets.ADD_TO_PROJECT_PAT }}
                ```
                Replace `YOUR_GITHUB_ORGANIZATION` and `YOUR_PROJECT_NUMBER` with your actual details.
            3.  Save this customized version of `add-issues-to-project.yml` to a location on your computer.
    2.  Configure the `batch-deploy-add-new-issues-workflow.sh` script:
        *   Set the `WORKFLOW_FILE_PATH` variable in the script to the full path of your *customized and saved* `add-issues-to-project.yml` file (e.g., `WORKFLOW_FILE_PATH="$HOME/my_custom_workflows/add-issues-to-project.yml"`).
        *   Configure the `REPO_LIST` in the script with the repositories where you want to deploy this workflow.
    3.  Run: `bash ./batch-deploy-add-new-issues-workflow.sh`
*   **Notes**:
    *   This script performs `git clone`, `git commit`, and `git push` operations. Ensure your `gh` CLI is authenticated with rights to push to these repositories, or that your Git credential manager is set up.
    *   The commit message is predefined in the script.
    *   It creates a temporary directory for cloning, which is removed afterward.
    *   If the workflow file in the repository is identical to the one being deployed, it will skip committing and pushing for that repository.

---

### 4. `automate-github-secrets.sh`

*   **Purpose**: Sets a GitHub Actions secret (by default, `ADD_TO_PROJECT_PAT`) in multiple repositories. This is useful for providing a PAT to workflows, like the one deployed by `batch-deploy-add-new-issues-workflow.sh`.
*   **How to use**:
    1.  Generate a GitHub Personal Access Token (PAT) with appropriate scopes (see Prerequisites).
    2.  Configure `PAT_VALUE` (with your actual PAT) and `REPO_LIST` in the script.
    3.  Run: `bash ./automate-github-secrets.sh`
*   **Notes**:
    *   **Security**: Be very careful with your PAT. Once you've run this script to set the secrets in your repositories, you might want to clear the `PAT_VALUE` from the script file or delete the script if you don't need to run it again soon, to avoid accidentally exposing the PAT if the script is shared or committed.
    *   The secret name `ADD_TO_PROJECT_PAT` is a common convention for the `actions/add-to-project` action, but can be changed if your workflow uses a different secret name (you'd need to change it in this script and in your workflow YAML).

## Recommended Workflow

This section outlines the recommended order for using the scripts to set up automated issue tracking for new issues and to handle existing issues.

**Part 1: Initial Setup (For Automating *New* Issues)**

This part focuses on configuring GitHub Actions to automatically add newly created issues to your project. These steps are typically done once.

1.  **`automate-github-secrets.sh`**
    *   **Purpose**: Securely provides the necessary GitHub Personal Access Token (PAT) to your repositories. This PAT allows the GitHub Action (deployed in the next step) to add issues to your project.
    *   **Action**:
        1.  Generate a GitHub Personal Access Token (PAT) with the required scopes (see Prerequisites).
        2.  Configure `PAT_VALUE` (with your PAT) and `REPO_LIST` in the `automate-github-secrets.sh` script.
        3.  Run the script: `bash ./automate-github-secrets.sh`. It sets the `ADD_TO_PROJECT_PAT` secret in all repositories listed in its `REPO_LIST`.

2.  **`batch-deploy-add-new-issues-workflow.sh`** (using the provided `add-issues-to-project.yml`)
    *   **Purpose**: Deploys the GitHub Actions workflow (`add-issues-to-project.yml`) to all specified repositories. This workflow will automatically add any *newly created* issues in these repositories to your designated project.
    *   **Action**:
        1.  Locate the `add-issues-to-project.yml` file provided in *this* automation scripts repository.
        2.  **Customize it**: Open this YAML file. You **must** change the `project-url` to point to your organization and project number (e.g., `https://github.com/orgs/YOUR_GITHUB_ORGANIZATION/projects/YOUR_PROJECT_NUMBER`).
        3.  Save this customized `add-issues-to-project.yml` file somewhere on your local system.
        4.  In the `batch-deploy-add-new-issues-workflow.sh` script, update the `WORKFLOW_FILE_PATH` variable to point to the location where you saved your customized YAML file.
        5.  Configure the `REPO_LIST` in `batch-deploy-add-new-issues-workflow.sh` with the target repositories.
        6.  Run the script: `bash ./batch-deploy-add-new-issues-workflow.sh`.
    *   **Result**: After these two steps, any new issues created in the configured repositories will be automatically added to your GitHub project by the GitHub Action.

**Part 2: Handling Existing Issues (One-Time Population)**

The GitHub Action set up above only works for *newly created* issues. If you have existing issues in your repositories that you want to add to the project, use the following scripts.

3.  **`add-all-existing-issues-to-project.sh`**
    *   **Purpose**: Adds all existing issues (both open and closed) from your specified repositories to the project.
    *   **Action**:
        1.  Configure `ORG_NAME`, `PROJECT_NUMBER`, and `REPO_LIST` in the `add-all-existing-issues-to-project.sh` script.
        2.  Run the script: `bash ./add-all-existing-issues-to-project.sh`. This can take a significant amount of time depending on the number of issues and repositories.

4.  **`categorize-project-items.sh`**
    *   **Purpose**: After adding existing issues (using the script above), this script updates their status in the project based on their current state in the repository. Open issues will be set to your "Todo" status (or equivalent), and closed issues to your "Done" status (or equivalent).
    *   **Action**:
        1.  Configure the project details (`ORG_NAME`, `PROJECT_NUMBER`) and your specific status field names (`STATUS_FIELD_NAME`, `TODO_OPTION_NAME`, `DONE_OPTION_NAME`) in the `categorize-project-items.sh` script. Ensure these names exactly match your project's setup.
        2.  Run the script: `bash ./categorize-project-items.sh`.
    *   **Note**: This script can also be run periodically to ensure project item statuses reflect the actual issue states if they are changed manually or by other processes outside the project board.

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
