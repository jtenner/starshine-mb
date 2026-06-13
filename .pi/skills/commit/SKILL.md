---
name: commit
description: Commit current work using Starshine's commit policy. Use when the user asks to commit, create commits, save changes to git history, or prepare a commit from the current worktree.
---

# Commit

Commit the current worktree as one or more policy-compliant commits.

## Trigger

Use this skill whenever the user asks to `commit`, create a git commit, save changes in git history, or split current work into commits.

## Policy

- Treat every request to "commit" as a request to split the worktree by top-level unit of change and commit each unit separately.
- Prefer large, detailed commits that explain what changed and why while staying as atomic as possible.
- Commit titles must use `<kind>: <title>`.
- Commit with `git commit -F <temp-file>`, not `git commit -m`.
- Commit bodies must include changed files and reasons.
- Update relevant docs before committing; do not add per-commit changelog entries.
- Use docs/wiki pages, `docs/wiki/log.md`, release notes, and git history for durable change records.
- Prune stale `agent-todo.md` items and add new blockers or risks when the change affects active backlog.

## Validation Policy

- Docs-only commits do not require tests. Use diff, link, and source review unless docs change generated contracts or executable examples.
- Forward-moving test or expectation updates do not require a test run unless the intent is to fix related behavior.
- Positive behavior changes may be committed even if they temporarily leave some tests failing, as long as progress and the failure state are documented in the commit body.
- Prefer `bun validate` before committing only when the change needs repository-wide confidence.
- Use the task-specific validation ladder when a change is ready for broad signoff or touches high-risk behavior.

## Workflow

1. Inspect the worktree with `git status --short` and review relevant diffs.
2. Identify top-level units of change. Keep each commit atomic, but do not split one coherent unit into tiny low-context commits.
3. For each unit:
   - stage only the files or hunks that belong to that unit;
   - review the staged diff;
   - decide whether validation is required under the validation policy;
   - run required validation, or explicitly record why validation was not run;
   - write a detailed commit message to a temporary file;
   - commit with `git commit -F <temp-file>`.
4. Repeat until all intended units are committed.
5. Report the created commits, validation run or intentionally skipped, and any remaining uncommitted changes.

## Commit Message Shape

```text
<kind>: <title>

Changed files:
- <path>: <what changed and why>

Validation:
- <commands run, results, or why tests were not required>

Notes:
- <known temporary failures, follow-ups, or backlog impacts when relevant>
```

Omit empty sections only when they add no useful information. Keep the body detailed enough that a future maintainer can understand the intent without reconstructing it from the diff.
