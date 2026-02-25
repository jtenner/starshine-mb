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
- Pass constructor parameters should be immutable and captured in `ModuleTransformer` event closures.

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

In this workspace, use absolute moon path when needed:
- `/home/jtenner/.moon/bin/moon test`
- `/home/jtenner/.moon/bin/moon info && /home/jtenner/.moon/bin/moon fmt`

## Repository Layout
- `src/lib/*.mbt`: core wasm model/types (`types.mbt`), traits/helpers (`arbitrary.mbt`, `eq.mbt`, `show.mbt`, `texpr.mbt`)
- `src/ir/*.mbt`: IR analyses/utilities (`ir_context.mbt`, `liveness.mbt`, `gvn.mbt`, etc.)
- `src/passes/*.mbt`: optimization and lowering passes
- `src/transformer/*.mbt`: `ModuleTransformer` framework
- `src/validate/*.mbt`: wasm validation/typechecking
- `src/binary/*.mbt`: wasm binary encoding/decoding
- `src/wast/*.mbt`: s-expression text parsing/printing

## Pass Pipeline (Compressed)
- Canonical scheduler: `src/passes/optimize.mbt`.
- `optimize_module(...)` always runs `lift_to_texpr_pass()` first.
- Preferred integration shape:
  - pass constructor returns `ModuleTransformer[IRContext]` (or `Result[...]` if setup can fail)
  - scheduler dispatches `ModulePass` variants to constructors.
- `src/passes/util.mbt` has `wrap_unit_func_pass` for adapting `ModuleTransformer[Unit]` function passes.

## Current Gaps / Ongoing Work
- Migrate remaining non-IRContext-shaped passes (`de_nan`, `remove_unused`).
- Keep `IRContext`/SSA/CFG as the canonical optimization context for IR-driven passes.
- `GlobalStructInferenceDescCast` now includes a conservative singleton-global `ref.cast` lowering path; full opcode-level descriptor parity (`ref.get_desc` / descriptor-eq casts) still depends on descriptor IR support.
- Atomics/threading core instruction support is complete; remaining parity work is pass-specific atomics optimization behavior in heap passes.
- `Asyncify` parity follow-up remaining gaps are now mostly around wider Binaryen feature surface beyond current staged implementation (for example additional optimizer-stage parity and advanced unsupported value categories).

## Test/Validation Expectations for Pass Changes
- Update inline/dispatch tests in the pass file and/or `src/passes/optimize.mbt`.
- Run:
  - `/home/jtenner/.moon/bin/moon check`
  - `/home/jtenner/.moon/bin/moon test`
  - `/home/jtenner/.moon/bin/moon info && /home/jtenner/.moon/bin/moon fmt`
- Review `.mbti` diffs to confirm intended public API changes.

## Agent Task File
- `./agent-todo.md` contains AI-friendly backlog items.
