---
kind: entity
status: supported
last_reviewed: 2026-05-06
sources:
  - ../../../raw/research/0535-2026-05-06-merge-locals-direct-revalidation.md
  - ../../../raw/binaryen/2026-05-05-merge-locals-current-main-recheck.md
  - ../../../raw/research/0485-2026-05-05-merge-locals-current-main-recheck.md
  - ../../../raw/binaryen/2026-05-04-merge-locals-current-main-recheck.md
  - ../../../raw/research/0441-2026-05-04-merge-locals-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-25-merge-locals-current-main-source-correction.md
  - ../../../raw/research/0363-2026-04-25-merge-locals-source-correction-and-test-map.md
  - ../../../raw/binaryen/2026-04-23-merge-locals-primary-sources.md
  - ../../../raw/research/0272-2026-04-23-merge-locals-primary-sources-and-source-correction-followup.md
  - ../../../raw/research/0128-2026-04-20-merge-locals-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../tracker.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./local-graph-and-copy-influences.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../optimize-casts/index.md
  - ../local-subtyping/index.md
  - ../coalesce-locals/index.md
  - ../tracker.md
supersedes:
  - ../../../raw/research/0441-2026-05-04-merge-locals-current-main-recheck.md
---

# `merge-locals`

## Role

`merge-locals` is an upstream Binaryen copy-balancing pass.
It rewrites copy-shaped local traffic (`local.set $x (local.get $y)`) by temporarily exposing a trivial `local.tee`, then retargeting influenced gets to either the source local or the destination local when the `LocalGraph` proof says the move is still single-set and type-safe.
The pass is DWARF-sensitive: the reviewed source still reports `invalidatesDWARF() == true`.

It now has an active Starshine module-pass implementation for direct `--merge-locals` execution. The landed slice rewrites same-typed copy-shaped local traffic by retargeting later source-local gets to the destination local until either side is written, and wires the O4z pass name through the registry, dispatcher, tests, compare harness, and artifact lane. Broader LocalGraph-equivalent control-flow retargeting remains future work before preset scheduling.

So the beginner mental model is **copy-shape local traffic balancing with graph-checked retargeting**, not generic local-slot coalescing and not the stale one-set/local-simple-value story.

## Why it matters

- The saved generated-artifact `-O4z` audit recorded `merge-locals` as skipped top-level slot `27`.
- Binaryen's debug log for that replay showed repeated nested `merge-locals` executions under stronger optimize/shrink settings.
- The pass sits in the same late local-cleanup neighborhood as:
  - [`../optimize-casts/index.md`](../optimize-casts/index.md)
  - [`../local-subtyping/index.md`](../local-subtyping/index.md)
  - [`../coalesce-locals/index.md`](../coalesce-locals/index.md)
- The 2026-05-05 current-main recheck keeps that correction fresh without changing the reviewed `MergeLocals.cpp` contract.

## Inputs and outputs

### Input surface

Inside one Binaryen function, the pass observes:

- copy-shaped `local.set` / `local.get` pairs
- the local indices on the source side and destination side of each copy
- `LocalGraph` set-influence information for the original and synthetic tee nodes
- type equality on the influenced gets that may be retargeted

### Output surface

The pass can rewrite:

- influenced `local.get` indices, retargeting them toward either the source local or the destination local
- the copy-shaped `local.set` itself, by stripping the temporary tee wrapper after the rewrite
- local identity, which is why the pass invalidates DWARF

It does **not** rewrite function signatures, heap types, globals, imports, exports, or general slot-coloring layout.

## Invariants and correctness constraints

- **Copy-shaped candidate:** the pass starts from a `local.set` fed by a `local.get` of a different local.
- **Graph proof:** retargeting is only allowed when the eager `LocalGraph` snapshot says the influenced gets still have the intended single-set story.
- **Type match:** the affected gets must keep matching local types.
- **Orientation choice:** the pass may win by retargeting toward the source local or toward the destination local, depending on which side the graph proves safe.
- **Rollback safety:** a post-rewrite graph check can undo a candidate if the transformation no longer validates against the intended set relationships.
- **DWARF sensitivity:** because the pass changes local identity, it is explicitly not a debug-neutral no-op.

## Notable edge cases

- `between-unreachable` remains conservative in the reviewed lit surface.
- A candidate can look copy-like before rewrite but still fail the postGraph recheck.
- Type mismatches on influenced gets block a candidate.
- The pass only starts from copy-shaped local traffic; it is not a general answer to arbitrary local traffic.
- This pass is separate from [`../coalesce-locals/index.md`](../coalesce-locals/index.md), which handles broader slot-sharing / interference cleanup.

## Starshine status

Current Starshine has an active `src/passes/merge_locals.mbt` owner file and module-pass dispatcher arm. The pass is no longer a removed-name rejection: `src/passes/optimize.mbt` classifies `merge-locals` as a module pass, `src/passes/pass_manager.mbt` dispatches it, `src/passes/merge_locals_test.mbt` covers the public pipeline spelling plus same-typed copy retargeting and write invalidation, and `scripts/lib/pass-fuzz-compare-task.ts` exposes the direct oracle lane.

Validation evidence from the 2026-05-06 post-fuzzer-change direct revalidation:

- `moon info`, `moon fmt`, and `moon test` passed.
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass merge-locals --out-dir .tmp/pass-fuzz-merge-locals`: 6759 compared, 6759 normalized matches, 0 mismatches, 20 Binaryen command failures from the known empty-recursion-group parser/canonicalization class.

Prior artifact evidence from the 2026-05-05 landing slice also had `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --merge-locals` normalized WAT equal and canonical function compare equal; Starshine pass runtime was 475.956 ms versus Binaryen pass runtime 2062.410 ms on that artifact.

Remaining implementation debt is the broader LocalGraph-equivalent retargeting engine for control-flow-spanning copy traffic. Keep it out of public presets until that fuller rewrite is separately proven in the late local-cleanup neighborhood.

## How to validate a future port

1. Add focused tests for source-to-destination retargeting, destination-to-source retargeting, type-mismatch negatives, and rollback cases.
2. Add a conservative `between-unreachable` regression.
3. Compare `--pass merge-locals` against Binaryen for reduced WAT shapes before adding it to any preset.
4. Then run pass-targeted fuzz comparison at the repo standard scale once the implementation is stable.
5. Finally test the late local-cleanup neighborhood with `heap2local -> merge-locals -> optimize-casts -> local-subtyping -> coalesce-locals -> local-cse -> simplify-locals` as those neighbors become available locally.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md) - Source-corrected Binaryen implementation strategy.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md) - Owner-file, helper, scheduler, and official lit-test map.
- [`./local-graph-and-copy-influences.md`](./local-graph-and-copy-influences.md) - Focused guide to the graph/influence mechanics behind copy retargeting.
- [`./wat-shapes.md`](./wat-shapes.md) - Before/after shape catalog for beginners and port authors.
- [`./starshine-strategy.md`](./starshine-strategy.md) - Exact current Starshine status and future port map.
- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md) - First-slice analyzer, validation ladder, and exact local code surfaces for a future port.

## Sources

- [`../../../raw/research/0535-2026-05-06-merge-locals-direct-revalidation.md`](../../../raw/research/0535-2026-05-06-merge-locals-direct-revalidation.md)
- [`../../../raw/binaryen/2026-05-05-merge-locals-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-merge-locals-current-main-recheck.md)
- [`../../../raw/research/0485-2026-05-05-merge-locals-current-main-recheck.md`](../../../raw/research/0485-2026-05-05-merge-locals-current-main-recheck.md)
- [`../../../raw/binaryen/2026-05-04-merge-locals-current-main-recheck.md`](../../../raw/binaryen/2026-05-04-merge-locals-current-main-recheck.md)
- [`../../../raw/research/0441-2026-05-04-merge-locals-current-main-recheck.md`](../../../raw/research/0441-2026-05-04-merge-locals-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-25-merge-locals-current-main-source-correction.md`](../../../raw/binaryen/2026-04-25-merge-locals-current-main-source-correction.md)
- [`../../../raw/research/0363-2026-04-25-merge-locals-source-correction-and-test-map.md`](../../../raw/research/0363-2026-04-25-merge-locals-source-correction-and-test-map.md)
- Binaryen `version_129` source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MergeLocals.cpp>
- Binaryen current `main` source: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/MergeLocals.cpp>
- Binaryen lit test: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-locals.wast>
