# Tuple Optimization Aggregate Rewrite Timers

Date: 2026-06-29

## Question

Can the current candidate-heavy `tuple-optimization` performance blocker be reduced without changing transform behavior by removing per-group perf trace emission from the hottest rewrite loop?

## Context

The previous scalarized tuple-local cleanup fast-skip removed `cleanup-post-rewrite:scalarized-tuple-locals` as a material owner on the pure/drop-only candidate-heavy fixture. A fresh 1000-pair probe on the rebuilt native binary still showed Starshine far outside the pass-local target:

- `.tmp/to-passlocal-candidate-heavy-1000-20260629-current-probe`
- Starshine/Binaryen pass time: `40.058ms / 0.421ms`
- Detail totals included `rewrite-group-defs:source` `22.977ms`, `rewrite-group-defs:elide-simple-drop-only-source` `15.850ms`, and `prune-nops` `4.251ms`.

Inspection showed the source and simple-drop-only timers were emitted once per candidate group, producing thousands of timing lines on the candidate-heavy fixture. That instrumentation overhead was inside the measured pass-local region and obscured the remaining real rewrite costs.

## Change

Added a red-first white-box performance invariant in `src/passes/tuple_optimization_wbtest.mbt`:

- `tuple-optimization rewrite detail timers aggregate many source groups`

The test builds three independent simple pure/drop-only source groups and requires only one emitted timing line each for:

- `detail:tuple-optimization:rewrite-group-defs:source`
- `detail:tuple-optimization:rewrite-group-defs:elide-simple-drop-only-source`
- `detail:tuple-optimization:rewrite-group-defs:elide-simple-drop-only-source:replace-defs`

Before implementation it failed with `3 != 1` for the source timer.

Implementation added package-local perf helpers in `src/passes/pass_manager.mbt`:

- `perf_stop_timer_accumulate_opt(...)` records elapsed time into the existing timer totals without tracing a line.
- `perf_emit_timer_total_opt(...)` emits one aggregate timer line after the hot loop.

`src/passes/tuple_optimization.mbt` now accumulates per-group source/copy/drop-only-elision sub-timers quietly and emits their aggregate totals once after all group rewrites. Transform code and replacement behavior are unchanged.

## Validation

- Red-first focused test before implementation:
  - `moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt --filter '*rewrite detail timers aggregate*'`
  - Failed as intended: `3 != 1`.
- Focused test after implementation:
  - same command: passed `1/1`.
- Focused TO white-box file:
  - `moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt`
  - passed `52/52`.
- Focused pass package:
  - `moon test src/passes`
  - passed `3607/3607`.
- Native build:
  - `moon build --target native --release src/cmd`
  - passed with the pre-existing unused-function warnings in `src/passes/pass_manager.mbt`.
- General direct GenValid smoke:
  - `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass tuple-optimization --out-dir .tmp/pass-fuzz-tuple-optimization-genvalid-1000-aggregate-rewrite-timers --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures`
  - compared `1000/1000`, normalized `1000`, mismatches `0`, validation/generator/property/command failures `0`, Binaryen cache `1000/0`.
- Dedicated bounded profile smoke:
  - `bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass tuple-optimization --gen-valid-profile tuple-optimization-all --out-dir .tmp/pass-fuzz-tuple-optimization-genvalid-profile-100-aggregate-rewrite-timers --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 65 --keep-going-after-command-failures`
  - stopped at the mismatch cap after `80/100` compared, `80` raw mismatches, zero validation/generator/property/command failures, selected/profile labels spill `33`, tee `12`, copy-chain `35`.
  - Agent classification: same known simple type-indexed pure/drop-only scalar-spelling residual surface; this slice changed timing emission only and did not broaden the residual classification.
- Formatting/checks:
  - `moon fmt && git diff --check` passed.

## Performance

Candidate-heavy direct `--tuple-optimization` timing after aggregate rewrite timers:

| pairs | Starshine pass | Binaryen pass |
| ---: | ---: | ---: |
| 100 | `1.170ms` | `0.042ms` |
| 500 | `7.932ms` | `0.241ms` |
| 1000 | `24.379ms` | `0.295ms` |
| 2000 | `78.062ms` | `0.938ms` |

Out dirs:

- `.tmp/to-passlocal-candidate-heavy-100-20260629-aggregate-rewrite-timers`
- `.tmp/to-passlocal-candidate-heavy-500-20260629-aggregate-rewrite-timers`
- `.tmp/to-passlocal-candidate-heavy-1000-20260629-aggregate-rewrite-timers`
- `.tmp/to-passlocal-candidate-heavy-2000-20260629-aggregate-rewrite-timers`

The 1000-pair detail totals after the change:

- `rewrite-use-def-build`: `4.789ms`
- `ensure-split-locals`: `2.000ms`
- `rewrite-group-defs`: `10.145ms`
- `rewrite-group-defs:source`: `9.780ms`
- `rewrite-group-defs:elide-simple-drop-only-source`: `5.808ms`
- `rewrite-group-defs:elide-simple-drop-only-source:replace-defs`: `4.541ms`
- `prune-nops`: `4.228ms`
- `cleanup-post-rewrite`: `4.913ms`

This is a large kept measurement improvement over the cleaner previous representative rerun (`2.766ms`, `17.776ms`, `36.571ms`, `100.860ms` for 100/500/1000/2000 pairs), but TO still misses the project pass-local target by a wide margin.

## Remaining work

- Continue performance work. Remaining owners on the candidate-heavy fixture are now actual rewrite and cleanup costs rather than per-group trace emission:
  - `rewrite-group-defs:source` / simple drop-only replacement work,
  - `prune-nops`,
  - rewrite-time `use_def` construction,
  - split-local preparation.
- Do not revisit per-group root splicing. If root/nop cleanup is revisited, use a true pass-level batch rewrite that mutates each region once.
- Full TO audit closeout remains open: broader behavior surface, exact-slot/neighborhood evidence, full compare-pass ladder, 100k lane(s), and final docs/backlog sync are still incomplete.
