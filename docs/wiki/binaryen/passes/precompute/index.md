---
kind: entity
status: stub
last_reviewed: 2026-04-11
sources:
  - ../../../../../src/passes/precompute.mbt
  - ../../../../../src/passes/precompute_test.mbt
related:
  - ../../no-dwarf-default-optimize-path.md
---

# `precompute`

- Active hot pass in the Starshine registry.
- Current summary: Fold exact constant integer expressions that are trap-free and stable across the top-level precompute slots.
- This folder is the stable home for active pass docs; detailed `wat-shapes.md`, `binaryen-strategy.md`, `starshine-hot-ir-strategy.md`, and pass-specific notes are being authored.
