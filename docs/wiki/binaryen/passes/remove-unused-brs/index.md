---
kind: entity
status: supported
last_reviewed: 2026-04-09
sources:
  - ../../../../../src/passes/remove_unused_brs.mbt
  - ../../../../../src/passes/remove_unused_brs_test.mbt
related:
  - ./parity.md
  - ./returned-ladder-hot-shapes.md
  - ../../no-dwarf-default-optimize-path.md
---

# `remove-unused-brs`

- Active hot pass in the Starshine registry.
- Current summary: remove tail branches and returns that already flow to the surrounding continuation.
- Current durable pages: [`./parity.md`](./parity.md) and [`./returned-ladder-hot-shapes.md`](./returned-ladder-hot-shapes.md).
- Expand this folder with more explicit strategy notes as remaining late-phase RUB parity work lands.
