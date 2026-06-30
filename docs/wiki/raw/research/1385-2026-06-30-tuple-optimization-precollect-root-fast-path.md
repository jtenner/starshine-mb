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

# Tuple Optimization Pre-Collect Root Fast Path

## Question

Can the narrow exact source-only/no-host/local-set/drop-only root-elision fixture avoid the duplicated TO seed-collection plus fast-path validation/root-region scans?

## Red-first guard

Updated `tuple_optimization_wbtest.mbt` so the exact simple source-only/no-host/local-set/drop-only perf fixture must:

- emit `detail:tuple-optimization:pre-collect-simple-drop-only-root-elision-fast-path`,
- emit `detail:tuple-optimization:simple-drop-only-root-elision-fast-path:validate-function-root-groups`,
- emit `detail:tuple-optimization:simple-drop-only-root-elision-fast-path:single-root-region-fast-path`,
- still emit `detail:tuple-optimization:simple-drop-only-root-elision-fast-path`, and
- not emit the old `detail:tuple-optimization:collect-seed-groups` timer on this exact direct fast path.

The focused test failed before implementation because the old `collect-seed-groups` timer was still present and the pre-collect timer was absent.

## Change kept

`tuple_optimization_run` now uses `tuple_optimization_collect_seed_groups_with_simple_root_elision(...)` for the first pass over HOT nodes. That scan still returns the seed groups needed by the ordinary analysis fallback, but it also attempts to record a cleanup plan for the narrow direct root-elision surface while collecting seeds.

The fast path remains intentionally narrow:

- source group only; no copy source;
- no host lane;
- simple `i32, i64` type-indexed block payload with exact simple payload roots;
- every lane definition is a live `local.set` root;
- every lane local has exactly one write;
- every lane local read is a live direct `local.get -> drop` use; and
- every removable root definition has a single function-root use.

If any collected seed group fails those checks, TO keeps the collected groups and falls back to the ordinary full analysis/rewrite path.

## Validation

- Red-first focused command before implementation:
  - `moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt --filter '*perf detail timers attribute analysis and rewrite phases*'`
  - failed because `collect-seed-groups` was still emitted and `pre-collect-simple-drop-only-root-elision-fast-path` was absent.
- After implementation:
  - `moon fmt && moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt` passed, `56/56`.
  - `moon test src/passes` passed, `3611/3611`.
  - `moon build --target native --release src/cmd` passed with existing unused-function warnings in `src/passes/pass_manager.mbt`.
- Ordinary direct GenValid smoke:
  - `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass tuple-optimization --out-dir .tmp/pass-fuzz-tuple-optimization-genvalid-1000-precollect-root-fast-final --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures`
  - compared `1000/1000`, normalized `1000`, zero validation/generator/property/command failures, zero mismatches, Binaryen cache `1000/0`.
- Bounded dedicated profile smoke:
  - `bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass tuple-optimization --gen-valid-profile tuple-optimization-all --out-dir .tmp/pass-fuzz-tuple-optimization-genvalid-profile-100-precollect-root-fast-final --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 65 --keep-going-after-command-failures`
  - stopped at the mismatch cap after `80/100`, with `80` raw mismatches, zero validation/generator/property/command failures, Binaryen cache `80/0`.
  - selected/profile labels over compared cases: spill `33`, tee `12`, copy-chain `35`.
  - Agent classification remains unchanged: same known simple type-indexed pure/drop-only scalar-spelling residual surface; this performance slice does not broaden the narrow Starshine-win classification.

## Candidate-heavy timings

Timing-only command shape:

```sh
bun scripts/self-optimize-compare.ts .tmp/to-perf/tuple-candidate-heavy-${n}.wasm \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --out-dir .tmp/to-passlocal-candidate-heavy-${n}-20260630-precollect-root-fast-final \
  --timing-only --tuple-optimization
```

First-run Starshine/Binaryen pass-local timings:

| pairs | Starshine ms | Binaryen ms | target met? |
|---:|---:|---:|:---|
| 100 | 0.189 | 0.033 | no |
| 500 | 0.648 | 0.142 | no |
| 1000 | 1.201 | 0.450 | no |
| 2000 | 3.150 | 0.748 | no |

The 1000-pair detail trace (`.tmp/to-passlocal-candidate-heavy-1000-20260630-precollect-root-fast-final/starshine.stderr.txt`) reports:

- `pre-collect-simple-drop-only-root-elision-fast-path`: `0.749ms`
- `validate-function-root-groups`: `0.746ms`
- `single-root-region-fast-path`: `0.735ms`
- targeted removable-root cleanup: `0.394ms`
- `simple-drop-only-root-elision-fast-path`: `0.413ms`
- `pass:tuple-optimization`: `1.201ms`

## Interpretation

This is forward progress but not closeout. The pre-collect path avoids the old full-analysis timers on the exact fixture and removes the separate `collect-seed-groups` timer from that direct path, but pass-local timings remain outside the project target and are noisy. Compared with the prior root-elision slice's first-run trend (`0.165/0.040`, `0.676/0.192`, `1.522/0.316`, `2.933/0.762` ms), this slice improves 500/1000 pairs in the first run but regresses or stays noisy on 100/2000 pairs.

Remaining TO-owned owners are still seed/pre-collect validation, direct root cleanup, and untraced pass overhead. The next likely high-leverage direction is a true no-allocation direct recognizer that avoids building full seed-group arrays when the exact function-root fast path succeeds, while preserving the ordinary collected groups for fallback or bailing early enough not to regress non-candidate functions.
