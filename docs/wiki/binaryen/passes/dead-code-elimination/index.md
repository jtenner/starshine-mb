---
kind: entity
status: stub
last_reviewed: 2026-04-11
sources:
  - ../../../../../src/passes/dead_code_elimination.mbt
  - ../../../../../src/passes/dead_code_elimination_test.mbt
related:
  - ../../no-dwarf-default-optimize-path.md
---

# `dead-code-elimination`

- Active hot pass in the Starshine registry.
- Current summary: Prune unreachable tails, dead dropped values, and dead-result structured control in hot IR regions.
- This folder is the stable home for active pass docs; detailed `wat-shapes.md`, `binaryen-strategy.md`, `starshine-hot-ir-strategy.md`, and pass-specific notes are being authored.
