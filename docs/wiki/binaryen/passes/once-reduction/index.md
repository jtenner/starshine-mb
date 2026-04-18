---
kind: entity
status: stub
last_reviewed: 2026-04-18
sources:
  - ../../../../../src/passes/once_reduction.mbt
  - ../../../../../src/passes/once_reduction_test.mbt
  - ../late-pipeline-dispatch.md
related:
  - ../../no-dwarf-default-optimize-path.md
  - ../late-pipeline-dispatch.md
---

# `once-reduction`

- Active module pass in the Starshine registry.
- Current summary: Reduce repeated calls to run-once functions guarded by monotonic once globals.
- Current Binaryen terminology check: the Debian `wasm-opt` manpage still lists `--once-reduction`, and this maintenance run found no official-source rename or deprecation signal.
- Use [`../late-pipeline-dispatch.md`](../late-pipeline-dispatch.md) for the current tail roster and the 2026-04-18 official-source terminology check until dedicated strategy and parity pages land.
