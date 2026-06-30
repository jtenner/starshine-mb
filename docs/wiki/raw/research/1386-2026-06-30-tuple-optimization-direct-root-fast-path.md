---
kind: research
status: superseding-active
date: 2026-06-30
sources:
  - ../../binaryen/passes/tuple-optimization/parity.md
  - ../../binaryen/passes/tuple-optimization/fuzzing.md
  - ../../binaryen/passes/tuple-optimization/index.md
  - ../../../../src/passes/tuple_optimization.mbt
  - ../../../../src/passes/tuple_optimization_wbtest.mbt
  - ../../../../agent-todo.md
---

# Tuple Optimization Direct Root Fast Path

## Question

After the pre-collect root fast path, is there still a reasonable TO-owned optimization that avoids building full seed-group arrays on the exact simple function-root drop-only fixture?

## Red-first guard

Updated the exact source-only/no-host/local-set/drop-only perf-detail fixture to require `detail:tuple-optimization:direct-simple-drop-only-root-elision-fast-path` and to reject both the ordinary `collect-seed-groups` timer and the pre-collect root-elision timer on that exact direct path.

The focused test failed before implementation because the pre-collect timer still appeared and the direct timer was absent.

## Change kept

`tuple_optimization_run` now first tries a narrower direct recognizer before building `HotTupleOptimizationGroup` arrays. The recognizer scans live multivalue producers and classifies each as:

- not a seed group,
- an exact direct root-elision candidate, or
- a seed group that requires ordinary full analysis.

The direct path succeeds only if every collected seed group is the same narrow function-root candidate:

- two-lane type-indexed control producer,
- `i32, i64` lane locals,
- exact simple block payload roots,
- every producer use is a child slot of a `local.set`, not a `local.tee`,
- every lane definition is a single function-root use,
- every lane local has exactly one write, and
- every lane read is a live direct `local.get -> drop` use.

If any seed group needs broader TO logic, the direct recognizer returns `None` and the previous pre-collect/full-analysis fallback remains available.

## Validation

- Red-first focused command before implementation:
  - `moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt --filter '*perf detail timers attribute analysis and rewrite phases*'`
  - failed because `pre-collect-simple-drop-only-root-elision-fast-path` was still emitted and the direct timer was absent.
- After implementation:
  - `moon fmt && moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt` passed, `56/56`.
  - `moon test src/passes` passed, `3611/3611`.
  - `moon build --target native --release src/cmd` passed with existing unused-function warnings in `src/passes/pass_manager.mbt`.
- Ordinary direct GenValid smoke:
  - `.tmp/pass-fuzz-tuple-optimization-genvalid-1000-direct-root-fast`
  - compared `1000/1000`, normalized `1000`, zero validation/generator/property/command failures, zero mismatches, Binaryen cache `1000/0`.
- Bounded dedicated profile smoke:
  - `.tmp/pass-fuzz-tuple-optimization-genvalid-profile-100-direct-root-fast`
  - stopped at `80/100`, with `80` raw mismatches, zero validation/generator/property/command failures, Binaryen cache `80/0`.
  - Selected/profile labels remain spill `33`, tee `12`, copy-chain `35`.
  - Agent classification remains unchanged: same known simple type-indexed pure/drop-only scalar-spelling residual surface; this performance slice does not broaden the narrow Starshine-win classification.

## Candidate-heavy timings

Timing-only command shape:

```sh
bun scripts/self-optimize-compare.ts .tmp/to-perf/tuple-candidate-heavy-${n}.wasm \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --out-dir .tmp/to-passlocal-candidate-heavy-${n}-20260630-direct-root-fast \
  --timing-only --tuple-optimization
```

First-run Starshine/Binaryen pass-local timings:

| pairs | Starshine ms | Binaryen ms | target met? |
|---:|---:|---:|:---|
| 100 | 0.140 | 0.056 | no |
| 500 | 0.508 | 0.155 | no |
| 1000 | 0.956 | 0.293 | no |
| 2000 | 1.900 | 0.687 | no |

The 1000-pair detail trace (`.tmp/to-passlocal-candidate-heavy-1000-20260630-direct-root-fast/starshine.stderr.txt`) reports:

- `direct-simple-drop-only-root-elision-fast-path`: `0.504ms`
- `validate-function-root-groups`: `0.500ms`
- `single-root-region-fast-path`: `0.487ms`
- targeted removable-root cleanup: `0.420ms`
- `simple-drop-only-root-elision-fast-path`: `0.442ms`
- `pass:tuple-optimization`: `0.956ms`

## Interpretation

This is the largest remaining reasonable algorithmic win from the previous state: the exact direct fixture no longer builds full seed-group arrays before root elision. It still misses the formal pass-local target on this synthetic candidate-heavy stress fixture, but the absolute pass-local time is now sub-millisecond at 1000 pairs and about two milliseconds at 2000 pairs.

Remaining TO-owned optimization ideas are much narrower:

- specialize/remodel the root cleanup for function-root removal, currently about `0.420ms` at 1000 pairs;
- fuse or trim use-def validation checks in the direct recognizer, currently about `0.504ms` at 1000 pairs; or
- reduce detail timer overhead once attribution is no longer needed.

Given the user's 2026-06-30 caveat, if a cleanup-specialization probe does not produce a clear safe win, this pass is a candidate for evidence-backed soft acceptance despite missing the formal target, provided final signoff lanes and residual mismatch classifications are completed and documented.
