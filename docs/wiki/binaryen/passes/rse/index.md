---
kind: entity
status: working
last_reviewed: 2026-04-22
sources:
  - ../../../raw/binaryen/2026-04-22-rse-primary-sources.md
  - ../../../raw/research/0259-2026-04-22-rse-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0114-2026-04-20-rse-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
related:
  - ./binaryen-strategy.md
  - ./cfg-and-value-tracking.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../late-pipeline-dispatch.md
  - ../../no-dwarf-default-optimize-path.md
---

# `rse`

## Role

- `rse` is Binaryen's upstream `redundant-set-elimination` pass.
- In Starshine docs it may appear as either `rse` or `redundant-set-elimination` because the saved `-O4z` audit uses the short name while the backlog also uses the longer description.
- It is currently **unimplemented** in Starshine and still appears among the removed pass names in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).
- Despite the broad name, Binaryen `version_129` uses this pass for **local** redundancy cleanup, not generic global/memory/field-store elimination.

## Why it matters

- The canonical Binaryen no-DWARF function pipeline runs `rse` very late, right before the final `vacuum`.
- The saved generated-artifact `-O4z` audit records it as a real skipped upstream slot:
  - top-level slot `46`
- The saved Binaryen debug log also shows repeated nested reruns of the same `optimize-instructions -> heap-store-optimization -> rse -> vacuum` tail cluster under later optimizing passes.
- The repo backlog already treats it as a real parity task under slice `RSE` in [`../../../../../agent-todo.md`](../../../../../agent-todo.md).
- The dossier now also has an immutable raw primary-source manifest recording that the reviewed official Binaryen `version_129` release page on 2026-04-22 showed publish date **2026-04-01**, plus a dedicated Starshine status/port-map page tying the upstream story directly to the current local registry, backlog, and scheduler surfaces.

## Beginner summary

A safe beginner mental model is:

- remember what value each local definitely holds right now
- if a new `local.set` writes the same value again, delete the write
- if a write will be overwritten before any needed read, delete the earlier write
- if a later `local.get` can use the current expression directly, replace the `local.get`
- but stop being clever when control flow gets messy, predecessor values disagree, or loop reasoning would become unsound

That is much closer to the real Binaryen pass than the name alone.

## Current durable takeaways

- Binaryen `version_129` `rse` is a **locals-only** pass:
  - it visits `LocalSet`
  - it tracks `LocalGet`
  - it relies on `LocalGraph`, liveness, and value numbering helpers
- The pass is wider than “adjacent overwrite elimination”:
  - it reasons across CFG predecessor merges
  - it tracks copied locals
  - it rewrites some `local.get`s directly
- Same-block reads do not automatically keep a set alive. If those reads can themselves be rewritten, the set may still be removed.
- The pass has a real GC/ref-type story, but it is about **refined local-value substitution**, not `struct.set` or `array.set` elimination.
- Upstream deliberately bails out on loop precision with the current implementation instead of pretending the block-input lattice is stronger than it is.
- Scheduler placement is part of the meaning: earlier cleanup passes expose redundant local traffic, and the final `vacuum` then cleans the leftovers that `rse` creates.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the actual Binaryen `version_129` implementation: local-only scope, LocalGraph/liveness/value-numbering dependencies, rewrite rules, CFG merge logic, loop bailout, GC refinement behavior, and scheduler placement.
- [`./cfg-and-value-tracking.md`](./cfg-and-value-tracking.md)
  The easiest part of the pass to misunderstand: the tiny value lattice (`Unseen` vs exact value vs merged values), copied-local inheritance, same-block read rewriting, and why loop inputs currently stay conservative.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly before/after shape catalog for the positive, negative, bailout, and pass-interaction families that matter most.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Current Starshine status and future landing-zone map: removed-name registry tracking, backlog slice `RSE`, canonical no-DWARF slot, and the neighboring local pass dossiers a future port should compose with.

## Current maintenance rule

- Treat this folder as the canonical home for future `rse` research and port planning.
- Keep it explicitly marked as **unimplemented** until Starshine grows a real pass.
- New `rse` findings should update both the strategy page and the shape catalog so the algorithm explanation and the examples stay aligned.
- If newer Binaryen versions broaden `rse` beyond locals, record that as version drift instead of silently retrofitting this `version_129` dossier.

## Sources

- [`../../../raw/binaryen/2026-04-22-rse-primary-sources.md`](../../../raw/binaryen/2026-04-22-rse-primary-sources.md)
- [`../../../raw/research/0259-2026-04-22-rse-primary-sources-and-starshine-followup.md`](../../../raw/research/0259-2026-04-22-rse-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0114-2026-04-20-rse-binaryen-research.md`](../../../raw/research/0114-2026-04-20-rse-binaryen-research.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RedundantSetElimination.cpp>
- Binaryen `version_129` scheduler source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Binaryen `version_129` nested cleanup helper: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- Binaryen `version_129` GC lit tests: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/rse-gc.wast>
- Binaryen `version_129` pass tests: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/rse_all-features.wast>
