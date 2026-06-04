---
kind: decision
status: supported
last_reviewed: 2026-06-04
sources:
  - ../raw/ir2/2026-06-04-cfg-tail-call-current-recheck.md
  - ../raw/research/0060-2026-03-24-cfg-contract-and-block-boundary-rules.md
  - ../raw/wasm/2026-05-19-tail-call-control-flow-sources.md
  - ../raw/wasm/2026-05-19-wast-control-flow-sources.md
  - ../wast/control-flow-authoring.md
  - ../wast/exception-tag-authoring.md
  - ../wast/tail-call-authoring.md
  - ../../../src/ir/cfg_contract.mbt
  - ../../../src/ir/cfg.mbt
  - ../../../src/ir/hot_flags.mbt
  - ../../../src/ir/cfg_contract_test.mbt
  - ../../../src/ir/cfg_test.mbt
  - ../../../src/ir/cfg_order_test.mbt
  - ../../../src/validate/typecheck.mbt
related:
  - ./local-ssa-policy.md
  - ./test-matrix.md
  - ./pass-porting-checklist.md
  - ../wast/control-flow-authoring.md
  - ../wast/exception-tag-authoring.md
  - ../wast/tail-call-authoring.md
  - ../../../src/ir/cfg_contract.mbt
  - ../../../src/ir/cfg_contract_test.mbt
  - ../../../src/ir/cfg.mbt
  - ../../../src/ir/cfg_test.mbt
  - ../../../src/ir/hot_flags.mbt
---

# IR2 CFG Contract

## Overview

IR2 builds control-flow graphs as **derived overlays** over one owned optimizer body, [`HotFunc`](../../../src/ir/hot_core.mbt). The CFG does not own or rewrite instructions. It gives later analyses a stable block graph with explicit normal exits, branch exits, exceptional exits, unreachable exits, region-entry blocks, and synthetic entry/exit nodes.

The beginner mental model is:

```text
HotFunc roots/regions/nodes
  -> block segmentation at roots, structured controls, and terminators
  -> synthetic entry/exit blocks
  -> explicit edge kinds for fallthrough, branch, return, exception, and unreachable
  -> downstream dominance, post-dominance, liveness, loop, use-def, effects, and SSA overlays
```

The advanced invariant is that every analysis must treat `BlockId` as an id inside one CFG overlay build. A `BlockId` is not a persistent `HotFunc` body id and must not survive mutation across `HotFunc.revision` changes.

## Boundary Policy

[`cfg_block_boundary_reasons(...)`](../../../src/ir/cfg_contract.mbt) is the current policy helper for explaining why a node starts or terminates a block segment.

| Boundary reason | Meaning | Typical source |
| --- | --- | --- |
| `RootEntry` | The node is a top-level root in the function body. | First root or any later root after a terminating previous root. |
| `ControlHeader` | Structured control is a block header and terminates the incoming block. | `block`, `loop`, `if`, `try`, `try_table`. |
| `LoopHeader` | A `loop` header is also its own explicit loop-target boundary. | `loop`. |
| `BodyRegionEntry` / `ThenRegionEntry` / `ElseRegionEntry` / `CatchRegionEntry` / `CatchListRegionEntry` | Structured-control child regions have explicit entry boundaries. | Control-region slot metadata from hot labels/regions. |
| `Terminator` | The node has no ordinary value-only continuation inside the same block segment. | Branches, returns, throws/delegates, `unreachable`, and structured-control headers. |

The segmentation implementation in [`cfg_builder_region_segments(...)`](../../../src/ir/cfg.mbt) follows the same broad rule: it starts a new segment after a terminator and before a structured-control node. That makes region-local block order deterministic and gives later passes stable predecessors/successors instead of making them infer control slots from child arrays.

## Successor And Edge-Kind Policy

[`CfgEdgeKind`](../../../src/ir/cfg_contract.mbt) has five explicit kinds:

| Edge kind | Meaning |
| --- | --- |
| `FallthroughEdge` | Ordinary control continuation or structured-control entry/exit flow. |
| `BranchEdge` | Explicit Wasm branch to a label target. |
| `ReturnEdge` | Function return to the synthetic normal exit. |
| `ExceptionalEdge` | Exception transfer to a catch/catch-list/delegate target or the caller-visible exceptional exit. |
| `UnreachableExitEdge` | Trap/unreachable transfer to the synthetic normal exit as an explicit nonfallthrough edge. |

The WAST fixture-facing label, branch-payload, and `br_table` default-target rules live in [`../wast/control-flow-authoring.md`](../wast/control-flow-authoring.md). Structured-control successor policy is intentionally small and named:

- `block` and `loop` use `InlineBodyRegion`.
- `if` uses `SplitThenElse` and creates an explicit fallthrough continuation when needed.
- `try` uses `SplitBodyCatch`.
- `try_table` uses `SplitBodyCatchList`.

Terminator edge policy in the concrete builder is:

- `br` and `br_table` produce `BranchEdge` targets only.
- `br_if`, `br_on_null`, `br_on_non_null`, `br_on_cast`, and `br_on_cast_fail` produce `BranchEdge` targets plus a `FallthroughEdge` when a next block exists.
- `return`, `return_call`, `return_call_indirect`, and `return_call_ref` produce a `ReturnEdge` to the synthetic normal exit.
- `throw`, `throw_ref`, and `rethrow` produce an `ExceptionalEdge` to the nearest handler target or the synthetic exceptional exit.
- `delegate` produces an `ExceptionalEdge` to the delegated label target.
- `unreachable` produces an `UnreachableExitEdge` to the synthetic normal exit.

The 2026-06-04 recheck in [`../raw/ir2/2026-06-04-cfg-tail-call-current-recheck.md`](../raw/ir2/2026-06-04-cfg-tail-call-current-recheck.md) is the current source bridge for this rule. WebAssembly Core 3.0 syntax includes `return_call`, `return_call_indirect`, and `return_call_ref`; validation treats them as stack-polymorphic tail-call forms whose callee result must match the enclosing function result; execution routes them through a tail-call path that unwinds the current function's frame/labels/handlers before entering the callee. Starshine's HOT flags agree with the no-fallthrough semantic model: [`hot_default_flags_for_op(...)`](../../../src/ir/hot_flags.mbt) marks all three tail-call HOT ops as both calls and terminators. WAST authoring details live in [`../wast/tail-call-authoring.md`](../wast/tail-call-authoring.md), and the older tail-call source manifest remains provenance at [`../raw/wasm/2026-05-19-tail-call-control-flow-sources.md`](../raw/wasm/2026-05-19-tail-call-control-flow-sources.md).

## Exceptional-Flow Policy

[`cfg_exception_target_policy(...)`](../../../src/ir/cfg_contract.mbt) records the high-level policy:

- Ordinary nodes use `NoExceptionEdge`.
- `try` routes exceptional flow to its catch region.
- `try_table` routes exceptional flow to its catch-list region; the WAST lowering and validation rules for catch labels and payloads live in [`../wast/exception-tag-authoring.md`](../wast/exception-tag-authoring.md).
- `throw`, `throw_ref`, and `rethrow` propagate to the nearest handler or caller-visible exceptional exit.
- `delegate` transfers exceptionally to its delegated target.

The concrete builder materializes the exceptional exit lazily: [`cfg_builder_exceptional_exit_block(...)`](../../../src/ir/cfg.mbt) creates the synthetic exceptional exit only when a function actually needs one.

## Tail Calls: Return Edge Plus Call Effects

Tail calls are easy to misread because they combine two families of facts:

| HOT op | Effect/signature family | CFG continuation family | Practical consequence |
| --- | --- | --- | --- |
| `ReturnCall` | Direct call: callee signature, import/export, side effect, trap, and performance reasoning. | `ReturnEdge` to the synthetic normal exit. | No ordinary successor after the node; later roots are unreachable from this block. |
| `ReturnCallIndirect` | Indirect call: table/reference/signature checks plus ordinary call effects. | `ReturnEdge` to the synthetic normal exit. | Treat it as a call for validation/effects, but as a return for CFG shape. |
| `ReturnCallRef` | Typed-function-reference call: reference nullability/type checks plus ordinary call effects. | `ReturnEdge` to the synthetic normal exit. | It is not the same as `call_ref`; it tail-exits the current function. |

A concrete CFG tail-call test should therefore assert that the ending block has a single `ReturnEdge` and that a following root has no predecessor from the tail-call block. An effects or pass-safety test may still need to assert the call/trap side of the same op.

## Current Local Gap: Tail-Call Helper Coverage

There is one important 2026-06-04 consistency gap to keep visible:

- [`src/ir/hot_flags.mbt`](../../../src/ir/hot_flags.mbt) correctly marks `ReturnCall`, `ReturnCallIndirect`, and `ReturnCallRef` as terminators.
- [`src/ir/cfg.mbt`](../../../src/ir/cfg.mbt) correctly maps all three tail-call forms to `ReturnEdge` when they are the last node in a block segment.
- [`src/ir/cfg_contract.mbt`](../../../src/ir/cfg_contract.mbt), however, currently omits the tail-call forms from `cfg_op_is_terminator(...)` and `cfg_terminator_edge_kinds(...)`.
- [`src/ir/cfg_contract_test.mbt`](../../../src/ir/cfg_contract_test.mbt) has focused policy-helper tests for ordinary `Return`, `ThrowRef`, `Delegate`, and structured control, but no focused tail-call case yet.
- [`src/ir/cfg_test.mbt`](../../../src/ir/cfg_test.mbt) has concrete graph tests for nested blocks, `try_table`, ordinary return, and synthetic continuations, but no focused concrete tail-call graph test yet.

Until the helper and tests are fixed, treat the concrete builder plus HOT flags as the stronger evidence for actual CFG behavior, and treat the policy helper omission as a testable follow-up rather than as a deliberate semantic distinction. A code fix should add failing `return_call*` CFG-contract tests first, add or refresh a concrete no-fallthrough CFG test, then update both helper functions and any affected order/CFG expectations.

## Concrete Flow Examples

### Straight-line roots with an ordinary branch

```wat
(block $exit
  local.get 0
  br_if $exit
  i32.const 1
  drop)
```

`br_if` belongs at a block tail. The CFG should have one `BranchEdge` to the `$exit` continuation and one `FallthroughEdge` to the block containing `i32.const; drop`.

### Tail call is a return edge, not a fallthrough call

```wat
(func $caller (result i32)
  return_call $callee)
```

The tail call is still a call for side-effect, trap, and signature purposes, but the CFG control edge is a `ReturnEdge` to the synthetic normal exit. There is no ordinary fallthrough successor after the tail call. WAST fixture authors should also keep the current function return-type constraint visible; see [`../wast/tail-call-authoring.md`](../wast/tail-call-authoring.md).

### Try/catch materializes exceptional flow

```wat
(try
  (do
    call $may_throw)
  (catch $tag
    i32.const 0
    drop))
```

The `try` header has ordinary fallthrough into the body region and an exceptional edge to the catch region. Calls are represented as call/effect nodes; thrown exceptional control reaches the handler target through the handler policy rather than by child-slot guessing.

## Analysis Consumers And Validation Guidance

- Dominance and loop analyses should use normal `FallthroughEdge`, `BranchEdge`, and `ReturnEdge` policy rather than silently traversing exceptional exits.
- Post-dominance has separate normal and exceptional exit roots; keep that split visible when changing exception policy.
- Liveness and local SSA v1 intentionally follow the current non-exceptional policy, as documented in [`local-ssa-policy.md`](local-ssa-policy.md).
- New CFG semantics should update [`cfg_contract.mbt`](../../../src/ir/cfg_contract.mbt), focused tests in [`cfg_contract_test.mbt`](../../../src/ir/cfg_contract_test.mbt), concrete CFG builder coverage in [`cfg_test.mbt`](../../../src/ir/cfg_test.mbt), and deterministic order expectations in [`cfg_order_test.mbt`](../../../src/ir/cfg_order_test.mbt) when traversal order changes.
- Use the placement guidance in [`test-matrix.md`](test-matrix.md): helper-policy tests belong in `cfg_contract_test.mbt`; built graph shape belongs in `cfg_test.mbt`; traversal determinism belongs in `cfg_order_test.mbt`.

## Practical Rules

- Derive successor structure from control-slot metadata, not from child-slot guessing.
- Materialize exceptional flow as real CFG edges.
- Keep synthetic entry, normal exit, and exceptional exit policy separate from owned body nodes.
- Do not carry `BlockId` across `HotFunc.revision` changes.
- Treat tail calls as call-family operations for effect/signature analysis and as return-family operations for CFG continuation.

## Sources

- Archived original CFG contract note: [`../raw/research/0060-2026-03-24-cfg-contract-and-block-boundary-rules.md`](../raw/research/0060-2026-03-24-cfg-contract-and-block-boundary-rules.md)
- Current CFG tail-call recheck: [`../raw/ir2/2026-06-04-cfg-tail-call-current-recheck.md`](../raw/ir2/2026-06-04-cfg-tail-call-current-recheck.md)
- Tail-call source manifest: [`../raw/wasm/2026-05-19-tail-call-control-flow-sources.md`](../raw/wasm/2026-05-19-tail-call-control-flow-sources.md)
- Policy layer: [`../../../src/ir/cfg_contract.mbt`](../../../src/ir/cfg_contract.mbt)
- Concrete builder: [`../../../src/ir/cfg.mbt`](../../../src/ir/cfg.mbt)
- HOT flags and query helpers: [`../../../src/ir/hot_flags.mbt`](../../../src/ir/hot_flags.mbt), [`../../../src/ir/hot_query.mbt`](../../../src/ir/hot_query.mbt)
- CFG tests: [`../../../src/ir/cfg_contract_test.mbt`](../../../src/ir/cfg_contract_test.mbt), [`../../../src/ir/cfg_test.mbt`](../../../src/ir/cfg_test.mbt), [`../../../src/ir/cfg_order_test.mbt`](../../../src/ir/cfg_order_test.mbt)
- Tail-call validation: [`../../../src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt)
- Ordinary WAST control-flow guide: [`../wast/control-flow-authoring.md`](../wast/control-flow-authoring.md)
- Exception/tag catch payload guide: [`../wast/exception-tag-authoring.md`](../wast/exception-tag-authoring.md)
- Tail-call WAST authoring guide: [`../wast/tail-call-authoring.md`](../wast/tail-call-authoring.md)
