---
kind: entity
status: stub
last_reviewed: 2026-04-11
sources:
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/trace_golden_test.mbt
related:
  - ../../no-dwarf-default-optimize-path.md
---

# `vacuum`

- Active hot pass in the Starshine registry.
- Current summary: Remove `nop` roots and region entries through hot IR cleanup.
- This folder is the stable home for active pass docs; detailed `wat-shapes.md`, `binaryen-strategy.md`, `starshine-hot-ir-strategy.md`, and pass-specific notes are being authored.
