---
kind: entity
status: stub
last_reviewed: 2026-04-18
sources:
  - ../../../../../src/passes/memory_packing.mbt
  - ../../../../../src/passes/memory_packing_test.mbt
  - ../late-pipeline-dispatch.md
related:
  - ../../no-dwarf-default-optimize-path.md
  - ../late-pipeline-dispatch.md
---

# `memory-packing`

- Active module pass in the Starshine registry.
- Current summary: Split active data segments around profitable zero ranges while preserving startup memory semantics.
- Current Binaryen terminology check: the Debian `wasm-opt` manpage still lists `--memory-packing`, and this maintenance run found no official-source rename or deprecation signal.
- Use [`../late-pipeline-dispatch.md`](../late-pipeline-dispatch.md) for the current tail roster and the 2026-04-18 official-source terminology check until dedicated strategy and parity pages land.
