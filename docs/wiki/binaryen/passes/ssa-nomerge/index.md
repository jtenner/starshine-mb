---
kind: entity
status: working
last_reviewed: 2026-04-10
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
- The current artifact-backed blocker is a final-module validation failure on the checked-in debug CLI artifact; see the parity page for the current repro and signoff rule.
