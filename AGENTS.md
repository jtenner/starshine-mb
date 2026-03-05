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
- If optimization state is reusable, put it in `IRContext` instead of threading extra parameters.
- Pass constructor parameters should be immutable and captured in `ModuleTransformer` event closures.s

## Tooling
- Format: `moon fmt`
- Interface refresh: `moon info`
- Lint/check: `moon check` (not very useful, runs as part of "test")
- Tests: `moon test` (`moon test --update` for snapshot updates) (also runs "check" as byproduct)
- Coverage helper: `moon coverage analyze > uncovered.log`
- Preferred final local check sequence:
  - `moon info && moon fmt`
  - `moon check`
  - `moon test`
- Running multiple `moon` commands in parallel contends on `_build/.moon-lock`; one process waits on the lock instead of progressing concurrently.

In this workspace, use absolute moon path when needed:
- `/home/jtenner/.moon/bin/moon test`
- `/home/jtenner/.moon/bin/moon info && /home/jtenner/.moon/bin/moon fmt`

## Repository Layout
- `src/lib/`: wasm core model types plus shared traits and utilities.
- `src/ir/`: IR data structures and compiler analyses/utilities.
- `src/passes/`: optimization/lowering pass implementations and pass helpers.
- `src/transformer/`: `ModuleTransformer` framework and related tests.
- `src/validate/`: wasm validation and typechecking logic.
- `src/binary/`: binary wasm encoding/decoding.
- `src/wast/`: WAST s-expression parsing and printing.
- `src/wat/`: text-format wasm (`.wat`) support.
- `src/cmd/` and `src/cli/`: command entrypoints and CLI plumbing.
- `src/node_api/`: Node-facing API integration layer.
- `src/spec_runner/`: spec test execution helpers.
- `tests/spec/`: upstream-style spec test corpus and proposal fixtures.
- `tests/node/`: Node integration tests and scripts.
- `examples/`: runnable usage examples and sample config/module inputs.
- `scripts/`: project automation and maintenance scripts.

## Test/Validation Expectations for Pass Changes
- Update inline/dispatch tests in the pass file and/or `src/passes/optimize.mbt`.
- Run:
  - `/home/jtenner/.moon/bin/moon check`
  - `/home/jtenner/.moon/bin/moon test`
  - `/home/jtenner/.moon/bin/moon info && /home/jtenner/.moon/bin/moon fmt`
- Review `.mbti` diffs to confirm intended public API changes.

## Agent Task File
- `./agent-todo.md` contains AI-friendly backlog items.

## Surprises
Whenever something surprises you about the project, and can be fixed in another agent pass, please report these surprises in a file called `./agent-surprises.md`. This will help the user understand the project better and help developers modify the codebase so that things are less surprising in the future.
