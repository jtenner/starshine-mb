---
kind: entity
status: stub
last_reviewed: 2026-04-11
sources:
  - ../../../../../src/passes/heap_store_optimization.mbt
  - ../../../../../src/passes/heap_store_optimization_test.mbt
related:
  - ../../no-dwarf-default-optimize-path.md
---

# `heap-store-optimization`

- Active hot pass in the Starshine registry.
- Current summary: Fold exact struct.set writes into nearby struct.new allocations when local and effect ordering stays safe.
- This folder is the stable home for active pass docs; detailed `wat-shapes.md`, `binaryen-strategy.md`, `starshine-hot-ir-strategy.md`, and pass-specific notes are being authored.
