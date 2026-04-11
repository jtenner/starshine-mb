# 0078 - RemoveUnusedBrs False Prefix-Guard Raw Skip

## Scope

- Reduce `remove-unused-brs` no-op cost from raw false positives in the prefix-guard detector.
- Keep the structured-return raw skip aligned with the actual HOT carried-guard legality surface.
- Confirm whether the fix retires the next debug-artifact hotspot pair or only trims a narrower cost class.

## Problem

After `0077`, the next large unchanged artifact hotspots were still:

- `Func 1058`
- `Func 1150`

The first hypothesis was that the raw structured-return skip was still being cancelled by an over-broad HOT-only candidate detector.

The relevant raw helper was:

- `run_hot_pipeline_raw_remove_unused_brs_block_has_prefix_guard_payload_branch_candidate(...)`

Its old rule was too broad:

- if the first root of a one-result block was a void block
- and that inner block contained any later `br_if 0`
- and the outer result block later carried payload before a `br`

then the raw layer forced lift, even if the `br_if` could not possibly be the first inner HOT root that the real result-prefix matcher needs.

## Reduced Repro

The new perf fixture is:

- `perf_test_make_structured_return_ladder_with_false_prefix_guard_module(...)`
- perf test `remove-unused-brs skips structured return ladders when a false prefix guard candidate cannot rewrite`

The reduced shape is:

- a normal structured-return ladder that should raw-skip
- plus a one-result inner block whose first root is a standalone `drop`
- followed only later by the `br_if 0` that the old raw detector used to treat as a carried-guard HOT candidate

That shape is not a real carried-guard rewrite:

- the actual HOT result-prefix matcher would reject it because the first inner root is not the guard branch
- but the old raw detector still cancelled `structured-return-ladder-noop`

The new perf regression failed before the fix by lifting, entering HOT, and mutating the function instead of skipping raw.

## Fix

`run_hot_pipeline_raw_remove_unused_brs_block_has_prefix_guard_payload_branch_candidate(...)` is now stricter.

Before the first matching `br_if 0`, the helper now rejects prefixes that already contain obviously separate void roots such as:

- `drop`
- `local.set`
- `br`
- `br_table`
- `return`
- `block` / `if` with void type
- `loop`
- `try_table`
- `unreachable`

This does not try to perfectly reconstruct raw root boundaries.

- It is a conservative narrowing that aligns the raw detector better with the real HOT matcher.
- The existing carried-guard lift regression still stays green.

## Validation

- Focused perf regression:
  - `moon test src/passes/perf_test.mbt`
  - result: passing after the detector change
- Compare-pass parity:
  - `bun scripts/pass-fuzz-compare.ts --pass remove-unused-brs --generator gen-valid --count 10000 --min-compared 10000 --max-failures 20 --out-dir .tmp/pass-fuzz-rub-genvalid-20260410-false-prefix-guard-10000`
  - result: `10000/10000` compared, `10000/10000` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, `0` command failures
- Artifact trace:
  - `moon run --target native --release src/cmd -- --tracing pass --remove-unused-brs --out .tmp/rub-trace-false-prefix-guard-idle.wasm tests/node/dist/starshine-debug-wasi.wasm`
  - traced totals improved versus the `0077` baseline:
    - RUB pass total: `671669 us` -> `668850 us`
    - lift total: `931152 us` -> `878726 us`
- Hotspot status:
  - `Func 1058` improved from `pass=18500 / lift=9317` to `pass=16053 / lift=7490`
  - `Func 1150` regressed from `pass=15611 / lift=14778` to `pass=16976 / lift=15629`

## Outcome

- The raw structured-return skip no longer lifts a reduced false-positive carried-guard shape that the HOT matcher cannot rewrite.
- The fix is a real net-positive on traced total lift and pass cost.
- The main parser-shaped hotspot pair is still open.

## Remaining Gap

This fix did not retire the current top artifact hotspots outright.

- `Func 1058` still lifts and still reports result-prefix rejects.
- `Func 1150` still lifts and is now the single largest traced pass hotspot.

So the next performance slice should not assume every remaining hotspot is just another raw false positive in the prefix-guard detector.

The next useful question is narrower:

1. why `Func 1150` still enters HOT and only reports `rub-result-prefix reject=inner-op`
2. whether that family wants another raw false-positive fix, a HOT fast-fail guard, or a larger no-op classifier
3. how to reduce it without reopening the real carried-guard parity surface
