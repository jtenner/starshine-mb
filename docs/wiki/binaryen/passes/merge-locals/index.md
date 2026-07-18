---
kind: entity
status: supported
last_reviewed: 2026-07-18
sources:
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/MergeLocals.cpp
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../ir2/registry-map.md
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
---

# `merge-locals`

## Role

`merge-locals` is an upstream Binaryen copy-balancing pass.
It rewrites copy-shaped local traffic (`local.set $x (local.get $y)`) by temporarily exposing a trivial `local.tee`, then retargeting influenced gets to either the source local or the destination local when the `LocalGraph` proof says the move is still single-set and type-safe.
The pass is DWARF-sensitive: the reviewed source still reports `invalidatesDWARF() == true`.

Starshine now implements the complete Binaryen v131 algorithm as a HOT pass: temporary-tee instrumentation, eager CFG-backed LocalGraph influences, both retargeting orientations, exact type checks, post-graph sibling rollback, and cleanup. A linear immutable-snapshot raw path keeps straight-line copy-heavy workloads near Binaryen speed, while structured control uses the full graph path. The pass is scheduled in O4z immediately after `heap2local`.

So the beginner mental model is **copy-shape local traffic balancing with graph-checked retargeting**, not generic local-slot coalescing and not the stale one-set/local-simple-value story.

## Why it matters

- The saved generated-artifact `-O4z` audit recorded `merge-locals` as skipped top-level slot `27`.
- Binaryen's debug log for that replay showed repeated nested `merge-locals` executions under stronger optimize/shrink settings.
- The pass sits in the same late local-cleanup neighborhood as:
  - [`../optimize-casts/index.md`](../optimize-casts/index.md)
  - [`../local-subtyping/index.md`](../local-subtyping/index.md)
  - [`../coalesce-locals/index.md`](../coalesce-locals/index.md)
- The 2026-07-11 current-main recheck keeps that upstream contract fresh and reconciles the living dossier with the landed Starshine direct pass: local status is active, but its deliberately linear forward-alias subset is not a `LocalGraph` parity claim.

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

Closed for v0.1.0 against Binaryen v131. `src/passes/merge_locals.mbt` owns the HOT graph implementation and straight-line raw fast path; `src/passes/optimize.mbt` registers the descriptor and schedules `heap2local -> merge-locals -> optimize-casts`; focused tests cover both orientations, structured influence, tee candidates, rollback, and slot order. Seven leaf GenValid profiles plus `merge-locals-all` cover the maintained family matrix.

Final evidence is `100000/100000` regular GenValid, `10000/10000` dedicated, `10000/10000` random-all-profile, and `10000/10000` exact `heap2local -> merge-locals -> optimize-casts` neighborhood normalized matches. The wasm-smith lane has one proven no-pass codec-baseline unreachable-debris difference and 44 Binaryen/tool failures; no merge-locals transform mismatch remains. Copy-heavy whole-command timing is `13.787 ms` Starshine versus `10.819 ms` Binaryen v131 (`1.27x`). Full evidence and classification are in research note `1574`.

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

- Binaryen current owner: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/MergeLocals.cpp>; registration: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>; fixture: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/merge-locals.wast>
- research note 0535
- research note 0485
- research note 0441
- research note 0363
- Binaryen `version_129` source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MergeLocals.cpp>
- Binaryen current `main` source: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/MergeLocals.cpp>
- Binaryen lit test: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-locals.wast>
