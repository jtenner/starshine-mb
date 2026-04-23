---
kind: entity
status: supported
last_reviewed: 2026-04-23
sources:
  - ../../../raw/binaryen/2026-04-23-merge-locals-primary-sources.md
  - ../../../raw/research/0272-2026-04-23-merge-locals-primary-sources-and-source-correction-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../tracker.md
related:
  - ./binaryen-strategy.md
  - ./local-graph-and-copy-influences.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../optimize-casts/index.md
  - ../local-subtyping/index.md
  - ../coalesce-locals/index.md
  - ../tracker.md
---

# `merge-locals`

## Role

- `merge-locals` is an upstream Binaryen higher-aggression local-cleanup pass.
- It is currently **unimplemented** in Starshine and still appears under the removed pass names in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).
- The reviewed Binaryen `version_129` contract is narrower and more specific than the name suggests: this is a **simple-set-root plus equivalent-copy merger** that collapses structurally equivalent alias locals onto one existing target local.

## Why it matters

- The saved generated-artifact `-O4z` audit still records it as a real skipped top-level upstream slot:
  - top-level slot `27`
- The saved Binaryen debug log also recorded repeated nested executions in the captured `-O4z` run, so it is not just a one-off top-level curiosity.
- The pass sits immediately before several already-documented local-cleanup neighbors whose purpose is easier to understand once `merge-locals` is taught correctly:
  - `optimize-casts`
  - `local-subtyping`
  - `coalesce-locals`
- This 2026-04-23 follow-up corrected the older dossier's main overread: the pass does **not** use the previous local-name early bailout story and does **not** normalize groups by inventing a fresh canonical temp local.

## Beginner summary

A safe beginner mental model is:

- start from a simple value-producing `local.set`
- find other locals that are only equivalent copy wrappers around that same value story
- prove, with LocalGraph plus structural dominance, that the affected gets and copy sets are safe to retarget
- pick one existing local as the winner
- rewrite the equivalent family to use that one existing local

That is much closer to the real pass than “merge locals that all have one set.”

## Current durable takeaways

- `merge-locals` is **not** part of this repo's canonical no-DWARF `-O` / `-Os` path.
- In reviewed Binaryen `version_129`, `pass.cpp` only inserts it when:
  - `options.optimizeLevel >= 3`, or
  - `options.shrinkLevel >= 2`
- The pass is rooted in simple `local.set` producers recorded by `LocalGraph` set-influence analysis.
- Safety depends on both graph facts and structural proof:
  - `LocalGraph::computeInfluences()`
  - `LocalGraph::computeSetInfluences()`
  - `LocalStructuralDominance`
  - copy-equivalence checks over wrapper locals
- The pass chooses one **existing** target local and rewrites redundant equivalent copy locals around it.
- The reviewed source reports `invalidatesDWARF() == true`; the older local-name bailout explanation was stale.
- Current Starshine has no implementation file yet; the local strategy today is explicit registry tracking plus future-port planning.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the reviewed Binaryen `version_129` implementation: scheduler placement, invalidates-DWARF contract, LocalGraph plus structural-dominance proof, target-local selection, and rewrite surface.
- [`./local-graph-and-copy-influences.md`](./local-graph-and-copy-influences.md)
  Focused guide to the easiest part of the pass to misunderstand: how set influences, copy-equivalence, and local structural dominance work together.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly before/after shape catalog for the positive, negative, bailout, and interaction families that matter most.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Exact current Starshine status and port map: removed-name registry entry, rejection surface, planning docs, and the neighboring local implementation cluster a future port would need to integrate with.

## Current maintenance rule

- Treat this folder as the canonical home for future `merge-locals` research and port planning.
- Keep it explicitly marked as **unimplemented** until Starshine grows a real pass.
- Keep the strategy page, the LocalGraph page, and the Starshine page in sync whenever new evidence changes the answer to either:
  - “what exactly counts as an equivalent merge family?”, or
  - “what existing target local can Binaryen safely choose?”

## Sources

- [`../../../raw/binaryen/2026-04-23-merge-locals-primary-sources.md`](../../../raw/binaryen/2026-04-23-merge-locals-primary-sources.md)
- [`../../../raw/research/0272-2026-04-23-merge-locals-primary-sources-and-source-correction-followup.md`](../../../raw/research/0272-2026-04-23-merge-locals-primary-sources-and-source-correction-followup.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`](../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md)
- Binaryen `version_129` release page: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
- Binaryen `version_129` source files:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MergeLocals.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/LocalStructuralDominance.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass-utils.h>
- Binaryen `version_129` lit test: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-locals.wast>
- Current upstream freshness checks:
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/MergeLocals.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
