---
name: setup-pre-commit
description: Set up pre-commit checks so formatting, linting, or targeted validation runs before commits. Use when user wants safer commits or wants to enforce checks locally.
---

# Setup Pre-Commit

Configure pre-commit checks for the project.

## Workflow
1. Identify the smallest fast checks worth running before each commit.
2. Choose the project's preferred hook tool.
3. Install the hook without overwriting unrelated existing config.
4. Scope checks to staged files when possible.
5. Verify the hook is fast enough to keep.
