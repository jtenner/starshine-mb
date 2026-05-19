# WebAssembly WAST Tail-Call Sources (2026-05-19)

## Scope

Primary-source and local-code manifest for [`../../wast/tail-call-authoring.md`](../../wast/tail-call-authoring.md). This source snapshot focuses on authoring, lowering, binary encoding, validation, CFG, and pass-rewrite implications for `return_call`, `return_call_indirect`, and `return_call_ref` in Starshine WAST fixtures.

## Sources Checked

1. WebAssembly Core Specification draft / WebAssembly 3.0 bikeshed, instruction syntax and validation: <https://webassembly.github.io/spec/core/bikeshed/index.html> (searched/opened 2026-05-19). The current core instruction surface includes direct, indirect, and reference tail-call forms, and the validation rules require target result types to match the current function's return type.
2. W3C WebAssembly Core Specification page: <https://www.w3.org/TR/wasm-core/> (searched/opened 2026-05-19). The current W3C page describes `return_call`, `return_call_ref`, and `return_call_indirect` as tail-call variants of the corresponding call instructions.
3. WebAssembly Specification 3.0 PDF, 2026-04-09 release: <https://webassembly.github.io/spec/core/_download/WebAssembly.pdf> (searched/opened 2026-05-19). Used as the stable downloadable companion for the current draft validation text, including stack-polymorphic notes for tail-call forms.
4. WebAssembly tail-call proposal repository: <https://github.com/WebAssembly/tail-call> and proposal overview <https://github.com/WebAssembly/tail-call/blob/main/proposals/tail-call/Overview.md> (searched/opened 2026-05-19). The repository is now historical; use it for rationale that tail calls are return-position transfers and use the current core draft for live syntax/validation.
5. MDN `call` control-flow reference: <https://developer.mozilla.org/en-US/docs/WebAssembly/Reference/Control_flow/call> (searched 2026-05-19). Used only as a high-quality secondary cross-check that ordinary direct/indirect calls have corresponding tail-call variants; official spec sources remain normative.

## Durable Takeaways

- Tail-call forms are call-family instructions with no ordinary fallthrough continuation. After the callee returns normally, control returns to the caller of the current function.
- `return_call` carries a `funcidx`, like `call`, and consumes the callee parameters. Its callee result types must match the current function return type.
- `return_call_indirect` carries a table index plus type use/index, like `call_indirect`, and also consumes a table element index. It must select a function-reference-compatible table and its target results must match the current function return type.
- `return_call_ref` carries a function type use/index, consumes callee parameters plus a function reference, and has the same current-return-type constraint.
- In validation, successful tail-call instructions make the following instruction stream unreachable/stack-polymorphic rather than producing ordinary stack results for local continuation.
- Passes that rewrite function indices, type indices, table indices, signatures, or control flow must treat tail calls as both call-family use sites and return-family terminators.

## Local Starshine Evidence To Pair With This Snapshot

- [`../../../../src/wast/keywords.mbt`](../../../../src/wast/keywords.mbt): registers `return_call`, `return_call_indirect`, and `return_call_ref` as WAST opcodes.
- [`../../../../src/wast/parser.mbt`](../../../../src/wast/parser.mbt): parses `return_call` with a required function index, `return_call_indirect` with optional table index plus type use, and `return_call_ref` with a type use.
- [`../../../../src/wast/lower_to_lib.mbt`](../../../../src/wast/lower_to_lib.mbt): resolves WAST identifiers/type uses into core `FuncIdx`, `TableIdx`, and `TypeIdx` carriers.
- [`../../../../src/wast/module_wast.mbt`](../../../../src/wast/module_wast.mbt): prints the three tail-call forms and makes parsed default-table abbreviations explicit on roundtrip output.
- [`../../../../src/lib/types.mbt`](../../../../src/lib/types.mbt): core `Instruction::ReturnCall`, `ReturnCallIndirect`, and `ReturnCallRef` variants plus constructor helpers.
- [`../../../../src/binary/decode.mbt`](../../../../src/binary/decode.mbt) and [`../../../../src/binary/encode.mbt`](../../../../src/binary/encode.mbt): binary opcodes `0x12`, `0x13`, and `0x15` for direct, indirect, and reference tail calls.
- [`../../../../src/validate/typecheck.mbt`](../../../../src/validate/typecheck.mbt): validates return-type compatibility and marks the final state unreachable for all three tail-call forms.
- [`../../../../src/ir/hot_flags.mbt`](../../../../src/ir/hot_flags.mbt) and [`../../../../src/ir/cfg.mbt`](../../../../src/ir/cfg.mbt): HOT flags and concrete CFG builder treat tail calls as call-family terminators with return-edge control flow.
- [`../../../../src/wast/arbitrary.mbt`](../../../../src/wast/arbitrary.mbt): WAST arbitrary can emit representative tail-call surface opcodes, so fixture and fuzz guidance should keep them distinct from ordinary calls.

## Caveats And Supersession

- This manifest supersedes the narrower CFG-only role of [`2026-05-19-tail-call-control-flow-sources.md`](2026-05-19-tail-call-control-flow-sources.md) for WAST fixture authoring. The older manifest remains useful for IR2 CFG semantics.
- The official core draft and W3C page are fresher than the archived proposal repository. Do not use proposal-era opcode or validation wording to override the current spec.
- Starshine's WAST roundtrip printer may expand omitted table indices for `return_call_indirect`; that is a local presentation detail, not a semantic change.
