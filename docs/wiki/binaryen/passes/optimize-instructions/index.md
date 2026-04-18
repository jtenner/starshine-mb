---
kind: entity
status: stub
last_reviewed: 2026-04-18
sources:
  - ../../../../../src/passes/optimize_instructions.mbt
  - ../../../../../src/passes/optimize_instructions_test.mbt
  - ../../../raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md
  - ../../../raw/research/0095-2026-04-18-generated-o4z-optimize-instructions-slot16-func652-stack-underflow.md
  - ../../../raw/research/0100-2026-04-18-generated-o4z-optimize-instructions-slot44-func1818-stack-underflow.md
related:
  - ../../no-dwarf-default-optimize-path.md
  - ../late-pipeline-dispatch.md
---

# `optimize-instructions`

- Active hot pass in the Starshine registry.
- Current summary: Fold safe exact-instruction peepholes such as constant eqz, shift masks, and compare-to-zero patterns.
- Current 2026-04-18 ordered generated-artifact follow-up: the saved `cmd.wasm` audit found two hard corruption slots for this pass, both failing in final module validation (`Func 652` at Binaryen slot `16`, `Func 1818` at slot `44`).
- Durable ordered-audit takeaway: both failures pair with neighboring `vacuum` failures on the same offending functions, so the current reduction priority is the shared ordered-prefix states around `Func 652` and `Func 1818`, not an `optimize-instructions`-only theory.
- Use [`../late-pipeline-dispatch.md`](../late-pipeline-dispatch.md) for the current tail roster until dedicated strategy and parity pages land.
