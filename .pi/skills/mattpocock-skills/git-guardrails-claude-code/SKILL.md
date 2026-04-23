---
name: git-guardrails-claude-code
description: Set up Claude Code hooks to block dangerous git commands (push, reset --hard, clean, branch -D, etc.) before they execute. Use when user wants to prevent destructive git operations, add git safety hooks, or block git push/reset in Claude Code.
---

# Setup Git Guardrails

Install a `PreToolUse` hook that blocks destructive git commands before they run.

## Blocked commands
- `git push`
- `git reset --hard`
- `git clean -f` / `git clean -fd`
- `git branch -D`
- `git checkout .` / `git restore .`

## Workflow
1. Ask whether to install for this project or globally.
2. Copy `scripts/block-dangerous-git.sh` into the target hooks directory.
3. Make it executable.
4. Merge the hook into the relevant Claude settings file.
5. Ask whether the blocked pattern list should be customized.
6. Verify with a sample blocked command.
