---
kind: entity
status: stub
last_reviewed: 2026-04-11
sources:
  - ../../../../../src/passes/simplify_locals.mbt
  - ../../../../../src/passes/simplify_locals_test.mbt
related:
  - ../../no-dwarf-default-optimize-path.md
---

# `simplify-locals`

- Active hot pass in the Starshine registry.
- Current summary: Remove dead local.set/local.tee defs through the hot SSA overlay.
- This folder is the stable home for active pass docs; detailed `wat-shapes.md`, `binaryen-strategy.md`, `starshine-hot-ir-strategy.md`, and pass-specific notes are being authored.
