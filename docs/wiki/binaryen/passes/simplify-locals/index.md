---
kind: entity
status: working
last_reviewed: 2026-04-10
sources:
  - ../../../raw/research/0076-2026-04-01-simplify-locals-binaryen-research-plan.md
  - ../../../../../src/passes/simplify_locals.mbt
  - ../../../../../src/passes/simplify_locals_test.mbt
  - ../../../../../src/passes/pass_manager.mbt
related:
  - ./binaryen-strategy.md
  - ./starshine-hot-ir-strategy.md
  - ../../no-dwarf-default-optimize-path.md
---

# `simplify-locals`

## Role

- `simplify-locals` is an active hot pass in Starshine's Binaryen namespace.
- The pass sits on the fault line between local sink parity and structured return rewriting, so both HOT-IR strategy and raw-lane fallback behavior matter for understanding its current shape.

## Current Summary

- Binaryen treats `simplify-locals` as a staged locals optimizer with early no-structure variants and a later full structured pass.
- Starshine's in-tree work has focused first on the no-structure parity surface: dead-set cleanup, local-copy and sink rewrites, and validator-heavy raw fallback behavior for large artifact functions.
- Full structured parity remains open work; keep the pass folder focused on durable strategy, parity boundaries, and shape notes rather than one-off debugging transcripts.

## Page Map

- [`./binaryen-strategy.md`](./binaryen-strategy.md) - Upstream stage breakdown, invalidation rules, and no-DWARF pipeline placement.
- [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md) - Current HOT-IR and raw-lane port strategy for the in-tree pass.

## Current Maintenance Rule

- Treat this folder as the canonical home for future simplify-locals parity notes.
- Add dedicated parity or shape pages here as the remaining structured and exact-path gaps are reduced.
