# Project Structure
- Directory-scoped packages (`moon.pkg`) under a top-level `moon.mod.json`.
- Test files stay beside implementation (`*_test.mbt`, `*_wbtest.mbt`).
- Breaking API changes are acceptable while project is pre-release.
- Imports for each package live in `package*/imports.mbt`.
- Main layout:
  - `docs/`: canonical research/plan/audit/bench baseline (`docs/[serial]-[YYYY-MM-DD]-[kebab-title].md`).
  - `src/`: active package dirs include `binary`, `cli`, `cmd`, `diff`, `fs`, `fuzz`, `ir`, `lib`, `spec_runner`, `validate`, `validate_trace`, `wast`, `wat`.
  - `src/`: `node_api/`, `optimization/`, and `transformer/` currently exist as empty compatibility/staging dirs; do not document them as active packages unless they are rebuilt.
  - `examples/`, `tests/spec/`, `tests/node/`.
  - `scripts/`: Bun entrypoints only (`validate.ts`, `fuzz.ts`, `self-opt.ts`, `make.ts`, `examples.ts`) with shared code in `scripts/lib/*` and tests in `scripts/test/*`.

# Rules
- Prefer compact, directly actionable rules and docs.
- Start from `docs/` for prior architecture, ABI, release, planning, and research context before major changes.
- MoonBit code style:
  - block-structured with `///|` (block order is non-semantic).
  - prefer constructor methods over open-struct literals.
  - keep deprecated behavior in `deprecated.mbt` with `#deprecated`.
- Use strict TDD: write tests first and verify they fail.
- Avoid trace/progress/telemetry-only tests unless explicitly requested.
- Do not remove features or disable passing tests to mask failures.
- Keep `agent-todo.md` strictly as unreleased backlog.
- Update inline/dispatch tests for pass behavior changes in the implementing file and the active dispatcher. Today that is usually `src/cmd/cmd.mbt`; once the rebuilt pass manager lands, update `src/passes/optimize.mbt` too.
- Run `moon test` and `moon info && moon fmt` before pass-change signoff.
- Review `.mbti` diffs when public API changes.
- Do not add shell scripts under `scripts/`.
- Update README/API docs when public behavior changes.
- Keep `agent-lost-and-found.md` for friction-only notes (gitignored, not committed).
- Gitignore newly discovered non-repo build/cache dirs when needed.
- Do not edit with destructive git commands unless explicitly requested.

# Tooling
- `moon info`, `moon fmt`, `moon check`, `moon test`.
- `moon test --update` for snapshot updates.
- Bun-first workflow: `bun validate ...`, `bun fuzz ...`, `bun self-opt ...`, `bun make ...`, `bun examples ...`.
- Fuzzing runs through `moon run src/fuzz ...` or `bun fuzz run ...` (not heavy randomized loops in `moon test`).
- Local full gate: `bun validate full --profile ci --target wasm-gc`.
- Coverage + README sync checks via `bun validate coverage` and `bun validate readme-api-sync`.
- Preferred final quick check: `moon info && moon fmt`, then `moon test`.
- Prefer `bun validate` checks before committing.
- Multiple `moon` commands contend on `_build/.moon-lock`; serialize these runs.
- When requested to test the full self-optimize pipeline, ask the user for permission before running it.
- For optimize-pipeline parity signoff, ask permission before running `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --optimize` and treat canonical parity plus Starshine wall time at least 50% as fast as Binaryen as the done threshold.

# Commit Process
- For any commit, update `CHANGELOG.md` first with a short completed-work entry.
- Include date, a bold short title, and intent in changelog entries.
- Review staged diff before committing.
- Write commit body to a temp file and run `git commit -F <temp-file>`.
- Commit text should include changed files and reasons.
- Do not use `git commit -m`.
- Changelog entries are concise and include date + completed intent.

# Publish Workflow
- For releases, require explicit semver bump (`patch|minor|major`) and run `bun validate` first.
- Run all full validation checks and stop on any failure.
- Update all package versions consistently for the release target.
- Bump all package versions consistently before tagging.
- Reuse changelog entry text for tag and release notes.
- Push commit, annotated tag, and release; avoid duplicate releases.
- Stop at the first validation failure and fix before continuing.

# Research
- Use the next zero-padded serial `docs` filename with commit date and short kebab title.
- Before creating/renaming research, scan `docs/` for matching pass/topic names and legacy aliases.
- Research should include scope, current behavior, correctness constraints, validation plan, performance impact, and open questions.
- Update `README`s and code references when legacy path notes are replaced by canonical serial docs.
- After significant research updates, refresh the matching `agent-todo.md` blockers.

# Agent Workflow Files
- `agent-todo.md`: keep as active-only backlog grouped by release target and IR2 slice id. Active slices should carry goal, why, deliverables, implementation tasks, required APIs, invariants, dependencies, exit criteria, and suggested tests.
- `agent-lost-and-found.md`: local canary for process friction and concrete recommendations; never commit.
- Keep release blockers and known test failures visible in `agent-todo.md` until resolved.
- Before commit, remove no-longer-relevant tasks and add new blockers/risks.
