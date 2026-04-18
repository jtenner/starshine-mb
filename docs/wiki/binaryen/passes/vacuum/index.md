---
kind: entity
status: stub
last_reviewed: 2026-04-18
sources:
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/trace_golden_test.mbt
  - ../../../raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md
  - ../../../raw/research/0097-2026-04-18-generated-o4z-vacuum-slot23-func652-stack-underflow.md
  - ../../../raw/research/0098-2026-04-18-generated-o4z-vacuum-slot33-func1818-stack-underflow.md
related:
  - ../../no-dwarf-default-optimize-path.md
  - ../late-pipeline-dispatch.md
---

# `vacuum`

- Active hot pass in the Starshine registry.
- Current summary: Remove `nop` roots and region entries through hot IR cleanup.
- Current 2026-04-18 ordered generated-artifact follow-up: the saved `cmd.wasm` audit found two hard corruption slots for this pass, both failing in final module validation (`Func 652` at Binaryen slot `23`, `Func 1818` at slot `33`).
- Use [`../late-pipeline-dispatch.md`](../late-pipeline-dispatch.md) for the current tail roster until dedicated strategy and parity pages land.
