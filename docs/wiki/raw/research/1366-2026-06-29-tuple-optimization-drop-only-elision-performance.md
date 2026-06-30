---
kind: research
status: working
last_reviewed: 2026-06-29
sources:
  - ../../../binaryen/passes/tuple-optimization/parity.md
  - ../../../binaryen/passes/tuple-optimization/fuzzing.md
  - ../../../../src/passes/tuple_optimization.mbt
  - ../../../../src/passes/tuple_optimization_wbtest.mbt
  - ../../../../agent-todo.md
---

# Tuple Optimization Pure Drop-Only Elision Performance Slice

## Question

The previous root-slot slice reduced one `rewrite-group-defs` contributor but the synthetic candidate-heavy fixtures were still far outside the pass-local target. This slice tested a narrow follow-up: avoid the root-prefix insertion path entirely for simple pure type-indexed source groups whose scalar lanes are all drop-only.

## Change

`tuple-optimization` now recognizes simple two-lane `i32, i64` type-indexed block source groups whose payload lanes are pure constants or `local.get`s, whose defining `local.set`/direct-drop `local.tee` nodes have no non-drop uses, and whose lane locals only feed direct drops. For that surface, the pass elides the source definitions directly instead of allocating dedicated split locals and inserting per-group prefix `local.set`s.

The elision path is deliberately narrow:

- no copy-source group;
- simple two-lane `i32, i64` type-indexed block producer;
- block payload contains no prefix roots and only cloneable pure lane values;
- lane locals have only direct drop reads, not scalar-forward/copy or non-drop uses;
- `local.tee` definitions are allowed only when the tee result itself is directly dropped.

Because this path only removes pure values that are otherwise dropped, it is a Starshine-owned size/performance win rather than a broader Binaryen-spelling parity claim. Broader type, lane-count, non-drop, and effect/trap surfaces remain outside this classification.

The first implementation used the normal replacement helper per defining node. A small follow-up batches cache invalidation/trace marking inside this elision path by using direct HOT node replacement and calling `pass_mark_mutated` once per group.

## Red-First Coverage

Focused type-indexed white-box expectations were tightened before implementation:

```sh
moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt --filter '*type-indexed block*'
```

The two updated tests initially failed because the current rewrite still emitted two `local.set` operations through split locals for both spill and tee fixtures. After implementation the same focused lane passes, and the full tuple white-box file still passes.

## Candidate-Heavy Measurement

Regenerated the missing 2000-pair fixture as `.tmp/to-perf/tuple-candidate-heavy-2000.{wat,wasm}` using the same independent two-lane type-indexed spill pattern as the existing 100/500/1000 fixtures.

Final timing commands after rebuilding `_build/native/release/build/cmd/cmd.exe`:

```sh
for n in 100 500 1000 2000; do
  bun scripts/self-optimize-compare.ts \
    .tmp/to-perf/tuple-candidate-heavy-${n}.wasm \
    --starshine-bin _build/native/release/build/cmd/cmd.exe \
    --out-dir .tmp/to-passlocal-candidate-heavy-${n}-20260629-drop-only-elide-batched-mark \
    --timing-only \
    --tuple-optimization
done
```

Results versus the prior root-slot best:

| Pairs | Prior Starshine/Binaryen pass | New Starshine/Binaryen pass | Prior `rewrite-group-defs` | New `rewrite-group-defs` | Notes |
| ---: | ---: | ---: | ---: | ---: | --- |
| 100 | `2.944ms / 0.047ms` | `1.916ms / 0.038ms` | `2.070ms` | `1.402ms` | cleanup `0.249ms`, use-def build `0.239ms`, ensure splits `0.043ms` |
| 500 | `31.320ms / 0.144ms` | `21.425ms / 0.143ms` | `23.919ms` | `16.835ms` | cleanup `2.241ms`, use-def build `1.570ms`, ensure splits `0.498ms` |
| 1000 | `116.342ms / 0.369ms` | `73.728ms / 0.263ms` | `92.264ms` | `65.410ms` | cleanup `8.057ms`, use-def build `4.050ms`, ensure splits `1.789ms` |
| 2000 | prior root-slot datapoint absent | `291.755ms / 0.557ms` | prior root-slot datapoint absent | `250.428ms` | cleanup `27.186ms`, use-def build `12.066ms`, ensure splits `6.638ms` |

An intermediate run before batching the mutation mark produced slightly slower 100/500/1000/2000 Starshine pass times of `2.093ms`, `21.838ms`, `81.034ms`, and `301.090ms`; the batched-mark run above supersedes it for this slice.

## Dedicated Profile Residual Measurement

The bounded dedicated profile remains raw-red but stays inside the simple pure/drop-only scalar-spelling family:

```sh
bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed \
  --pass tuple-optimization \
  --gen-valid-profile tuple-optimization-all \
  --out-dir .tmp/pass-fuzz-tuple-optimization-genvalid-profile-100-drop-only-elide-batched-mark \
  --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --max-failures 50 \
  --keep-going-after-command-failures
```

Result: stopped at the mismatch cap after `65 / 100` compared, with zero validation/generator/property/command failures and `65` raw mismatches. Selected profiles and labels were spill `26`, tee `10`, and copy-chain `29`.

A local measurement over the 65 failure dirs found uniform Starshine raw-size/op wins and no size regressions:

| Label | Count | Avg Starshine raw-byte delta | Avg local-decl delta | Avg effective WAT-op delta |
| --- | ---: | ---: | ---: | ---: |
| `tuple-optimization:spill` | 26 | `-22.0` | `0.0` | `-11.0` |
| `tuple-optimization:tee` | 10 | `-20.0` | `0.0` | `-10.0` |
| `tuple-optimization:copy-chain` | 29 | `-20.0` | `0.0` | `-10.0` |

This updates the narrow Starshine-win classification for the current simple pure/drop-only profile surface, but it still does not classify broader type/lane/effect/non-drop surfaces.

## Correctness Checks

- Red-first focused type-indexed tests failed before implementation with two residual `local.set` operations in each fixture.
- `moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt --filter '*type-indexed block*'` => `2 / 2` passed after implementation.
- `moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt` => `50 / 50` passed.
- `moon test src/passes` => `3605 / 3605` passed.
- `moon build --target native --release src/cmd` => completed with existing unused-function warnings in `src/passes/pass_manager.mbt`.
- `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass tuple-optimization --out-dir .tmp/pass-fuzz-tuple-optimization-genvalid-1000-drop-only-elide-batched-mark --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 50 --keep-going-after-command-failures` => `1000 / 1000` compared, `1000` normalized matches, zero validation/generator/property/command failures, Binaryen cache `1000 / 0`.
- `moon fmt`, `git diff --check`, and `moon info` completed; `moon info` reported only pre-existing warnings in `src/binary`, `src/ir`, and `src/validate`.

## Interpretation

This is another real localized speed win: the 1000-pair fixture improves from `116.342ms` to `73.728ms` pass-local Starshine time after the root-slot slice, and from `153.200ms` to `73.728ms` versus the detail-timer baseline. It still does not close the pass-local blocker. Even after pure drop-only elision, Starshine remains far outside the target on this synthetic candidate-heavy surface; `rewrite-group-defs` remains dominant and grows sharply with pair count.

The remaining likely owner is not root-prefix insertion for the simple pure/drop-only source family anymore. The next slice should add narrower sub-timers or optimize the per-definition replacement/mutation work inside `rewrite-group-defs`, plus the post-rewrite cleanup that scans the enlarged function after many replacements.

## Remaining Work

- Keep TO audit open; do not pin the original/main thread.
- Continue performance work inside `rewrite-group-defs`, now focusing on per-definition replacement/mutation cost and cleanup rather than root-slot lookup or simple pure drop-only prefix insertion.
- Keep dedicated-profile raw-red classification narrow until broader type/lane/effect/non-drop surfaces are inspected or implemented.
- Final TO closeout still needs exact-slot/neighborhood evidence and the full required 100k/10k pass-fuzz matrix.
