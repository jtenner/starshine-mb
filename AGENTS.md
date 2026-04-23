# Repo Essentials

- MoonBit workspace with directory-scoped packages via `moon.pkg` under `moon.mod.json`.
- Tests live beside implementation as `*_test.mbt` or `*_wbtest.mbt`; package imports live in `package*/imports.mbt`.
- Review `.mbti` diffs for public API changes.
- `docs/README.md` is the canonical docs and wiki schema; keep it in sync with this file.
- Keep normative docs in `docs/`, living knowledge in `docs/wiki/`, immutable committed sources in `docs/wiki/raw/` except for redaction or format normalization, and one-off investigations in `docs/wiki/raw/research/[serial]-[YYYY-MM-DD]-[kebab-title].md`.
- Keep `docs/wiki/index.md` and `docs/wiki/log.md` current when wiki schema, ingest, query-fileback, or lint behavior changes.
- `src/node_api/`, `src/optimization/`, and `src/transformer/` are inactive compatibility or staging dirs unless rebuilt.
- `agent-todo.md` is active unreleased backlog only. `agent-lost-and-found.md` is local-only and must never be committed.

# Always-Follow Workflow Rules

- Use TDD: write or update tests first, confirm failure, then implement.
- Start from `docs/` for major architecture, ABI, release, planning, or wiki-schema work. Read `docs/README.md` first for knowledge-base ingest, query, lint, or schema work.
- Update relevant docs for behavior or API changes; keep docs concise.
- Update pass tests in the implementing file and active dispatcher. Today that is usually `src/cmd/cmd.mbt`; later also `src/passes/optimize.mbt`.
- Do not remove features, disable passing tests, add telemetry-only tests, or add shell scripts under `scripts/`.
- Gitignore new non-repo build or cache dirs when needed.
- Do not use destructive git commands unless explicitly requested.
- Serialize `moon` commands because they contend on `_build/.moon-lock`.

# Task-Specific Rules

## Docs And Wiki

- Prefer updating an existing wiki page over creating a near-duplicate page.
- Cite supporting numbered docs, raw sources, tests, or source files.
- Record uncertainty, contradictions, and supersession explicitly; do not silently overwrite stale claims.
- Treat completed debugging, research, and design threads as sources; file durable conclusions back into the wiki.
- Once a research note in `docs/` has been fully absorbed and is no longer the active normative contract, move it to `docs/wiki/raw/research/` and repoint live references.
- Never commit secrets, credentials, tokens, or other private material into `docs/wiki/` or `docs/wiki/raw/`.

## Working On Passes

- Correctness first.
- Match oracle Binaryen at minimum.
- Target `< 1s` or `>= 50%` of Binaryen wall time where possible.
- Verify parity with `bun fuzz compare-pass ...` or `bun scripts/pass-fuzz-compare.ts ...` at `10000` comparisons.
- Prefer `--pass <name>` with canonical pass names and treat the harness as pass-targeted before expanding to combined-pass runs.

## Validation And Signoff

- Preferred quick signoff: `moon info`, `moon fmt`, then `moon test`.
- Prefer `bun validate` before committing.
- Local full gate: `bun validate full --profile ci --target wasm-gc`.
- Coverage: `bun validate coverage`.
- README sync: `bun validate readme-api-sync`.

## Commit And Publish

- Update relevant docs and `CHANGELOG.md` before commit.
- Keep changelog entries concise: date, bold short title, completed intent.
- Review the staged diff.
- Commit with `git commit -F <temp-file>` and include changed files plus reasons in the commit text.
- Prune stale `agent-todo.md` items and add new blockers or risks.
- Publishing requires an explicit semver bump, successful validation, consistent package version bumps, and reusing changelog text for tag and release notes.

## Research, Backlog, And MoonBit Style

- Research docs use the next zero-padded serial with commit date and short kebab title after scanning `docs/`, `docs/wiki/`, and `docs/wiki/raw/research/` for overlaps.
- Substantial investigations belong in `docs/wiki/raw/research/`; keep durable conclusions live in `docs/wiki/` when they should remain reusable.
- Keep `agent-todo.md` grouped by release target and IR2 slice id, with only active unreleased work plus goal, why, deliverables, tasks, required APIs, invariants, dependencies, exit criteria, and suggested tests.
- Keep release blockers and known test failures visible until resolved.
- MoonBit style: use block-structured `///|`, prefer constructor methods over open-struct literals, and keep deprecated behavior in `deprecated.mbt` with `#deprecated`.
