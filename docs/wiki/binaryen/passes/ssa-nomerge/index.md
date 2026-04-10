---
kind: entity
status: stub
last_reviewed: 2026-04-09
sources:
  - ../../../../../src/passes/ssa_nomerge.mbt
  - ../../../../../src/passes/ssa_nomerge_test.mbt
related:
  - ../../no-dwarf-default-optimize-path.md
---

# `ssa-nomerge`

- Active hot pass in the Starshine registry.
- Current summary: untangle hot locals into semi-SSA form and lower overlay phis through predecessor copies.
- This folder is now the stable home for future `wat-shapes.md`, `binaryen-strategy.md`, `starshine-hot-ir-strategy.md`, and pass-specific notes.
