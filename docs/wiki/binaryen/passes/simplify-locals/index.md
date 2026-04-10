---
kind: entity
status: stub
last_reviewed: 2026-04-09
sources:
  - ../../../../../src/passes/simplify_locals.mbt
  - ../../../../../src/passes/simplify_locals_test.mbt
related:
  - ../../no-dwarf-default-optimize-path.md
---

# `simplify-locals`

- Active hot pass in the Starshine registry.
- Current summary: remove dead `local.set` and `local.tee` definitions through the hot SSA overlay.
- This folder is now the stable home for future `wat-shapes.md`, `binaryen-strategy.md`, `starshine-hot-ir-strategy.md`, and pass-specific notes.
