# Project Agents.md Guide

This is a [MoonBit](https://docs.moonbitlang.com) project.

## Project Structure
- MoonBit packages are directory-scoped (`moon.pkg` per package).
- Top-level module metadata is in `moon.mod.json`.
- Tests are usually colocated with code in this project.
- Common test suffixes:
  - blackbox: `_test.mbt`
  - whitebox: `_wbtest.mbt`
- Project hasn't been released yet, breaking api changes are okay.
- Imports from other modules should exist in `package*/imports.mbt`

## Coding Convention
- MoonBit code is block-structured with `///|`; block order is not semantically relevant.
- Prefer constructor methods over open-struct literals.
- Put deprecated code in `deprecated.mbt` with `#deprecated` markers.
- Please use strict TDD for both feature and regression tests. Write tests before code, and make sure they fail explicitly before writing the code. 
- Do not add tests tracing.
- Unless explicitly instructed, do not remove or disable existing features or tests to make tests pass. Changing test expectations to meet correctness standards is fine.

## Tooling
- Format: `moon fmt`
- Interface refresh: `moon info`
- Lint/check: `moon check` (not very useful, runs as part of "test")
- Tests: `moon test` (`moon test --update` for snapshot updates) (also runs "check" as byproduct)
- Fuzz suites: run via `moon run src/fuzz ...` (or `scripts/run-fuzz.sh ...`), not via heavy/randomized `moon test` harness loops.
- Coverage helper: `moon coverage analyze > uncovered.log`
- Preferred final local check sequence:
  - `moon info && moon fmt`
  - `moon test`
  - If requested, stage a commit with a temporary commit file that contains the description of the task, files changed, and why they were changed.
- Running multiple `moon` commands in parallel contends on `_build/.moon-lock`; one process waits on the lock instead of progressing concurrently.
- When testing the self-optimize pipeline, let the user run the pipeline instead of running it yourself.

## Repository Layout
- `examples/`: runnable usage examples and sample config/module inputs.
- `scripts/`: project automation and maintenance scripts.
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
- Run:
  - `moon test`
  - `moon info && moon fmt`
- Review `.mbti` diffs to confirm intended public API changes.

## Agent Task File
- `./agent-todo.md` contains AI-friendly backlog items.

## Additional Project Files
- Please report files that were difficult to find, or things  in `agent-lost-and-found.md`.
- Please report any publishing blockers or test failures left in `agent-todo.md`
