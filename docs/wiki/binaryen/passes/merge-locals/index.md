---
kind: entity
status: supported
last_reviewed: 2026-04-25
sources:
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
  - ../optimize-casts/index.md
  - ../local-subtyping/index.md
  - ../coalesce-locals/index.md
  - ../tracker.md
supersedes:
  - ../../../raw/research/0272-2026-04-23-merge-locals-primary-sources-and-source-correction-followup.md
---

# `merge-locals`

## Role

`merge-locals` is an upstream Binaryen higher-aggression local cleanup pass.
It is currently **unimplemented** in Starshine and is still tracked as a removed pass name in [`../../../../../src/passes/optimize.mbt:144-151`](../../../../../src/passes/optimize.mbt).

The corrected 2026-04-25 source read is:

- Binaryen skips functions that have local names.
- It builds an eager `LocalGraph` and computes ordinary plus set influences.
- It scans locals with exactly one set.
- The set must have a value and that value must be simple enough to move.
- All influenced gets for the candidate local must trace back to that same set.
- Binaryen either reuses a small existing source-local chain or creates one fresh temp, then retargets gets and removes redundant sets.

So the beginner mental model is **one-set local merging with influence proof**, not generic liveness coalescing and not the stale 2026-04-23 `EquivalentCopies` / `LocalStructuralDominance` story.

## Why it matters

- The saved generated-artifact `-O4z` audit recorded `merge-locals` as skipped top-level slot `27`.
- Binaryen's debug log for that replay showed repeated nested `merge-locals` executions under stronger optimize/shrink settings.
- The pass sits in the same late local-cleanup neighborhood as:
  - [`../optimize-casts/index.md`](../optimize-casts/index.md)
  - [`../local-subtyping/index.md`](../local-subtyping/index.md)
  - [`../coalesce-locals/index.md`](../coalesce-locals/index.md)
- The 2026-04-25 source correction matters because the previous living dossier taught a non-source-backed algorithm and would have sent a future Starshine port in the wrong direction.

## Inputs and outputs

### Input surface

Inside one Binaryen function, the pass observes:

- local declarations and local names
- `local.set` nodes and their values
- `local.get` nodes influenced by each set
- control-flow enough for `LocalGraph` to know whether an influenced get traces back to one set

### Output surface

The pass can rewrite:

- `local.get` indices, retargeting them to the reused source local or to a newly allocated temp
- redundant `local.set` nodes, replacing them with `nop` / dropped structure during materialization
- local declarations, by adding a fresh temp in the nontrivial simple-value case

It does **not** rewrite function signatures, local types for refinement purposes, heap types, globals, imports, exports, or broad slot-coloring layout.

## Invariants and correctness constraints

- **Named-local bailout:** if the function has local names, Binaryen preserves that debug-facing surface by skipping the pass.
- **Single-set candidate:** the local being merged must have exactly one set in the graph.
- **Value present:** the single set must have a value; valueless or unreachable-adjacent oddities are conservative.
- **Simple-value gate:** the set value must be simple enough to move or duplicate safely under Binaryen's `FunctionUtils::isSimple(...)` predicate.
- **Influence proof:** every influenced get for the candidate local must still be traced by `LocalGraph` to that same set.
- **Small-source reuse gate:** direct source-local reuse is allowed only for a small enough `local.get` source chain.
- **Fresh-temp fallback:** otherwise the pass materializes a new local temp for the simple value and redirects the influenced gets to that temp.

## Notable edge cases

- Branching and multivalue-like arity cases can still rewrite when the single-set influence story is intact.
- DAG-like sharing and loop-backedge copy cases are source-backed lit-test families, but they are still governed by the one-set and influenced-get rules.
- Complex or effectful values stay put even if the local otherwise has one set.
- Extra sets break the candidate immediately.
- Unreachable-adjacent cases are conservative; the official test includes `between-unreachable` coverage.
- This pass is separate from [`../coalesce-locals/index.md`](../coalesce-locals/index.md), which handles broader slot-sharing / interference cleanup.

## Starshine status

Current Starshine has no `src/passes/merge_locals.mbt` owner file and no `agent-todo.md` slice for this pass.
The local status is intentionally limited to:

- removed-name tracking: [`../../../../../src/passes/optimize.mbt:144-151`](../../../../../src/passes/optimize.mbt)
- removed-pass rejection: [`../../../../../src/passes/optimize.mbt:455-473`](../../../../../src/passes/optimize.mbt)
- generic removed-name rejection test: [`../../../../../src/passes/registry_test.mbt:171-179`](../../../../../src/passes/registry_test.mbt)
- historical Batch 1 planning: [`../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md:41-42`](../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md)

## How to validate a future port

1. Add focused tests for direct source-local reuse, fresh-temp materialization, branching arity, DAG sharing, loop copies, extra-set negatives, complex-value negatives, and named-local bailout behavior.
2. Compare `--pass merge-locals` against Binaryen for reduced WAT shapes before adding it to any preset.
3. Then run pass-targeted fuzz comparison at the repo standard scale once the implementation is stable.
4. Finally test the late local-cleanup neighborhood with `heap2local -> merge-locals -> optimize-casts -> local-subtyping -> coalesce-locals -> local-cse -> simplify-locals` as those neighbors become available locally.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md) - Source-corrected Binaryen implementation strategy.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md) - Owner-file, helper, scheduler, and official lit-test map.
- [`./local-graph-and-copy-influences.md`](./local-graph-and-copy-influences.md) - Focused guide to the graph/influence mechanics without the stale structural-dominance overread.
- [`./wat-shapes.md`](./wat-shapes.md) - Before/after shape catalog for beginners and port authors.
- [`./starshine-strategy.md`](./starshine-strategy.md) - Exact current Starshine status and future port map.

## Sources

- [`../../../raw/binaryen/2026-04-25-merge-locals-current-main-source-correction.md`](../../../raw/binaryen/2026-04-25-merge-locals-current-main-source-correction.md)
- [`../../../raw/research/0363-2026-04-25-merge-locals-source-correction-and-test-map.md`](../../../raw/research/0363-2026-04-25-merge-locals-source-correction-and-test-map.md)
- Binaryen `version_129` source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MergeLocals.cpp>
- Binaryen current `main` source: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/MergeLocals.cpp>
- Binaryen lit test: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-locals.wast>
