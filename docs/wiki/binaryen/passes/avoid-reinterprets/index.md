---
kind: entity
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-avoid-reinterprets-port-readiness-primary-sources.md
  - ../../../raw/research/0381-2026-04-26-avoid-reinterprets-port-readiness.md
  - ../../../raw/binaryen/2026-04-24-avoid-reinterprets-primary-sources.md
  - ../../../raw/research/0281-2026-04-24-avoid-reinterprets-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0172-2026-04-21-avoid-reinterprets-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../agent-todo.md
  - ../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./single-load-chains-and-bailouts.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../tracker.md
---

# `avoid-reinterprets`

## Role

- `avoid-reinterprets` is a real public Binaryen pass.
- Starshine now has an active first-slice module pass that rewrites direct full-width load-plus-reinterpret pairs; the harder indirect `reinterpret(local.get <- load)` helper-local family remains unimplemented follow-up.
- It is **not** part of the repo's current canonical no-DWARF `-O` / `-Os` optimize path.
- Its job is to replace certain `reinterpret(load(...))` or `reinterpret(local.get <- load)` shapes with extra same-address loads of the target reinterpret type.

## Why this pass matters

- The original parity queue and the first tracker-expansion wave are already dossier-covered, so this folder is an explicit source-backed expansion for a real local pass that has now moved from removed to active-partial.
- `agent-todo.md` currently has **no dedicated `avoid-reinterprets` slice**.
- The 2026-04-24 follow-up added an immutable raw primary-source manifest and a dedicated Starshine status page, so future readers no longer need to infer local status from registry snippets alone.
- The 2026-04-26 port-readiness follow-up added a focused current-main source bridge plus a first-slice / validation page, so future implementers can start from direct `reinterpret(load)` flips before designing a LocalGraph-equivalent proof.
- The pass name sounds broader than the real contract.
- A future port needs to preserve exact provenance and helper-local behavior, not just “remove reinterprets somehow.”

## Beginner summary

A good beginner mental model is:

- if Binaryen sees a full-width load
- and later sees the same bits only being reinterpreted as another full-width type
- it may duplicate the load in the other type instead of keeping the reinterpret

So this pass is best taught as:

- **full-width load-plus-reinterpret rewriting**
- not generic type canonicalization
- not generic local propagation
- and not generic load CSE

## Most important durable takeaways

- The reviewed implementation is a small function-parallel AST pass.
- It only looks at the four scalar reinterpret unary ops.
- It only duplicates **full-width, reachable** loads.
- It follows only **single-set** local chains back to one source load.
- It uses `Properties::getFallthrough(...)`, so some wrappers are transparent and others are not.
- Direct `reinterpret(load(...))` can be flipped immediately with no helper locals.
- `reinterpret(local.get ...)` uses fresh helper locals and duplicates the load at the source site.
- The pointer helper local uses the memory's `addressType`, so memory64 needs `i64` pointer temps.
- The reviewed `version_129` and current `main` implementation file still showed no teaching-relevant drift in the 2026-04-24 source recheck.
- The 2026-04-26 current-main / port-readiness recheck again found no teaching-relevant drift and narrowed the recommended first Starshine slice to direct full-width `reinterpret(load)` rewrites before indirect local-chain helper-local work.
- Current Starshine accepts the pass as an active module pass for direct full-width load flips, with no preset scheduling yet.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the actual Binaryen implementation, algorithmic phases, helper dependencies, and pass interactions.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  File-by-file and test-by-test map of the upstream sources that define the pass contract.
- [`./single-load-chains-and-bailouts.md`](./single-load-chains-and-bailouts.md)
  Focused guide to the real proof obligation: single reaching-set load chains, fallthrough wrappers, pointer-temp typing, and the main bailout shapes.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly shape catalog showing the main positive, mixed-use, and bailout WAT families.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Current Starshine status-and-port-planning page mapping the active direct-load implementation, remaining indirect provenance proof, missing backlog slice, and likely HOT-IR building blocks.
- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md)
  First-slice and validation guide for a future port: direct full-width load flips first, indirect helper-local rewrites only after a documented single-load provenance proof, and a reduced-test-to-Binaryen-oracle ladder.

## Current maintenance rule

- Treat this folder as the canonical home for future `avoid-reinterprets` research and port planning.
- Keep it explicitly marked as **partial** until Starshine grows the indirect single-load-provenance helper-local family.
- Cite the raw primary-source manifest when restating original Binaryen source provenance: [`../../../raw/binaryen/2026-04-24-avoid-reinterprets-primary-sources.md`](../../../raw/binaryen/2026-04-24-avoid-reinterprets-primary-sources.md); cite the 2026-04-26 bridge when discussing port readiness or current local line anchors: [`../../../raw/binaryen/2026-04-26-avoid-reinterprets-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-26-avoid-reinterprets-port-readiness-primary-sources.md).
- Keep the scheduler fact explicit too: this is a real public Binaryen pass, but it is outside the current no-DWARF default optimize path.
- Keep the scope fact explicit: reviewed Binaryen duplicates eligible loads to serve reinterpret users; it does not retarget whole local webs or eliminate every reinterpret in sight.
- Keep the implementation split explicit: direct `reinterpret(load)` flips are implemented in [`../../../../../src/passes/avoid_reinterprets.mbt`](../../../../../src/passes/avoid_reinterprets.mbt); indirect `reinterpret(local.get)` rewrites still require an explicit LocalGraph-equivalent proof decision first.

## Sources

- [`../../../raw/binaryen/2026-04-26-avoid-reinterprets-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-26-avoid-reinterprets-port-readiness-primary-sources.md)
- [`../../../raw/research/0381-2026-04-26-avoid-reinterprets-port-readiness.md`](../../../raw/research/0381-2026-04-26-avoid-reinterprets-port-readiness.md)
- [`../../../raw/binaryen/2026-04-24-avoid-reinterprets-primary-sources.md`](../../../raw/binaryen/2026-04-24-avoid-reinterprets-primary-sources.md)
- [`../../../raw/research/0281-2026-04-24-avoid-reinterprets-primary-sources-and-starshine-followup.md`](../../../raw/research/0281-2026-04-24-avoid-reinterprets-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0172-2026-04-21-avoid-reinterprets-binaryen-research.md`](../../../raw/research/0172-2026-04-21-avoid-reinterprets-binaryen-research.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`](../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../tracker.md`](../tracker.md)
- Binaryen `version_129` and current-main sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/AvoidReinterprets.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/avoid-reinterprets.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/avoid-reinterprets64.wast>
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/AvoidReinterprets.cpp>
