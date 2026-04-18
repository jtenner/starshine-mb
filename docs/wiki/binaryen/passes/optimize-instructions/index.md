---
kind: entity
status: stub
last_reviewed: 2026-04-18
sources:
  - ../../../../../src/ir/hot_lower.mbt
  - ../../../../../src/ir/hot_lower_test.mbt
  - ../../../../../src/passes/optimize_instructions.mbt
  - ../../../../../src/passes/optimize_instructions_test.mbt
  - ../../../raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md
  - ../../../raw/research/0095-2026-04-18-generated-o4z-optimize-instructions-slot16-func652-stack-underflow.md
  - ../../../raw/research/0100-2026-04-18-generated-o4z-optimize-instructions-slot44-func1818-stack-underflow.md
  - ../../../raw/research/0103-2026-04-18-generated-o4z-optimize-instructions-slot16-func652-carrier-guard.md
related:
  - ../../no-dwarf-default-optimize-path.md
  - ../late-pipeline-dispatch.md
---

# `optimize-instructions`

- Active hot pass in the Starshine registry.
- Current summary: Fold safe exact-instruction peepholes such as constant eqz, shift masks, and compare-to-zero patterns.
- Current 2026-04-18 ordered generated-artifact follow-up: the saved `cmd.wasm` audit found two hard corruption slots for this pass.
- Slot `16` no longer dies on the original `Func 652` witness after [0103](../../../raw/research/0103-2026-04-18-generated-o4z-optimize-instructions-slot16-func652-carrier-guard.md): the extracted replay showed that HOT lowering was incorrectly stackifying a wrapped `local.set` carrier block into `block (result i32)` even though child branches still targeted the parent exit label.
- The full slot-`16` replay is still not green after that fix; it now advances to `Func 1818`, which aligns the remaining early `optimize-instructions` blocker with the later slot-`44` `Func 1818` family from [0100](../../../raw/research/0100-2026-04-18-generated-o4z-optimize-instructions-slot44-func1818-stack-underflow.md).
- Durable ordered-audit takeaway: `optimize-instructions` still shares the remaining live blocker family with the neighboring late-pipeline passes, but the old early `Func 652` failure is now retired as a concrete HOT-lower carrier-wrapper bug rather than left as a generic paired-state suspicion.
- Use [`../late-pipeline-dispatch.md`](../late-pipeline-dispatch.md) for the current tail roster until dedicated strategy and parity pages land.
