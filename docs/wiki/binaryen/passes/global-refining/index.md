---
kind: entity
status: stub
last_reviewed: 2026-04-18
sources:
  - ../../../../../src/passes/global_refining.mbt
  - ../../../../../src/passes/global_refining_test.mbt
  - ../late-pipeline-dispatch.md
related:
  - ../../no-dwarf-default-optimize-path.md
  - ../late-pipeline-dispatch.md
---

# `global-refining`

- Active module pass in the Starshine registry.
- Current summary: Refine private defined global reference types from their initializer and observed writes.
- Current Binaryen terminology check: the Debian `wasm-opt` manpage still lists `--global-refining`, and this maintenance run found no non-GitHub evidence of a rename or deprecation.
- Use [`../late-pipeline-dispatch.md`](../late-pipeline-dispatch.md) for the current tail roster and the 2026-04-18 non-GitHub terminology check until dedicated strategy and parity pages land.
