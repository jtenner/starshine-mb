---
kind: entity
status: working
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0128-2026-04-20-merge-locals-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../tracker.md
  - ../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json
  - ../../../../../.artifacts/o4z-wasm-opt-debug.log
  - ../../../../../agent-todo.md
related:
  - ./binaryen-strategy.md
  - ./local-graph-and-copy-influences.md
  - ./wat-shapes.md
  - ../optimize-casts/index.md
  - ../local-subtyping/index.md
  - ../coalesce-locals/index.md
  - ../tracker.md
---

# `merge-locals`

## Role

- `merge-locals` is an upstream Binaryen higher-aggression local-cleanup pass.
- It is currently **unimplemented** in Starshine and still appears under the removed pass names in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).
- Despite the broad CLI name, Binaryen `version_129` uses it for a much narrower job: find locals that all trace back to one sufficiently simple single-set source story, then make that whole group read from one canonical slot.

## Why it matters

- The updated pass tracker listed `merge-locals` as the strongest remaining wiki-status `none` target when this thread started.
- The saved generated-artifact `-O4z` audit records it as a real skipped top-level upstream slot:
  - top-level slot `27`
- The saved Binaryen debug log shows it is bigger than a one-off top-level detail:
  - top-level slot `27` took about `0.341063` seconds
  - the full `-O4z` run executed `merge-locals` `18` total times because nested optimizing reruns reused the stronger default function pipeline
- The pass sits immediately before several already-documented neighbors whose purpose is easier to understand once `merge-locals` is clear:
  - `optimize-casts`
  - `local-subtyping`
  - `coalesce-locals`
- The local backlog does **not** yet have a dedicated `merge-locals` slice in `agent-todo.md`.
  - The current planning surface is still the older Batch 1 removed-pass note in `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`.

## Beginner summary

A safe beginner mental model is:

- if several locals are really just aliases of one simple source value,
- stop bouncing that value through all those locals,
- pick one canonical slot,
- and make the whole group read that slot instead.

That is much closer to the real pass than “merge similar locals.”

## Current durable takeaways

- `merge-locals` is **not** part of the canonical no-DWARF `-O` / `-Os` path in this repo.
- In `version_129`, `pass.cpp` only inserts it when:
  - `options.optimizeLevel >= 3`, or
  - `options.shrinkLevel >= 2`
- The pass is built around an eager `LocalGraph(false)`, not a liveness-coloring algorithm.
- The core candidate rule is tiny and strict:
  - exactly one set
  - that set has a value
  - the value is `FunctionUtils::isSimple(...)`
  - the influenced gets still trace back to that same exact set
- The pass can normalize the group in two different ways:
  - directly reuse an existing tiny source local when the set is a trivial `local.get` chain
  - or create one fresh temp local for a simple non-trivial source value
- The current implementation skips whole functions with local names instead of trying to preserve that metadata through the rewrite.
- This pass is **not** `coalesce-locals`, `local-subtyping`, or a general-purpose copy-propagation pass.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the actual Binaryen `version_129` implementation: helper dependencies, scheduler placement, candidate filtering, canonical-slot choice, and the visible rewrite contract.
- [`./local-graph-and-copy-influences.md`](./local-graph-and-copy-influences.md)
  Focused guide to the easiest part of the pass to misunderstand: how `LocalGraph` influence facts make the pass wider than a peephole but much narrower than full local-slot coloring.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly before/after shape catalog for the positive, negative, bailout, and interaction families that matter most.

## Current maintenance rule

- Treat this folder as the canonical home for future `merge-locals` research and port planning.
- Keep it explicitly marked as **unimplemented** until Starshine grows a real pass.
- Keep the strategy page and the LocalGraph/influences page in sync whenever new evidence changes the answer to either:
  - “which locals are actually eligible?”, or
  - “when does Binaryen reuse an old local versus allocate a fresh canonical temp?”

## Sources

- [`../../../raw/research/0128-2026-04-20-merge-locals-binaryen-research.md`](../../../raw/research/0128-2026-04-20-merge-locals-binaryen-research.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../tracker.md`](../tracker.md)
- [`../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json`](../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json)
- [`../../../../../.artifacts/o4z-wasm-opt-debug.log`](../../../../../.artifacts/o4z-wasm-opt-debug.log)
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MergeLocals.cpp>
- Binaryen `version_129` scheduler source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Binaryen `version_129` helper sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h>
- Binaryen `version_129` lit tests: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-locals.wast>
- Current upstream freshness checks:
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/MergeLocals.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
