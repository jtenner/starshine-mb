---
kind: entity
status: supported
last_reviewed: 2026-04-09
sources:
  - ../../../../../src/passes/reorder_locals.mbt
  - ../../../../../src/passes/reorder_locals_test.mbt
related:
  - ./parity.md
  - ./multivalue-call-scope.md
  - ../../no-dwarf-default-optimize-path.md
---

# `reorder-locals`

- Active module pass in the Starshine registry.
- Current summary: sort body locals by access frequency and drop unaccessed body locals.
- Current durable pages: [`./parity.md`](./parity.md) and [`./multivalue-call-scope.md`](./multivalue-call-scope.md).
- Expand this folder with dedicated strategy and shape pages as broader RL research continues.
