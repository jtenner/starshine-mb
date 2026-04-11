---
kind: entity
status: stub
last_reviewed: 2026-04-11
sources:
  - ../../../../../src/passes/optimize_instructions.mbt
  - ../../../../../src/passes/optimize_instructions_test.mbt
related:
  - ../../no-dwarf-default-optimize-path.md
---

# `optimize-instructions`

- Active hot pass in the Starshine registry.
- Current summary: Fold safe exact-instruction peepholes such as constant eqz, shift masks, and compare-to-zero patterns.
- This folder is the stable home for active pass docs; detailed `wat-shapes.md`, `binaryen-strategy.md`, `starshine-hot-ir-strategy.md`, and pass-specific notes are being authored.
