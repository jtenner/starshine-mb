---
kind: entity
status: supported
last_reviewed: 2026-07-28
sources:
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/MergeLocals.cpp
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

Starshine implements the Binaryen v131 algorithm through a HOT path plus raw fast paths: temporary-tee instrumentation, eager CFG-backed LocalGraph influences, both retargeting orientations, exact type checks, post-graph sibling rollback, and cleanup. A linear immutable-snapshot path handles straight-line copy traffic, while a recursive regional bridge handles protected, typed-catch, catch-all, and delegate-bearing legacy `try` shapes that HOT lift does not yet admit. The pass is scheduled in O4z immediately after `heap2local`.

So the beginner mental model is **copy-shape local traffic balancing with graph-checked retargeting**, not generic local-slot coalescing and not the stale one-set/local-simple-value story.

## Why it matters

- The saved generated-artifact `-O4z` audit recorded `merge-locals` as skipped top-level slot `27`.
- Binaryen's debug log for that replay showed repeated nested `merge-locals` executions under stronger optimize/shrink settings.
- The pass sits in the same late local-cleanup neighborhood as:
  - [`../optimize-casts/index.md`](../optimize-casts/index.md)
  - [`../local-subtyping/index.md`](../local-subtyping/index.md)
  - [`../coalesce-locals/index.md`](../coalesce-locals/index.md)
- The 2026-07-28 source-family renewal checks the released v131 owner and both dedicated fixture surfaces, and replaces the stale forward-only description with the current HOT graph plus legacy-EH regional implementation.

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

Closed for the v0.1.1 Binaryen-v131 renewal. `src/passes/merge_locals.mbt` owns the HOT graph implementation, straight-line raw fast path, and recursive legacy-EH regional bridge; `src/passes/optimize.mbt` schedules `heap2local -> merge-locals -> optimize-casts`; focused tests cover both orientations, structured influence, tee candidates, rollback, unreachable control, legacy `try`, and slot order. Fifteen leaf GenValid profiles plus `merge-locals-all` cover the released source and fixture families.

Final explicit-v131 evidence:

- regular GenValid: `100000/100000` exact;
- dedicated `merge-locals-all`: `9353` exact plus `647` two-byte Starshine unread-tee wins;
- random all profiles: `9330` exact plus `625` eight-byte structured-result wins and `45` two-byte unread-tee wins;
- wasm-smith: `9955/9956` exact, one proven no-copy codec baseline, and `44` Binaryen-only parser/tool failures;
- runtime/idempotence: `1000/1000` idempotent, with all 60 exported legacy-EH cases returning equal results.

A 143,734-byte one-function copy-heavy benchmark records nine-run pass-local medians of `7.548 ms` Starshine versus `27.1409 ms` Binaryen v131: `0.278x` Binaryen time, or about `3.60x` as fast. The official full all-features fixture validates in both tools at 753 bytes Starshine versus 747 Binaryen; that six-byte fuzz-only control-rebuild shape is retained only with the measured pass-local speed win and reopens if it becomes a generated canonical size-loss family.

Full commands, cache counters, size counts, classifications, and reopening criteria are in [`fuzzing.md`](fuzzing.md) and [`starshine-port-readiness-and-validation.md`](starshine-port-readiness-and-validation.md).

## Reopening guide

Reopen for a semantic or validation failure, an uncovered v131 source family, a generated pass-owned canonical size loss without measured benefit, an unsafe cross-region legacy-EH case, or pass-local regression behind Binaryen on the copy-heavy benchmark. Downstream `coalesce-locals` suffix numbering remains separately owned by `[COALESCE-LOCALS]001`.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md) - Source-corrected Binaryen implementation strategy.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md) - Owner-file, helper, scheduler, and official lit-test map.
- [`./local-graph-and-copy-influences.md`](./local-graph-and-copy-influences.md) - Focused guide to the graph/influence mechanics behind copy retargeting.
- [`./wat-shapes.md`](./wat-shapes.md) - Before/after shape catalog for beginners and port authors.
- [`./starshine-strategy.md`](./starshine-strategy.md) - Current HOT/raw/legacy-EH implementation and residual classifications.
- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md) - Final validation matrix, official fixtures, and reopening criteria.
- [`./fuzzing.md`](./fuzzing.md) - Fifteen-leaf aggregate, exact lane counts, byte census, cache counters, runtime, and performance evidence.

## Sources

- Binaryen v131 owner: <https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/MergeLocals.cpp>; registration: <https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/pass.cpp>; fixture: <https://github.com/WebAssembly/binaryen/blob/version_131/test/lit/passes/merge-locals.wast>
- research note 0535
- research note 0485
- research note 0441
- research note 0363
- Binaryen `version_129` source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MergeLocals.cpp>
- Binaryen released-v131 source: <https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/MergeLocals.cpp>
- Binaryen lit test: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-locals.wast>
