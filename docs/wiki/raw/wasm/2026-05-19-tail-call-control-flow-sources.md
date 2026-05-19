# WebAssembly Tail-Call Control-Flow Sources (2026-05-19)

## Scope

Primary-source manifest for the IR2 CFG contract refresh in [`../../ir2/cfg-contract.md`](../../ir2/cfg-contract.md). The durable question is how `return_call`, `return_call_indirect`, and `return_call_ref` should be treated by Starshine's control-flow graph: ordinary calls may fall through if they return normally, while tail-call forms transfer control to the callee and then to the current caller's continuation.

## Sources Checked

1. WebAssembly Core Specification draft, instructions syntax: <https://webassembly.github.io/spec/core/syntax/instructions.html> (opened 2026-05-19). The current page includes the call-instruction family and, in the opened view, lists `return_call`, `return_call_indirect`, and `return_call_ref` alongside the ordinary direct, indirect, and reference call forms.
2. WebAssembly tail-call proposal repository: <https://github.com/WebAssembly/tail-call> (searched/opened 2026-05-19). The proposal is archived, and the repository summary describes the feature as calling functions in tail position without growing the stack. Treat it as historical rationale now that the core draft includes the instruction names.
3. WebAssembly tail-call proposal bikeshed source, validation/execution rules: <https://github.com/WebAssembly/tail-call/blob/main/proposals/tail-call/Overview.md> and proposal spec sources reachable from that repository (searched 2026-05-19). The useful stable takeaway is semantic rather than opcode-detail: tail calls are return-position transfers, not ordinary calls with a fallthrough continuation.

## Durable Takeaways

- The official current core instruction list includes tail-call forms in the call family.
- Tail-call forms are call instructions, but their control-flow effect is closer to `return` than to ordinary `call`: once the callee is entered, normal completion returns to the caller of the current function rather than to the instruction after the tail call.
- A CFG that models ordinary `call` as a potentially throwing fallthrough node should still model `return_call*` as a terminator with a return edge, plus any exceptional/trap policy that the local IR chooses to track for calls.
- The archived proposal repository is useful for historical semantics, but the current core draft should be treated as the fresher source for instruction-family existence.

## Local Starshine Evidence To Pair With This Snapshot

- [`../../../../src/lib/types.mbt`](../../../../src/lib/types.mbt): core `Instruction::ReturnCall`, `ReturnCallIndirect`, and `ReturnCallRef` variants.
- [`../../../../src/ir/hot_core.mbt`](../../../../src/ir/hot_core.mbt): `HotOp::ReturnCall`, `ReturnCallIndirect`, and `ReturnCallRef` variants.
- [`../../../../src/ir/hot_flags.mbt`](../../../../src/ir/hot_flags.mbt): tail-call HOT ops carry `HOT_FLAG_CALL`, `HOT_FLAG_SIDE_EFFECT`, `HOT_FLAG_MAY_TRAP`, `HOT_FLAG_HAS_EXCEPTIONAL_SUCC`, and `HOT_FLAG_TERMINATOR`.
- [`../../../../src/ir/cfg.mbt`](../../../../src/ir/cfg.mbt): the concrete CFG builder maps `Return`, `ReturnCall`, `ReturnCallIndirect`, and `ReturnCallRef` tails to the synthetic normal exit with `ReturnEdge`.
- [`../../../../src/ir/cfg_contract.mbt`](../../../../src/ir/cfg_contract.mbt): the policy helper currently omits the tail-call HOT ops from `cfg_op_is_terminator(...)` and `cfg_terminator_edge_kinds(...)`; the living wiki records that as a local policy/helper gap rather than smoothing over it.
- [`../../../../src/validate/typecheck.mbt`](../../../../src/validate/typecheck.mbt): validates `return_call*` against the function return context and target signature.
- [`../../../../src/wast/lower_to_lib.mbt`](../../../../src/wast/lower_to_lib.mbt), [`../../../../src/binary/decode.mbt`](../../../../src/binary/decode.mbt), and [`../../../../src/binary/encode.mbt`](../../../../src/binary/encode.mbt): text and binary surfaces preserve the distinct tail-call instruction family.

## Caveats

- This manifest is not a complete tail-call opcode table. The wiki page only needs enough primary-source evidence to keep CFG semantics honest.
- The exact Starshine bug-fix, if any, belongs in source and tests, not in this raw manifest. The manifest records the semantic evidence that makes the CFG helper omission visible.
