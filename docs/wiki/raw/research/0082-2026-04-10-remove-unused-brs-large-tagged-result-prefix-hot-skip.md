---
kind: research
status: completed
last_reviewed: 2026-04-10
sources:
  - ../../../../src/passes/remove_unused_brs.mbt
  - ../../../../src/passes/perf_test.mbt
  - ../../../../agent-todo.md
---

# 0082 - `remove-unused-brs` large tagged result-prefix hot skip

## Scope

- Retire the repeated lifted result-prefix rejection family that became the next visible RUB hotspot after the raw value-`if` / branch skip.
- Keep the living RUB wiki honest about the difference between retiring `Func 356` and actually improving whole-pass runtime.

## Problem

- After `0081`, the native artifact trace at `.tmp/rub-trace-large-value-if-branch-ladder-idle.stderr` still showed:
  - `Func 356` / `dfe__try__rewrite__instruction__type__idxs` at `pass=8317 / lift=4956`
  - repeated `rub-result-prefix reject=inner-op ...` lines before RUB exited with `changed=false`
- The family was a good HOT-skip candidate:
  - it already needed lift, so a raw skip was not the right tool
  - the expensive work was the repeated result-prefix matcher discovery, not an actual rewrite
  - the artifact body contained many result blocks whose first roots were tagged non-`Block` prefixes that could never satisfy the direct carried-guard rewrite

## Reduced Perf Lock

- Added `perf_test_make_large_tagged_result_prefix_ladder_module(...)` in `src/passes/perf_test.mbt`.
- Added perf lock `remove-unused-brs skips large tagged result-prefix ladders after lift`.
- The reduced family intentionally matches the measured artifact envelope:
  - one or two roots
  - hundreds of locals, calls, `local.set`, and `local.tee`
  - no `br_if`, no loops, and no `br_table`
  - many one-result blocks whose first roots are not plain prefix `Block`s

## Change

- Added `remove_unused_brs_can_skip_large_tagged_result_prefix_ladder(...)` in `src/passes/remove_unused_brs.mbt`.
- Added `result_block_non_block_prefix_count` to the shared lifted ladder-shape scan so the tagged detector can reuse the existing full walk instead of paying a second node scan.
- Added a cheap prefilter before that full scan:
  - locals must already be in the measured band
  - roots must already be one or two
  - node count must already be in the broad measured band
- The emitted lifted skip reason is `large-tagged-result-prefix-ladder-noop`.

## Important Cost Lesson

- The first draft of this slice did retire `Func 356`, but it counted tagged result prefixes in a second full walk across every lifted function.
- That first draft produced `.tmp/rub-trace-large-tagged-prefix-idle.stderr`:
  - `Func 356` already reported `skip-hot reason=large-tagged-result-prefix-ladder-noop`
  - traced RUB pass total rose to `712041 us`
  - traced lift total measured `897664 us`
- The landed version keeps the same skip reason but avoids most of that detection overhead by:
  - reusing the shared ladder-shape scan
  - failing fast on locals, roots, and node count before the full walk

## Validation

- `moon test src/passes`
  - `430/430` passing
- `bun scripts/pass-fuzz-compare.ts --pass remove-unused-brs --generator gen-valid --count 10000 --min-compared 10000 --max-failures 20 --out-dir .tmp/pass-fuzz-rub-genvalid-20260410-large-tagged-prefix-10000`
  - `10000/10000` compared
  - `10000` normalized matches
  - `0` mismatches
  - `0` validation failures
  - `0` generator failures
  - `0` command failures
- `bun scripts/pass-fuzz-compare.ts --pass remove-unused-brs --generator both --count 2000 --seed 0x5eed19 --max-failures 5 --out-dir .tmp/pass-fuzz-rub-both-20260410-large-tagged-prefix-2000`
  - `844/844` compared clean
  - `0` mismatches
  - stopped on `5` Binaryen-side command failures
  - failure classes were `1` `binaryen-command-failed` and `4` `binaryen-rec-group-zero`

## Artifact Impact

- Native replay:
  - `moon run --target native --release src/cmd -- --tracing pass --remove-unused-brs --out .tmp/rub-trace-large-tagged-prefix-fastguard-idle.wasm tests/node/dist/starshine-debug-wasi.wasm`
- The landed fastguard replay at `.tmp/rub-trace-large-tagged-prefix-fastguard-idle.stderr` shows:
  - `Func 356` now reports `skip-hot reason=large-tagged-result-prefix-ladder-noop`
  - `Func 356` improved to `pass=683 / lift=6135`
  - the tagged-prefix draft pass total improves from `712041 us` to `692911 us`
- The visible remaining hotspots are now:
  - `Func 1382` at `pass=7879 / lift=80435`
  - `Func 1482` at `pass=7595 / lift=65715`
- Important caveat:
  - the aggregate fastguard trace is still not a clean whole-pass win over the earlier raw value-`if` checkpoint at `.tmp/rub-trace-large-value-if-branch-ladder-idle.stderr` (`601957 us` pass, `794557 us` lift)
  - this slice should therefore be treated as a retired no-op hotspot plus a detector-cost lesson, not as final runtime signoff

## Remaining Work

- Keep future lifted no-op skips on the shared scan path whenever possible instead of adding another whole-function walk.
- The next runtime work is now centered on `Func 1382` / `Func 1482`, which dominate both pass and lift time in the latest tagged-prefix replay.
- I did not rerun the full self-opt compare in this slice.
