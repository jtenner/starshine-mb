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
  - ../../../raw/research/0104-2026-04-18-generated-o4z-optimize-instructions-slot16-func1818-parent-exit-payload-guard.md
related:
  - ../../no-dwarf-default-optimize-path.md
  - ../late-pipeline-dispatch.md
---

# `optimize-instructions`

- Active hot pass in the Starshine registry.
- Current summary: Fold safe exact-instruction peepholes such as constant eqz, shift masks, and compare-to-zero patterns.
- Current 2026-04-18 ordered generated-artifact follow-up: the saved `cmd.wasm` audit found two hard corruption slots for this pass, but only the later slot `44` replay remains open now.
- Slot `16` is retired in two HOT-lower fixes:
  - [0103](../../../raw/research/0103-2026-04-18-generated-o4z-optimize-instructions-slot16-func652-carrier-guard.md) fixed the extracted `Func 652` witness by refusing to stackify a wrapped `local.set` carrier into `block (result i32)` when child exits still targeted the parent exit label.
  - [0104](../../../raw/research/0104-2026-04-18-generated-o4z-optimize-instructions-slot16-func1818-parent-exit-payload-guard.md) fixed the remaining full-slot `Func 1818` crash by refusing to pack split parent-exit payload wrappers when nested child exits still target the wrapper label that a new typed carrier would shadow.
- The full slot-`16` replay now completes successfully and matches Binaryen's normalized WAT in the saved compare output from [0104](../../../raw/research/0104-2026-04-18-generated-o4z-optimize-instructions-slot16-func1818-parent-exit-payload-guard.md).
- Durable ordered-audit takeaway: the live `optimize-instructions` corruption family is no longer the old shared slot-16/slot-44 `Func 1818` suspicion. The remaining open `optimize-instructions` blocker is the later slot-`44` replay from [0100](../../../raw/research/0100-2026-04-18-generated-o4z-optimize-instructions-slot44-func1818-stack-underflow.md), while slot `16` is now retired as two separate HOT-lower carrier/packing bugs.
- Use [`../late-pipeline-dispatch.md`](../late-pipeline-dispatch.md) for the current tail roster until dedicated strategy and parity pages land.
