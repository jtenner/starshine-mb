---
kind: entity
status: working
last_reviewed: 2026-04-11
sources:
  - ../../../../../src/passes/ssa_nomerge.mbt
  - ../../../../../src/passes/ssa_nomerge_test.mbt
related:
  - ./parity.md
  - ../../no-dwarf-default-optimize-path.md
---

# `ssa-nomerge`

- Active hot pass in the Starshine registry.
- Current summary: untangle hot locals into semi-SSA form and lower overlay phis through predecessor copies.
- Current durable page: [`./parity.md`](./parity.md).
- The dead-param output blocker is fixed on current source and the reduced unreachable compare-carrier follow-up is now covered in-tree, but direct artifact replay still records one `Func 523` writeback-validation skip and many `suspicious-escape-carrier` raw-lowering skips; see the parity page for the current repros and signoff rule.
