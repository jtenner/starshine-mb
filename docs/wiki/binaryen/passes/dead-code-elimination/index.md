---
kind: entity
status: stub
last_reviewed: 2026-04-09
sources:
  - ../../../../../src/passes/dead_code_elimination.mbt
  - ../../../../../src/passes/dead_code_elimination_test.mbt
related:
  - ../../no-dwarf-default-optimize-path.md
---

# `dead-code-elimination`

- Active hot pass in the Starshine registry.
- Current summary: prune unreachable tails, dead dropped values, and dead-result structured control in hot IR regions.
- This folder is now the stable home for future `wat-shapes.md`, `binaryen-strategy.md`, `starshine-hot-ir-strategy.md`, and pass-specific notes.
