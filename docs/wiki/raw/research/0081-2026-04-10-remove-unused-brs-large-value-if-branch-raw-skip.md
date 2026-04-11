---
kind: research
status: completed
last_reviewed: 2026-04-10
sources:
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/perf_test.mbt
  - ../../../../agent-todo.md
---

# 0081 - `remove-unused-brs` large value-`if` / branch raw skip

## Scope

- Retire the next unchanged `remove-unused-brs` artifact hotspot after the lifted large `br_table` / return skip.
- Keep the living RUB wiki aligned with the actual remaining pass-heavy hotspot instead of the now-retired `Func 828`.

## Problem

- After the lifted large-`br_table` skip, the native artifact trace at `.tmp/rub-trace-large-brtable-hotskip-v2-idle.stderr` still showed:
  - `Func 828` / `hot__lift__impl__exact__family` at `pass=9900 / lift=4593`
  - `Func 356` / `dfe__try__rewrite__instruction__type__idxs` at `pass=8723 / lift=5630`
- `Func 828` was the simpler next target:
  - the raw function body had a tiny local footprint
  - it was a deep block chain around a huge `i64` value-`if` / bare-`br` decision ladder
  - the pass still reported `changed=false`
- The printed raw artifact shape for `Func 828` measured as:
  - `block=10`
  - `if=317`
  - `br=312`
  - `call=108`
  - `local.tee=1`
  - `return=10`
  - `local.set=0`
  - `br_if=0`
  - `br_table=0`
  - `select=0`

## Reduced Perf Lock

- Added `perf_test_make_large_value_if_branch_ladder_module(...)` in `src/passes/perf_test.mbt`.
- Added perf lock `remove-unused-brs skips large value-if branch ladders without hot lift`.
- The reduced family intentionally matches the artifact envelope:
  - tiny local footprint
  - deep plain block chain
  - almost one-for-one `if` / `br` traffic
  - explicit `return` wrappers after each block boundary
  - no `local.set`, `br_if`, `br_table`, `select`, or loop surface

## Change

- Added `run_hot_pipeline_raw_remove_unused_brs_can_skip_large_value_if_branch_ladder(...)` in `src/passes/pass_manager.mbt`.
- The new raw classifier requires:
  - very small locals
  - a deep leading void-block chain
  - dense `if` / `br` traffic with nearly matching counts
  - `return_count == block_count`
  - no `local.set`
  - no `br_if`
  - no `br_table`
  - no `select`
  - no loops
- The emitted raw skip reason is `large-value-if-branch-ladder-noop`.
- The detector is intentionally narrow:
  - it retired exactly one traced artifact function in the current replay
  - it is not meant as a generic "large value ladder" fast path

## Validation

- `moon test src/passes`
  - `429/429` passing
- `bun scripts/pass-fuzz-compare.ts --pass remove-unused-brs --generator gen-valid --count 10000 --min-compared 10000 --max-failures 20 --out-dir .tmp/pass-fuzz-rub-genvalid-20260410-large-value-if-branch-10000`
  - `10000/10000` compared
  - `10000` normalized matches
  - `0` mismatches
  - `0` validation failures
  - `0` generator failures
  - `0` command failures
- `bun scripts/pass-fuzz-compare.ts --pass remove-unused-brs --generator both --count 2000 --seed 0x5eed17 --max-failures 5 --out-dir .tmp/pass-fuzz-rub-both-20260410-large-value-if-branch-2000`
  - `846/846` compared clean
  - `0` mismatches
  - stopped on `5` Binaryen-side command failures
  - failure classes were `1` `binaryen-command-failed` and `4` `binaryen-rec-group-zero`

## Artifact Impact

- Native replay:
  - `moon run --target native --release src/cmd -- --tracing pass --remove-unused-brs --out .tmp/rub-trace-large-value-if-branch-ladder-idle.wasm tests/node/dist/starshine-debug-wasi.wasm`
- Total traced cost improved from `.tmp/rub-trace-large-brtable-hotskip-v2-idle.stderr` to `.tmp/rub-trace-large-value-if-branch-ladder-idle.stderr`:
  - pass total `654407 us -> 601957 us`
  - lift total `917148 us -> 794557 us`
- The traced target is now retired:
  - `Func 828` now reports `skip-raw reason=large-value-if-branch-ladder-noop`
- The next visible pass-heavy target is now:
  - `Func 356` at `pass=8317 / lift=4956`
- The remaining lift-heavy side is still led by:
  - `Func 1382` at `pass=6253 / lift=66966`
  - `Func 1482` at `pass=4586 / lift=45504`

## Remaining Work

- The pass-heavy side is now mostly the repeated result-prefix rejection family at `Func 356`.
- The lift-heavy side is still separate, so the next performance slice should keep:
  - pass-walk work inside RUB
  - pure lift cost avoided only by raw skip
  distinct in both the trace and the write-up.
- I did not rerun the full self-opt compare in this slice.
