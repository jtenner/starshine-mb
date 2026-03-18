# Project Agents.md Guide

This is a [MoonBit](https://docs.moonbitlang.com) project.

## Project Structure
- Packages are directory-scoped (`moon.pkg` per package); top-level module metadata is in `moon.mod.json`.
- Tests are usually colocated with code; common suffixes are blackbox `_test.mbt` and whitebox `_wbtest.mbt`.
- The project has not been released yet, so breaking API changes are okay.
- Imports from other modules should exist in `package*/imports.mbt`.

## Coding Convention
- MoonBit code is block-structured with `///|`; block order is not semantically relevant.
- Prefer constructor methods over open-struct literals.
- Put deprecated code in `deprecated.mbt` with `#deprecated` markers.
- Use strict TDD for both feature and regression tests: write tests before code, and make sure they fail explicitly before writing the code.
- Do not add tests that only assert tracing, progress logging, or telemetry text unless explicitly requested.
- Do not add tests tracing.
- Unless explicitly instructed, do not remove or disable existing features or tests to make tests pass. Changing test expectations to meet correctness standards is fine.

## Tooling
- Format: `moon fmt`. Interface refresh: `moon info`. Lint/check: `moon check` (not very useful; also runs as part of `moon test`).
- Tests: `moon test`; use `moon test --update` for snapshot updates.
- Task automation is Bun-first and task-family based: use `bun validate ...`, `bun fuzz ...`, `bun self-opt ...`, `bun make ...`, and `bun examples ...` from the repo root.
- Fuzz suites: run via `moon run src/fuzz ...` or `bun fuzz run ...`, not via heavy/randomized `moon test` harness loops.
- Full local gate: `bun validate full --profile ci --target wasm-gc` runs `moon info`, `moon fmt`, `moon check`, `moon test`, then fuzz suites.
- Coverage helper: `bun validate coverage --baseline .github/coverage-baseline.txt` or `moon coverage analyze > uncovered.log`
- README/API sync helper: `bun validate readme-api-sync`
- Preferred final local check sequence: `moon info && moon fmt`, then `moon test`.
- Running multiple `moon` commands in parallel contends on `_build/.moon-lock`; one process waits on the lock instead of progressing concurrently.
- When testing the self-optimize pipeline, let the user run the pipeline instead of running it yourself.

## Commit Strategy
- If a task ends with a commit, update `CHANGELOG.md` first with a short entry describing the completed work.
- Review the staged diff before committing.
- Write the commit message to a temporary file, then commit with `git commit -F <temp-file>`.
- Do not use `git commit -m` or interactive commit editors.

## Repository Layout
- `examples/`: runnable usage examples and sample config/module inputs.
- `scripts/`: top-level Bun task entrypoints only (`validate.ts`, `fuzz.ts`, `self-opt.ts`, `make.ts`, `examples.ts`).
- `scripts/lib/`: reusable task modules and helper implementations; when adding or changing automation, put reusable logic here and keep the top-level task files as thin dispatchers.
- `scripts/test/`: Bun/TS script-level regression tests for task behavior.
- Task scripting strategy: do not add shell scripts under `scripts/`; keep task automation importable, Windows-safe, and callable from the base Bun task files.
- `src/binary/`: binary wasm encoding/decoding.
- `src/cmd/` and `src/cli/`: command entrypoints and CLI plumbing.
- `src/diff/`: Meyers diff algorithm for debugging purposes.
- `src/ir/`: IR data structures and compiler analyses/utilities.
- `src/lib/`: wasm core model types plus shared traits and utilities.
- `src/node_api/`: Node-facing API integration layer.
- `src/passes/`: optimization/lowering pass implementations and pass helpers.
- `src/spec_runner/`: spec test execution helpers.
- `src/transformer/`: `ModuleTransformer` framework and related tests.
- `src/validate/`: wasm validation and typechecking logic.
- `src/wast/`: WAST s-expression parsing and printing.
- `src/wat/`: text-format wasm (`.wat`) support.
- `tests/node/`: Node integration tests and scripts.
- `tests/spec/`: upstream-style spec test corpus and proposal fixtures.

## Test/Validation Expectations for Pass Changes
- Update inline/dispatch tests in the pass file and/or `src/passes/optimize.mbt`.
- Run `moon test` and `moon info && moon fmt`.
- Review `.mbti` diffs to confirm intended public API changes.

## Agent Task File
- `./agent-todo.md` contains AI-friendly backlog items.
- Keep backlog tasks as simple bullet points grouped by priority/section.
- Do not mark completed backlog items in `agent-todo.md`; move completed work into `CHANGELOG.md` instead.

## Lost And Found Canary
- `./agent-lost-and-found.md` is a local canary file for agent observations; it is intentionally gitignored and should not be committed.
- Use it to record surprises in the development process: missing documentation, hard-to-find code paths, unclear workflow expectations, non-obvious setup requirements, or other friction that slowed the work down.
- Focus entries on technical debt and incremental process improvements that would help future agents or developers move faster.
- Prefer concrete notes: what was hard to find, why it mattered, and what file, doc, script, or workflow should be improved.
- If the issue suggests a repository-policy fix, note the recommended `AGENTS.md` or tooling update there so the developer orchestrating the work can decide whether to formalize it.
- Keep entries concise and developer-facing; this file is for process feedback, not task tracking or changelog history.

## Additional Project Files
- Report any publishing blockers or test failures left in `agent-todo.md`.
