# IR2 CFG Tail-Call Current Recheck

_Status:_ immutable source bridge for [`docs/wiki/ir2/cfg-contract.md`](../../ir2/cfg-contract.md), [`docs/wiki/ir2/test-matrix.md`](../../ir2/test-matrix.md), and the archived CFG note [`docs/wiki/raw/research/0060-2026-03-24-cfg-contract-and-block-boundary-rules.md`](../research/0060-2026-03-24-cfg-contract-and-block-boundary-rules.md)
_Captured:_ 2026-06-04

## Why this refresh exists

The living CFG page already records an important local inconsistency: Starshine's concrete CFG builder and HOT flags treat `return_call`, `return_call_indirect`, and `return_call_ref` as terminating return-family operations, while the lightweight `cfg_contract.mbt` policy helpers omit those three HOT ops. This note refreshes the evidence against the current WebAssembly Core 3.0 source pages and current local `src/ir` files so the wiki can distinguish:

- official WebAssembly semantics for tail-call instructions;
- Starshine's actual graph-building behavior;
- Starshine's current helper/test gap;
- the intended test-first repair path.

## Primary and repository sources checked

### Official WebAssembly context

- WebAssembly Core 3.0 syntax instructions, captured 2026-06-04: <https://webassembly.github.io/spec/core/syntax/instructions.html>
- WebAssembly Core 3.0 validation instructions, captured 2026-06-04: <https://webassembly.github.io/spec/core/valid/instructions.html>
- WebAssembly Core 3.0 execution instructions, captured 2026-06-04: <https://webassembly.github.io/spec/core/exec/instructions.html>
- WebAssembly proposals finished-proposals table, captured 2026-06-04: <https://github.com/WebAssembly/proposals/blob/main/finished-proposals.md>

Durable implication: Core 3.0 instruction syntax includes ordinary calls, typed-function-reference `call_ref`, indirect calls, `return`, and all three tail-call forms: `return_call`, `return_call_ref`, and `return_call_indirect`. The syntax page describes the `return_call*` forms as tail-call variants that return from the current function before making the respective call and avoid resource exhaustion from unbounded active-call growth. The validation page marks all three `return_call*` forms stack-polymorphic and checks that the callee result type matches the enclosing function result type. The execution page reduces `return_call` and `return_call_indirect` through `return_call_ref`, and `return_call_ref` unwinds labels/handlers/frame state before performing the referenced call. The proposals table records Tail call and Typed Function References as finished Core 3.0 proposals.

This supports the Starshine CFG rule that `return_call*` has call-family effects/trap potential but no normal fallthrough continuation: for control-flow graph purposes it exits the current function like `return`, not like `call` / `call_ref` / `call_indirect`.

### Starshine CFG and HOT sources

- [`src/ir/hot_flags.mbt`](../../../../src/ir/hot_flags.mbt) marks `HotOp::ReturnCall`, `HotOp::ReturnCallIndirect`, and `HotOp::ReturnCallRef` with `HOT_FLAG_CALL`, `HOT_FLAG_SIDE_EFFECT`, `HOT_FLAG_MAY_TRAP`, `HOT_FLAG_HAS_EXCEPTIONAL_SUCC`, and `HOT_FLAG_TERMINATOR`.
- [`src/ir/cfg.mbt`](../../../../src/ir/cfg.mbt) maps `HotOp::Return`, `HotOp::ReturnCall`, `HotOp::ReturnCallIndirect`, and `HotOp::ReturnCallRef` to a `CfgEdgeKind::ReturnEdge` from the current block to the synthetic normal exit.
- [`src/ir/cfg_contract.mbt`](../../../../src/ir/cfg_contract.mbt) currently includes `HotOp::Return` in `cfg_op_is_terminator(...)` and `cfg_terminator_edge_kinds(...)`, but omits `ReturnCall`, `ReturnCallIndirect`, and `ReturnCallRef`.
- [`src/ir/cfg_contract_test.mbt`](../../../../src/ir/cfg_contract_test.mbt) has focused helper-policy tests for ordinary return, branch, exception, delegate, and structured-control behavior, but no focused `return_call*` helper-policy case.
- [`src/ir/cfg_test.mbt`](../../../../src/ir/cfg_test.mbt) has concrete graph tests for nested blocks, `try_table`, ordinary return, and synthetic continuations, but no focused concrete tail-call CFG test.

## Current durable policy

- `return_call`, `return_call_indirect`, and `return_call_ref` are tail-call **terminators** for CFG segmentation.
- A block ending in one of those HOT ops should have a single `ReturnEdge` to the synthetic normal exit and no `FallthroughEdge` to a later root.
- The same HOT ops are still call-family operations for effect, trap, signature, import/table/reference, and performance reasoning.
- `call`, `call_indirect`, and `call_ref` remain ordinary call-family operations that may have exceptional/trap/effect behavior but do not exit the current function by themselves.
- The current concrete builder plus HOT flags are stronger evidence for actual Starshine behavior than the lightweight policy helper omission.

## Repair path if code work follows

Use TDD and keep the helper and concrete builder aligned:

1. Add failing policy-helper tests in `src/ir/cfg_contract_test.mbt` showing each `ReturnCall*` op gets `Terminator` from `cfg_block_boundary_reasons(...)` and `[ReturnEdge]` from `cfg_terminator_edge_kinds(...)`.
2. Add or refresh a concrete CFG test in `src/ir/cfg_test.mbt` proving a tail call does not fall through to a later root.
3. Update `cfg_op_is_terminator(...)` and `cfg_terminator_edge_kinds(...)` in `src/ir/cfg_contract.mbt`.
4. Re-run `moon test src/ir`; broader pass validation is only needed if optimizer behavior changes rather than helper metadata.

## Uncertainty and non-goals

- This note did not change code. It records the current inconsistency and the source-backed intended behavior.
- The Core 3.0 execution page's `return_call_ref` rule is operational semantics, not a Starshine-specific CFG mandate. The CFG mandate comes from combining that official no-fallthrough tail-call behavior with local HOT flags and builder code.
- Exceptional/trap flags on tail calls do not mean the CFG should add a separate ordinary exceptional edge for every possible callee trap here. The current local CFG builder models `return_call*` as a return edge; changing exceptional modeling would be a separate design change and must update CFG, post-dominance, liveness/SSA exclusions, and tests together.
