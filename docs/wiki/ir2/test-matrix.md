---
kind: concept
status: supported
last_reviewed: 2026-04-09
sources:
  - ../../0064-2026-03-24-ir2-test-matrix.md
related:
  - ./execution-plan.md
  - ../../../src/ir/test_helpers.mbt
  - ../../../src/passes/pass_test_helpers.mbt
  - ../../../src/ir/test_helpers_test.mbt
  - ../../../src/passes/trace_golden_test.mbt
---

# IR2 Test Matrix

## Durable Conclusions

- IR2 should use one shared fixture and golden layer for lift, analysis, lowering, and pass-trace coverage.
- The goal is deterministic evidence, not one-off module fixtures per pass.

## Shared Helpers

- [`../../../src/ir/test_helpers.mbt`](../../../src/ir/test_helpers.mbt) builds validated hot fixtures from WAT, verifies and lowers them back to modules, and dumps deterministic analysis overlays.
- [`../../../src/passes/pass_test_helpers.mbt`](../../../src/passes/pass_test_helpers.mbt) runs the public pass pipeline from WAT fixtures and captures deterministic pass traces.

## Current Golden Surface

- CFG, dominance, liveness, and SSA goldens use the local-phi `if` fixture in [`../../../src/ir/test_helpers_test.mbt`](../../../src/ir/test_helpers_test.mbt).
- Lower-and-validate mutation coverage uses the `nop` cleanup fixture in [`../../../src/ir/test_helpers_test.mbt`](../../../src/ir/test_helpers_test.mbt).
- Pass-trace goldens currently use the `vacuum` trace fixture in [`../../../src/passes/trace_golden_test.mbt`](../../../src/passes/trace_golden_test.mbt).

## Matrix

| Coverage area | Shared helper | Current fixture | Expected proof |
| --- | --- | --- | --- |
| Lift + verify | `ir_test_build_hot_from_wat(...)` | Local-phi `if` fixture | Lifted hot body verifies before analysis |
| CFG | `ir_test_dump_cfg(...)` | Local-phi `if` fixture | Stable block ids, node spans, preds, succs |
| Dominance | `ir_test_dump_dom(...)` | Local-phi `if` fixture | Stable idoms, tree children, frontiers |
| Liveness | `ir_test_dump_liveness(...)` | Local-phi `if` fixture | Stable per-block live-in/live-out bitsets |
| SSA | `ir_test_dump_ssa(...)` | Local-phi `if` fixture | Stable entry defs, phi inputs, get/set mappings |
| Lower + validate | `ir_test_assert_verify_and_lower(...)` | Mutated `nop` fixture | Mutated hot body lowers to a valid module |
| Pass execution | `pass_test_run_pipeline(...)` | `vacuum` WAT fixtures | Public pipeline stays usable from tests |
| Pass trace | `pass_test_capture_trace(...)` | `vacuum` WAT fixture | Stable trace keys and event order |

## Practical Rule

- Add new IR2 coverage by extending shared helpers or shared goldens first.
- Keep golden output deterministic.
- Use public lift, lower, analysis, and pass APIs in the helpers.
- Only assert revision numbers in trace goldens when the mutation path is deterministic.

## Sources

- Numbered research doc: [`../../0064-2026-03-24-ir2-test-matrix.md`](../../0064-2026-03-24-ir2-test-matrix.md)
- Execution-plan page: [`./execution-plan.md`](./execution-plan.md)
