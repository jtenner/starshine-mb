---
kind: research
status: working
date: 2026-06-29
sources:
  - ../../../../src/passes/tuple_optimization.mbt
  - ../../../../src/passes/tuple_optimization_wbtest.mbt
  - ../../../../src/ir/hot_region_edit.mbt
  - ../../binaryen/passes/tuple-optimization/parity.md
  - ../../binaryen/passes/tuple-optimization/fuzzing.md
---

# Tuple Optimization Targeted Root Removal And Fast Root Replacement

## Goal

Continue the `tuple-optimization` O4z audit performance closeout by reducing the post-rewrite pure/drop-only source-root cleanup owner without changing transform behavior.

## Red-First Guard

Added a white-box performance invariant to `src/passes/tuple_optimization_wbtest.mbt` for the pure/drop-only batched root-removal fixture:

- the fixture must still emit the top-level `cleanup-post-rewrite:remove-elided-drop-only-roots` timer;
- it must take a new targeted-region cleanup path when there are deferred root removals and no pre-existing/generated nops;
- it must not take the new full-region-scan subpath or the separate `prune-nops` path.

Before implementation the focused command failed because the trace only had the top-level removal timer and no `...:targeted-regions` subphase:

```sh
moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt --filter '*batched root removal skips nop prune*'
```

## Implementation

`src/passes/tuple_optimization.mbt` now records enough cleanup-plan facts to avoid recursively scanning the whole function when the narrow pure/drop-only elision path only needs to remove known root definitions:

- `HotTupleOptimizationRewriteCleanupPlan` carries the unique regions containing deferred removable roots.
- It also records whether the input had live `nop` nodes before rewrite.
- The simple drop-only elision path records each removable `local.set` root's containing region when the use-def-bounded root-slot lookup succeeds.
- Post-rewrite cleanup uses the targeted-region remover when there are no generated nops and no pre-existing nops; otherwise it keeps the old full scan so pre-existing nops are still pruned in the historical no-generated-nops path.

The initial targeted-region implementation exposed a second bottleneck: root-region `hot_region_replace_body(...)` went through `hot_root_splice(0, root_count, roots)`, which removes and reinserts root entries one at a time. `src/ir/hot_region_edit.mbt` now special-cases root-region body replacement by copying old roots for the return value, validating new roots, clearing `func.roots`, pushing the new roots, and bumping the HOT revision once. This preserves the existing `hot_region_replace_body` behavior while avoiding quadratic root-vector churn on large root regions.

## Focused Validation

- Red-first focused test before implementation: failed as intended on the missing `...:targeted-regions` timer.
- `moon test --package jtenner/starshine/ir --file hot_region_edit_test.mbt` — passed `3/3` with an existing `hot_verify.mbt` unreachable-code warning.
- `moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt --filter '*batched root removal skips nop prune*'` — passed `1/1` after implementation.
- `moon test --package jtenner/starshine/passes --file tuple_optimization_wbtest.mbt` — passed `54/54`.
- `moon test src/passes` — passed `3609/3609`.
- `moon build --target native --release src/cmd` — passed with pre-existing unused-function warnings in `src/passes/pass_manager.mbt` plus the existing `hot_verify.mbt` unreachable-code warning.
- `moon fmt && git diff --check` — passed.

## Direct Compare Evidence

General direct GenValid smoke after rebuilding native Starshine:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass tuple-optimization --out-dir .tmp/pass-fuzz-tuple-optimization-genvalid-1000-fast-root-replace --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures
```

Result: `1000/1000` compared, `1000` normalized matches, zero mismatches, zero validation/generator/property/command failures, Binaryen cache `1000/0`.

Bounded dedicated profile lane:

```sh
bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass tuple-optimization --gen-valid-profile tuple-optimization-all --out-dir .tmp/pass-fuzz-tuple-optimization-genvalid-profile-100-fast-root-replace --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 65 --keep-going-after-command-failures
```

Result: stopped at the mismatch cap after `80/100` compared, `80` raw mismatches, zero validation/generator/property/command failures, Binaryen cache `80/0`. Selected profiles and manifest labels stayed in the known narrow simple pure/drop-only scalar-spelling surface: spill `33`, tee `12`, copy-chain `35`; input effect/trap counts were all zero. This slice does not broaden the residual classification.

## Pass-Local Timing

Candidate-heavy timing command shape:

```sh
bun scripts/self-optimize-compare.ts .tmp/to-perf/tuple-candidate-heavy-${n}.wasm --starshine-bin _build/native/release/build/cmd/cmd.exe --out-dir .tmp/to-passlocal-candidate-heavy-${n}-20260629-fast-root-replace --timing-only --tuple-optimization
```

Post-slice Starshine/Binaryen pass-local timings:

| pairs | Starshine | Binaryen |
| ---: | ---: | ---: |
| 100 | `0.454ms` | `0.032ms` |
| 500 | `2.907ms` | `0.152ms` |
| 1000 | `8.606ms` | `0.345ms` |
| 2000 | `30.561ms` | `0.880ms` |

This improves over the previous kept use-def-reuse timings (`0.505ms`, `4.132ms`, `14.528ms`, `49.278ms`) but remains far outside the pass-local target.

Representative 1000-pair detail totals after the fast root replacement:

- `build-rewrite-mask`: `0.776ms`
- `ensure-split-locals`: `1.858ms`
- `rewrite-group-defs`: `4.452ms`
- `rewrite-group-defs:source`: `4.353ms`
- `rewrite-group-defs:elide-simple-drop-only-source`: `1.116ms`
- `rewrite-group-defs:elide-simple-drop-only-source:replace-defs`: `0.438ms`
- `cleanup-post-rewrite:remove-elided-drop-only-roots:targeted-regions`: `0.189ms`
- `cleanup-post-rewrite`: `0.359ms`

The former cleanup traversal/root-replacement owner is largely gone on this fixture. Remaining owners are actual source rewrite, split-local preparation, and rewrite-mask construction.

## Current Classification

Behavior is intended unchanged: no mutation happens between analysis/rewrite-mask construction and the first rewrite mutation, and the targeted root-removal path only removes the exact roots already identified by the pre-mutation use-def root-slot lookup. The fallback full scan remains for generated nops or pre-existing nops to preserve the earlier nop-pruning behavior.

TO closeout remains incomplete. The pass still misses the pass-local target by a wide margin, the dedicated profile remains raw-red in the narrow measured Starshine-win scalar-spelling family, exact-slot/neighborhood evidence is still pending, and the full required 100k closeout ladder has not run.
