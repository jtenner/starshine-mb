---
kind: entity
status: supported
last_reviewed: 2026-04-09
sources:
  - ../../../../../src/passes/heap2local.mbt
  - ../../../../../src/passes/heap2local_test.mbt
related:
  - ./parity.md
  - ../../no-dwarf-default-optimize-path.md
---

# `heap2local`

- Active hot pass in the Starshine registry.
- Current summary: replace non-escaping struct locals with scalar field locals and fold direct fresh-struct null comparisons.
- Current durable page: [`./parity.md`](./parity.md).
- Expand this folder with dedicated strategy and shape pages as broader H2L research continues.
