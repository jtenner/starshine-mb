# 0079 - RemoveUnusedBrs Mid Unique Tee Floor

## Scope

- Re-check the raw `unique-loop-select-return-ladder-noop` classifier after the false-prefix fix.
- Confirm whether lowering the `local_tee` floor from `20` to `16` retires the current traced hotspot or only reclassifies an already-no-op family.
- Record the current artifact mapping so later work does not chase the wrong function.

## Problem

After `0078`, the next traced unchanged hotspot pair was still:

- `Func 1150`
- `Func 1058`

The first follow-up hypothesis was that the narrower loop/select raw classifier was still too strict:

- `run_hot_pipeline_raw_remove_unused_brs_can_skip_unique_loop_select_return_ladder(...)`
- old bound: `shape.local_tee_count >= 20`

An initial reading of the debug WAT suggested the current `Func 1150` family looked close to that shape.

That reading turned out to be wrong.

- the sixteen-tee loop/select family in the artifact is `Func 1171`
- the real `Func 1150` hotspot is `wt__lower__module`
- `Func 1150` is a much larger carrier-heavy builder with roughly:
  - `1372` calls
  - `975` `local.tee`
  - `751` `local.set`
  - `302` `if`
  - `250` blocks
  - `27` loops
  - `239` plain `br`
  - `3` `br_table`
  - `29` returns
  - `1` `select`

So the tee-floor slice was never going to retire `Func 1150`.

## Reduced Repro

The focused perf lock is:

- helper: `perf_test_make_mid_unique_loop_select_return_ladder_module(...)`
- test: `remove-unused-brs skips mid unique loop-select return ladders without hot lift`

The important detail is not just the tee count.

- the reduced shape uses exactly `16` `local.tee`
- it also keeps the total instruction surface above the unique classifier's lower bound
- before the final fixture tuning, the repro was too small and fell back to `structured-return-ladder-noop`

The final reduced family now proves the intended boundary:

- before the tee-floor change it missed the unique classifier
- after the tee-floor change it reports `skip-raw reason=unique-loop-select-return-ladder-noop`

## Fix

The unique raw classifier now accepts:

- `shape.local_tee_count >= 16`

instead of:

- `shape.local_tee_count >= 20`

No other unique-loop/select bounds changed.

This keeps the classifier narrow:

- same locals window
- same instruction-count window
- same `call`, `local.set`, `if`, `return`, `select`, `br_if`, block, loop, `br`, and `drop` bounds

## Validation

- Focused and full pass tests:
  - `moon test src/passes`
  - result: `427/427` passing
- Compare-pass parity:
  - `bun scripts/pass-fuzz-compare.ts --pass remove-unused-brs --generator gen-valid --count 10000 --min-compared 10000 --max-failures 20 --out-dir .tmp/pass-fuzz-rub-genvalid-20260410-unique-tee16-10000`
  - result: `10000/10000` compared, `10000/10000` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, `0` command failures
- Artifact replay:
  - `moon run --target native --release src/cmd -- --tracing pass --remove-unused-brs --out .tmp/rub-trace-mid-unique-tee16-idle.wasm tests/node/dist/starshine-debug-wasi.wasm`
  - `Func 1171` now reports `skip-raw reason=unique-loop-select-return-ladder-noop`
  - `Func 1150` still lifts and reports `rub-result-prefix reject=inner-op block=2923 op=LocalSet`
  - `Func 1058` still lifts and reports the earlier result-prefix rejects
  - hotspot deltas versus the `0078` trace:
    - `Func 1150`: `pass=16976 / lift=15629` -> `pass=15707 / lift=15431`
    - `Func 1058`: `pass=16053 / lift=7490` -> `pass=15540 / lift=8114`
  - total traced runtime is not a clean win:
    - pass total: `668850 us` -> `682234 us`
    - lift total: `878726 us` -> `963261 us`

## Outcome

- The unique loop/select raw classifier now covers the intended sixteen-tee mid-band family.
- The slice is parity-clean.
- The slice reclassifies an already-no-op artifact family (`Func 1171`); it does not retire the actual `Func 1150` hotspot.

## Remaining Gap

The next useful performance question is still the same one from `0078`, but with the mapping corrected:

1. why `Func 1150` / `wt__lower__module` still enters HOT and only reports `rub-result-prefix reject=inner-op`
2. whether that giant carrier-heavy family wants a new raw no-op classifier, a cheaper lifted fast-fail, or both
3. how to reduce it without mis-classifying the unrelated `Func 1171` loop/select family again
