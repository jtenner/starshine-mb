---
kind: concept
status: supported
last_reviewed: 2026-05-13
sources:
  - ../../0064-2026-03-24-ir2-test-matrix.md
  - ../../../src/ir/test_helpers.mbt
  - ../../../src/ir/test_helpers_test.mbt
  - ../../../src/ir/cfg_test.mbt
  - ../../../src/ir/cfg_contract_test.mbt
  - ../../../src/ir/cfg_order_test.mbt
  - ../../../src/ir/dominators_test.mbt
  - ../../../src/ir/postdominators_test.mbt
  - ../../../src/ir/loop_info_test.mbt
  - ../../../src/ir/use_def_test.mbt
  - ../../../src/ir/liveness_test.mbt
  - ../../../src/ir/effects_test.mbt
  - ../../../src/ir/ssa_local_test.mbt
  - ../../../src/ir/ssa_destroy_test.mbt
  - ../../../src/ir/analysis_cache_test.mbt
  - ../../../src/passes/pass_test_helpers.mbt
  - ../../../src/passes/trace_golden_test.mbt
related:
  - ./architecture-rules.md
  - ./cfg-contract.md
  - ./local-ssa-policy.md
  - ./execution-plan.md
  - ./pass-porting-checklist.md
---

# IR2 Test Matrix

## Overview

IR2 tests are split into two layers:

1. **shared fixture/golden helpers** for cross-cutting IR2 contracts; and
2. **focused package tests** for individual overlays, mutation helpers, lowering edge cases, and pass behavior.

Use this page when deciding where a new IR2 or pass-port regression belongs. The goal is deterministic evidence for the public pipeline, not many one-off fixtures that only one pass can understand.

## Core Invariants

- Fixtures should enter through WAT or public `HotFunc` builders, then use public lift, verify, analysis, mutation, lower, and pass APIs.
- Golden output must be deterministic: block ids, traversal order, SSA value ids, local-copy insertion order, and trace tokens should not depend on map iteration or host timing.
- Analysis overlays are revision-keyed caches, not owned IR. Tests must prove both stable reuse before mutation and rebuild after mutation where cache behavior is the subject.
- Trace goldens may assert exact revision numbers only when the mutation path is deterministic and part of the contract.
- Pass tests should prefer the public pass runner unless a lower-level helper is itself the unit under test.

## Shared Fixture Helpers

### IR helpers

[`../../../src/ir/test_helpers.mbt`](../../../src/ir/test_helpers.mbt) owns the shared IR2 fixture/golden surface:

- `ir_test_build_hot_from_wat(...)` parses WAT, validates the boundary module, lifts a selected defined function, and verifies the hot body.
- `ir_test_assert_verify_and_lower(...)` verifies a possibly mutated hot body, lowers it back into the original module shell, and validates the result.
- `ir_test_dump_cfg(...)`, `ir_test_dump_dom(...)`, `ir_test_dump_liveness(...)`, and `ir_test_dump_ssa(...)` produce stable text dumps for cross-analysis goldens.

The current shared golden fixture in [`../../../src/ir/test_helpers_test.mbt`](../../../src/ir/test_helpers_test.mbt) is the local-phi `if` shape:

```wat
(module
  (func (param i32) (local i32)
    local.get 0
    if
      i32.const 7
      local.set 1
    else
      nop
    end
    local.get 1
    drop))
```

That one fixture intentionally exercises lift, CFG block formation, dominance, liveness, local SSA phi creation, local reads/writes, and deterministic node/value numbering.

### Pass helpers

[`../../../src/passes/pass_test_helpers.mbt`](../../../src/passes/pass_test_helpers.mbt) owns the shared pass fixture surface:

- `pass_test_module_from_wat(...)` parses and validates pass fixtures.
- `pass_test_lift_first_func(...)` lifts the first function and runs the pipeline verification checkpoint.
- `pass_test_run_pipeline(...)` executes requested passes through the public optimizer path.
- `pass_test_capture_trace(...)` captures trace lines from the public optimizer path.

[`../../../src/passes/trace_golden_test.mbt`](../../../src/passes/trace_golden_test.mbt) keeps the stable trace golden for a tiny `vacuum` fixture. It proves the shared trace path emits pipeline start/done, pass function selection, pass start, deterministic mutation revisions, and pass completion tokens.

## Current Coverage Matrix

| Coverage area | Primary location | Current proof |
| --- | --- | --- |
| Lift + verify | `src/ir/test_helpers.mbt`, `src/ir/test_helpers_test.mbt` | WAT fixtures validate before lift; lifted hot bodies pass core/control verification before analysis. |
| Lower + validate | `src/ir/test_helpers.mbt`, `src/ir/test_helpers_test.mbt` | Mutated hot bodies verify, lower into the original module shell, validate, and preserve important lowered shapes such as tee/compare branches without tuple debris. |
| CFG shape | `src/ir/test_helpers_test.mbt`, `src/ir/cfg_test.mbt`, `src/ir/cfg_contract_test.mbt` | Stable entry/exit/synthetic blocks, region roots, predecessors, successors, branch/return/unreachable/exceptional edges, and the policy documented in [`./cfg-contract.md`](./cfg-contract.md). |
| CFG traversal order | `src/ir/cfg_order_test.mbt` | Preorder, reverse postorder, exceptional-inclusive RPO, block-worklist seed order, and region-local block order are deterministic even for diamonds, exception edges, and unreachable tails. |
| Dominance | `src/ir/test_helpers_test.mbt`, `src/ir/dominators_test.mbt` | Stable immediate dominators, tree children, dominance frontiers, and helper behavior over reachable control shapes. |
| Post-dominance | `src/ir/postdominators_test.mbt` | Shared-exit joins, return-vs-exceptional exits, loop side-exits, frontiers, and separated ordinary/exceptional exit roots are covered. |
| Loop info | `src/ir/loop_info_test.mbt` | Natural-loop headers, bodies, latches, exits, depths, nested-loop ownership, and early exits are covered from CFG plus dominance evidence. |
| Use-def | `src/ir/use_def_test.mbt` | Child/root use sites, block-local local-def/use bitsets, unique local read/write node lists, and lightweight node-use builds are covered. |
| Liveness | `src/ir/test_helpers_test.mbt`, `src/ir/liveness_test.mbt` | Live-in/live-out sets are stable across joins and use-def inputs; exceptional-edge policy is explicit. |
| Effects | `src/ir/effects_test.mbt` | Pure arithmetic, memory, calls, throws, traps, local state, region/block aggregation, and shared-DAG cache behavior are covered. |
| Local SSA build | `src/ir/test_helpers_test.mbt`, `src/ir/ssa_local_test.mbt` | Entry definitions, phi inputs, get/use mappings, and local-set/tee definitions are deterministic and consistent with [`./local-ssa-policy.md`](./local-ssa-policy.md). |
| SSA destruction | `src/ir/ssa_destroy_test.mbt` | Phi lowering to predecessor copies, loop preheader/backedge copies, synthetic continuations, copy-cycle temps, dead-local cleanup, and Binaryen-style temp-local retention choices are covered. |
| Analysis cache | `src/ir/analysis_cache_test.mbt` | CFG/dom/effects reuse while the revision is unchanged, dependency rebuild after root mutation, and `cache_invalidate_all(...)` clearing all overlays are covered. |
| Pass execution | `src/passes/pass_test_helpers.mbt`, package pass tests | Pass fixtures run through the public optimizer path rather than pass-private harnesses unless the private helper is the unit under test. |
| Pass trace | `src/passes/pass_test_helpers.mbt`, `src/passes/trace_golden_test.mbt` | Trace capture uses the public optimizer trace callback and keeps stable pipeline/pass/function/mutation tokens. |

## Where To Put New Coverage

- **New analysis overlay or cache behavior:** add focused coverage in the owning `src/ir/*_test.mbt` file, then extend `src/ir/test_helpers.mbt` only if more than one future test needs the same deterministic dump.
- **New CFG boundary rule:** update [`./cfg-contract.md`](./cfg-contract.md), the owning CFG test, and any shared dump expectations that should change.
- **New local-SSA rule:** update [`./local-ssa-policy.md`](./local-ssa-policy.md), `src/ir/ssa_local_test.mbt` or `src/ir/ssa_destroy_test.mbt`, and shared dumps only when the cross-analysis fixture should demonstrate it.
- **New pass-port behavior:** start with a pass package test through `pass_test_run_pipeline(...)`; use lower-level IR helpers only for reduced invariants that cannot be expressed through the public pass path.
- **New trace token:** update existing trace-golden coverage or a functional pass test that already captures trace output. Do not add trace-only tests.

## Validation And Signoff

For IR2-only documentation or helper changes, run the narrow affected package tests when possible:

- `moon test src/ir`
- `moon test src/passes`

For behavior or public API changes, use the repo validation floor from [`../../README.md`](../../README.md) and [`../tooling/validation-gates.md`](../tooling/validation-gates.md): `moon info`, `moon fmt`, `bun validate readme-api-sync`, then `moon test`.

## Current Gaps And Non-Goals

- Shared dumps currently cover CFG, dominance, liveness, and local SSA. Post-dominance, loop info, use-def, effects, and cache behavior have focused tests but no shared text-dump helper yet. Add a dump helper only when multiple tests need durable cross-analysis goldens.
- The matrix is not a replacement for pass-specific semantic tests or Binaryen oracle comparison.
- The old numbered doc remains the handoff source, but this living page is the fresher navigation surface for current in-tree test locations.

## Sources

- Numbered handoff doc: [`../../0064-2026-03-24-ir2-test-matrix.md`](../../0064-2026-03-24-ir2-test-matrix.md)
- Shared IR helpers: [`../../../src/ir/test_helpers.mbt`](../../../src/ir/test_helpers.mbt), [`../../../src/ir/test_helpers_test.mbt`](../../../src/ir/test_helpers_test.mbt)
- Analysis and cache evidence: [`../../../src/ir/cfg_test.mbt`](../../../src/ir/cfg_test.mbt), [`../../../src/ir/cfg_contract_test.mbt`](../../../src/ir/cfg_contract_test.mbt), [`../../../src/ir/cfg_order_test.mbt`](../../../src/ir/cfg_order_test.mbt), [`../../../src/ir/dominators_test.mbt`](../../../src/ir/dominators_test.mbt), [`../../../src/ir/postdominators_test.mbt`](../../../src/ir/postdominators_test.mbt), [`../../../src/ir/loop_info_test.mbt`](../../../src/ir/loop_info_test.mbt), [`../../../src/ir/use_def_test.mbt`](../../../src/ir/use_def_test.mbt), [`../../../src/ir/liveness_test.mbt`](../../../src/ir/liveness_test.mbt), [`../../../src/ir/effects_test.mbt`](../../../src/ir/effects_test.mbt), [`../../../src/ir/ssa_local_test.mbt`](../../../src/ir/ssa_local_test.mbt), [`../../../src/ir/ssa_destroy_test.mbt`](../../../src/ir/ssa_destroy_test.mbt), [`../../../src/ir/analysis_cache_test.mbt`](../../../src/ir/analysis_cache_test.mbt)
- Shared pass helpers and trace golden: [`../../../src/passes/pass_test_helpers.mbt`](../../../src/passes/pass_test_helpers.mbt), [`../../../src/passes/trace_golden_test.mbt`](../../../src/passes/trace_golden_test.mbt)
