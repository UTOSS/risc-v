# Required CI Checks Configuration

This document explains how to configure required status checks for this repository to prevent merging broken PRs.

## Overview

The CI workflow includes a special `required` job that depends on all critical CI jobs:
- `svlint` - Linting checks
- `build_and_test` - Build and test the core
- `riscof` - RISCOF compliance tests
- `de1-soc` - DE1-SoC environment build and test

The `required` job will only pass if all these jobs succeed, providing a single status check to mark as required.

## Configuring Branch Protection

To enable required status checks:

1. Go to your repository on GitHub
2. Navigate to **Settings** → **Branches**
3. Under "Branch protection rules", click **Add rule** or edit an existing rule
4. For "Branch name pattern", enter `main` (or your default branch)
5. Check **Require status checks to pass before merging**
6. Search for and select the `required` status check
7. Optionally, also check **Require branches to be up to date before merging**
8. Click **Create** or **Save changes**

## How It Works

The `required` job:
- Uses `if: always()` to ensure it runs even if some jobs fail
- Declares all critical jobs in its `needs` list
- Checks the result of each job and fails if any job didn't succeed
- Provides clear output showing which jobs failed

This pattern ensures:
- A consistent status check name (`required`) that can be marked as required in branch protection
- All critical CI jobs must pass before the PR can be merged
- Clear feedback when jobs fail

## Testing

When you open a PR, you should see the `required` check in the status checks list. It will only pass if all dependent jobs succeed.
