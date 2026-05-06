---
kind: entity
status: supported
last_reviewed: 2026-05-06
sources:
  - ../../../raw/binaryen/2026-05-06-alignment-lowering-current-main-recheck.md
  - ../../../raw/research/0496-2026-05-06-alignment-lowering-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-26-alignment-lowering-current-main-port-readiness.md
  - ../../../raw/research/0379-2026-04-26-alignment-lowering-port-readiness.md
  - ../../../raw/binaryen/2026-04-23-alignment-lowering-primary-sources.md
  - ../../../raw/research/0171-2026-04-21-alignment-lowering-binaryen-research.md
  - ../../../raw/research/0200-2026-04-21-alignment-lowering-chunk-matrix-followup.md
  - ../../../raw/research/0273-2026-04-23-alignment-lowering-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../tracker.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./chunk-selection-and-unreachable-semantics.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../tracker.md
---

# `alignment-lowering`

## Role

- `alignment-lowering` is a real public Binaryen pass.
- It is currently **unimplemented** in Starshine's active optimizer and still lives in the local boundary-only registry in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).
- It is **not** part of the repo's current canonical no-DWARF `-O` / `-Os` default optimize path.
- Its job is to replace unaligned ordinary scalar loads and stores with smaller naturally aligned accesses that reconstruct or split the same value.

## Why this pass matters

- The main parity queue and first tracker-expansion wave are already dossier-covered, so this folder is an explicit source-backed tracker expansion for another real local registry entry.
- `agent-todo.md` currently has **no dedicated `alignment-lowering` slice**.
- The pass is shape-driven, narrow, and easy to misread from the name alone.
- A future port needs to preserve exact evaluation order and signedness behavior, not just “some equivalent smaller loads/stores.”

## Beginner summary

A good beginner mental model is:

- if a load or store promises too little alignment
- Binaryen keeps the address and value evaluation single-shot using fresh locals
- then it performs several smaller aligned memory operations instead
- and finally rebuilds or splits the scalar bits with shifts, ors, wraps, extends, and reinterprets

So this pass is best taught as:

- **scalar misalignment legalization for ordinary loads and stores**
- not as a generic memory optimizer

## Most important durable takeaways

- The real upstream public pass name is just `alignment-lowering`.
- On 2026-04-23 the reviewed official Binaryen `version_129` release page showed publish date **2026-04-01**.
- It is a small AST walker, not a CFG/dataflow optimization pass.
- Reviewed Binaryen `version_129` rewrites only ordinary `Load` and `Store` nodes.
- Already-natural alignment stays untouched.
- `i32` chunk logic is the core engine; `f32`, `i64`, and `f64` reuse it.
- The exact helper matrix is small and source-confirmed: the interesting integer helper cases are misaligned `2`-byte and `4`-byte families, not an open-ended generic chunker.
- The pass introduces fresh locals to preserve single evaluation of pointer and value expressions.
- Unreachable loads and stores have special operand-preserving rewrites.
- The reviewed `version_129` and current upstream `main` implementation file are still aligned; the 2026-05-06 current-main recheck found no teaching-relevant drift from that contract.
- Starshine still has no implementation or dedicated backlog slice for this pass, but the dossier now has a dedicated local status/port-planning page and a first-slice validation bridge instead of leaving that story scattered across registry docs.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the actual Binaryen implementation, algorithmic phases, helper dependencies, and the exact positive/bailout rewrite families.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  File-by-file and test-by-test map of the upstream sources that define the pass contract.
- [`./chunk-selection-and-unreachable-semantics.md`](./chunk-selection-and-unreachable-semantics.md)
  Dedicated follow-up page for the exact byte-width/alignment helper matrix, the largest-legal-chunk selection rule, and the operand-preserving unreachable fast paths a future port must match literally.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly shape catalog showing the main aligned-chunk rewrite families, negative shapes, bailout shapes, and easy-to-miss corner cases.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Exact current Starshine status and port-planning bridge, including the boundary-only registry entry, the active request guard, the missing dedicated backlog slice, and the still-open landing-zone question.
- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md)
  Implementation-readiness bridge for future Starshine work: local memory-op code map, narrow first-slice scope, red-test order, direct Binaryen oracle comparison plan, and the unresolved HOT-vs-lib landing-zone decision.

## Current maintenance rule

- Treat this folder as the canonical home for future `alignment-lowering` research and port planning.
- Keep it explicitly marked as **unimplemented** until Starshine grows a real active pass for it.
- Keep the scheduler fact explicit too: this is a real public Binaryen pass, but it is not in the current no-DWARF default optimize path.
- Keep the local-status fact explicit too: Starshine still tracks the name boundary-only, rejects explicit requests honestly, and still has no dedicated backlog slice or chosen landing zone.
- Keep the port-readiness page current whenever future code changes the local load/store/HOT landing-zone answer.
- Keep the scope fact explicit: reviewed Binaryen handles ordinary scalar loads/stores here, not every memory instruction family.
- Keep the helper-matrix fact explicit too: the future-port contract is not just “split to smaller loads/stores somehow,” but the exact source-backed chunk-selection and unreachable-operand rules documented in the mechanics page.

## Sources

- [`../../../raw/binaryen/2026-05-06-alignment-lowering-current-main-recheck.md`](../../../raw/binaryen/2026-05-06-alignment-lowering-current-main-recheck.md)
- [`../../../raw/research/0496-2026-05-06-alignment-lowering-current-main-recheck.md`](../../../raw/research/0496-2026-05-06-alignment-lowering-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-26-alignment-lowering-current-main-port-readiness.md`](../../../raw/binaryen/2026-04-26-alignment-lowering-current-main-port-readiness.md)
- [`../../../raw/research/0379-2026-04-26-alignment-lowering-port-readiness.md`](../../../raw/research/0379-2026-04-26-alignment-lowering-port-readiness.md)
- [`../../../raw/binaryen/2026-04-23-alignment-lowering-primary-sources.md`](../../../raw/binaryen/2026-04-23-alignment-lowering-primary-sources.md)
- [`../../../raw/research/0171-2026-04-21-alignment-lowering-binaryen-research.md`](../../../raw/research/0171-2026-04-21-alignment-lowering-binaryen-research.md)
- [`../../../raw/research/0200-2026-04-21-alignment-lowering-chunk-matrix-followup.md`](../../../raw/research/0200-2026-04-21-alignment-lowering-chunk-matrix-followup.md)
- [`../../../raw/research/0273-2026-04-23-alignment-lowering-primary-sources-and-starshine-followup.md`](../../../raw/research/0273-2026-04-23-alignment-lowering-primary-sources-and-starshine-followup.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`](../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md)
- [`../tracker.md`](../tracker.md)
