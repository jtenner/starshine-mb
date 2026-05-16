# Commit

- Update relevant docs before committing; do not add per-commit changelog entries.
- Use docs/wiki pages, `docs/wiki/log.md`, release notes, and git history for durable change records.
- Review the staged diff.
- Commit with `git commit -F <temp-file>`, not `git commit -m`.
- Include changed files and reasons in the commit text.
- Prune stale `agent-todo.md` items and add new blockers or risks.
