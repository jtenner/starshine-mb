---
kind: entity
status: stub
last_reviewed: 2026-04-09
sources:
  - ../../../../../src/passes/memory_packing.mbt
  - ../../../../../src/passes/memory_packing_test.mbt
related:
  - ../../no-dwarf-default-optimize-path.md
---

# `memory-packing`

- Active module pass in the Starshine registry.
- Current summary: split active data segments around profitable zero ranges while preserving startup memory semantics.
- This folder is now the stable home for future `wat-shapes.md`, `binaryen-strategy.md`, `starshine-hot-ir-strategy.md`, and pass-specific notes.
