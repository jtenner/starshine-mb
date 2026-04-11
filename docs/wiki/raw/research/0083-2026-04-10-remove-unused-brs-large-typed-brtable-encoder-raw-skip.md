---
kind: research
status: completed
last_reviewed: 2026-04-10
sources:
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/perf_test.mbt
  - ../../../../agent-todo.md
---

# 0083 - `remove-unused-brs` large typed `br_table` encoder raw skip

## Scope

- Retire the next unchanged lift-heavy artifact family after the tagged result-prefix hot skip.
- Record the detector-boundary lesson from the first reduced-only draft that missed the real artifact body.

## Problem

- After `0082`, the native artifact trace at `.tmp/rub-trace-large-tagged-prefix-fastguard-idle.stderr` still showed:
  - `Func 1382` at `pass=7879 / lift=80435`
  - `Func 1482` at `pass=7595 / lift=65715`
- `Func 1482` was the simpler next target:
  - RUB still finished `changed=false`
  - most of the visible cost was lift plus no-op traversal
  - the raw body was a deep decoded block shell around a single `br_table` encoder ladder, so a raw skip was the right boundary

## Reduced Perf Lock

- Added `perf_test_make_large_typed_br_table_encoder_ladder_module(...)` in `src/passes/perf_test.mbt`.
- Added perf lock `remove-unused-brs skips large typed br_table encoder ladders without hot lift`.
- The reduced family matches the measured artifact envelope:
  - `1024` to `5000` locals
  - very deep decoded leading block shell
  - exactly one `br_table`
  - many calls, `local.set`, `local.tee`, `if`, `br`, `return`, and `drop`
  - no `select`
  - no `br_if`
  - only a few loops
  - a large mix of value and void blocks

## Change

- Extended `RawRemoveUnusedBrsShape` in `src/passes/pass_manager.mbt` with:
  - `value_block_count`
  - `void_block_count`
- `run_hot_pipeline_raw_remove_unused_brs_scan_shape(...)` now counts both block classes, treating `TypeIdxBlockType(_)` as a value block.
- Added `run_hot_pipeline_raw_remove_unused_brs_leading_any_block_chain_depth(...)` as a cheap decoded-shell prefilter.
- Added `run_hot_pipeline_raw_remove_unused_brs_can_skip_large_typed_br_table_encoder_ladder(...)`.
- The landed detector requires:
  - locals in the measured band
  - `leading_any_block_chain_depth >= 32`
  - broad raw control surface from `run_hot_pipeline_instr_scan(...)`
  - narrow lifted-from-trace counts on calls, locals, blocks, `if`, `br`, `return`, and `drop`
  - exactly one `br_table`
- The emitted raw skip reason is `large-typed-br-table-encoder-ladder-noop`.

## Boundary Lesson

- The first detector draft was stricter:
  - it required `instrs.length() == 1`
  - it keyed on a single reduced typed root
- That version passed the reduced perf lock but missed the real artifact `Func 1482`.
- The landed rule instead keys on the decoded any-block shell plus the measured count envelope.
- The maintenance rule is the same one already seen in other RUB slices:
  - use the reduced lock to prove the family
  - then calibrate the final detector against the real artifact body instead of freezing the first reduced-only approximation

## Validation

- `moon test src/passes`
  - `431/431` passing
- `bun scripts/pass-fuzz-compare.ts --pass remove-unused-brs --generator gen-valid --count 10000 --min-compared 10000 --max-failures 20 --out-dir .tmp/pass-fuzz-rub-genvalid-20260410-typed-brtable-encoder-v4-10000`
  - `10000/10000` compared
  - `10000` normalized matches
  - `0` mismatches
  - `0` validation failures
  - `0` generator failures
  - `0` command failures
- `bun scripts/pass-fuzz-compare.ts --pass remove-unused-brs --generator both --count 2000 --seed 0x5eed1d --max-failures 5 --out-dir .tmp/pass-fuzz-rub-both-20260410-typed-brtable-encoder-v4-2000`
  - `840/840` compared clean
  - `0` mismatches
  - stopped on `5` Binaryen-side command failures

## Artifact Impact

- Native replay:
  - `moon run --target native --release src/cmd -- --tracing pass --remove-unused-brs --out .tmp/rub-trace-typed-brtable-encoder-idle-v4.wasm tests/node/dist/starshine-debug-wasi.wasm`
- Total traced cost improved from `.tmp/rub-trace-large-tagged-prefix-fastguard-idle.stderr` to `.tmp/rub-trace-typed-brtable-encoder-idle-v4.stderr`:
  - pass total `692911 us -> 653494 us`
  - lift total `994979 us -> 730704 us`
- The traced target is now retired:
  - `Func 1482` now reports `skip-raw reason=large-typed-br-table-encoder-ladder-noop`
- The remaining visible hotspot is now:
  - `Func 1382` at `pass=6716 / lift=65291`
  - it still reports `skip-hot reason=large-void-if-return-ladder-noop`

## Remaining Work

- The next runtime work is now centered on `Func 1382`.
- That follow-up should still keep pure lift cost separate from RUB walk cost before adding another no-op skip.
- I did not rerun the full self-opt compare in this slice.
