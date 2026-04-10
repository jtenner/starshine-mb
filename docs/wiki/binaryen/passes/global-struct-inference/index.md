---
kind: entity
status: supported
last_reviewed: 2026-04-09
sources:
  - ../../../../../src/passes/global_struct_inference.mbt
  - ../../../../../src/passes/global_struct_inference_test.mbt
related:
  - ./parity.md
  - ../../no-dwarf-default-optimize-path.md
---

# `global-struct-inference`

- Active module pass in the Starshine registry.
- Current summary: fold immutable struct field reads from closed-world global instances when their values are globally fixed.
- Current durable page: [`./parity.md`](./parity.md).
- Expand this folder with strategy and shape pages as the broader no-DWARF pipeline research reaches GSI.
