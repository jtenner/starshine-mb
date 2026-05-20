# `call_ref` Source Refresh

- Capture date: 2026-05-20
- Source family: current WebAssembly Core specification pages plus Starshine WAST/core/binary/validator/generator code
- Primary sources checked:
  - WebAssembly Core Specification, `Syntax / Instructions — WebAssembly 3.0 (2026-05-14)`: <https://webassembly.github.io/spec/core/syntax/instructions.html>
  - WebAssembly Core Specification, `Binary Format / Instructions — WebAssembly 3.0 (2026-05-14)`: <https://webassembly.github.io/spec/core/binary/instructions.html>
  - WebAssembly Core Specification, `Validation / Instructions — WebAssembly 3.0 (2026-05-14)`: <https://webassembly.github.io/spec/core/valid/instructions.html>
  - WebAssembly Core Specification, `Execution / Instructions — WebAssembly 3.0 (2026-05-14)`: <https://webassembly.github.io/spec/core/exec/instructions.html>
  - Existing Starshine snapshots: [`2026-05-19-wast-call-and-function-sources.md`](2026-05-19-wast-call-and-function-sources.md), [`2026-05-19-wast-tail-call-sources.md`](2026-05-19-wast-tail-call-sources.md), and [`2026-05-13-ref-func-declaration-sources.md`](2026-05-13-ref-func-declaration-sources.md)

## Durable takeaways

- `call_ref` is an ordinary call-family instruction whose immediate is a function type index. It consumes the callee parameters followed by a function reference of that type and then produces the target function type's results.
- `return_call_ref` uses the same reference-call target shape but is a tail call: after consuming parameters and the function reference, validation requires the callee result list to equal the current function's result list and the local continuation becomes unreachable.
- The current WebAssembly binary opcode table assigns `call_ref` to `0x14` and `return_call_ref` to `0x15`; both carry a type index immediate.
- A `ref.func` instruction is one way to materialize a function reference for `call_ref`, but `call_ref` itself is not a `ref.func` declaration source. Declaration eligibility remains a separate module-level rule owned by [`../../validate/ref-func-declarations.md`](../../validate/ref-func-declarations.md).
- Current Starshine WAST exposes `return_call_ref` text but still does not expose ordinary non-tail `call_ref` text. Therefore ordinary `call_ref` evidence currently comes from core instruction builders, binary bytes, validator tests, valid generation, or optimizer-oracle inputs, not from human-authored WAST parser/printer fixtures.

## Starshine implications

- [`../../../../src/lib/types.mbt`](../../../../src/lib/types.mbt) models `Instruction::CallRef(TypeIdx)` and `Instruction::ReturnCallRef(TypeIdx)` separately, so passes can distinguish ordinary-result flow from tail-call termination.
- [`../../../../src/binary/decode.mbt`](../../../../src/binary/decode.mbt) and [`../../../../src/binary/encode.mbt`](../../../../src/binary/encode.mbt) roundtrip opcodes `0x14` and `0x15` with `TypeIdx` immediates.
- [`../../../../src/validate/typecheck.mbt`](../../../../src/validate/typecheck.mbt) currently expects the function reference after the callee parameters for both reference-call forms. It uses a nullable reference to the exact type index as the static operand type, then either pushes results for `call_ref` or sets the state unreachable for `return_call_ref` after checking current-function result compatibility.
- [`../../../../src/wast/keywords.mbt`](../../../../src/wast/keywords.mbt), [`../../../../src/wast/parser.mbt`](../../../../src/wast/parser.mbt), [`../../../../src/wast/lower_to_lib.mbt`](../../../../src/wast/lower_to_lib.mbt), and [`../../../../src/wast/module_wast.mbt`](../../../../src/wast/module_wast.mbt) cover `return_call_ref` but not ordinary `call_ref` text today.
- [`../../../../src/validate/gen_valid.mbt`](../../../../src/validate/gen_valid.mbt) can build natural `ref.func` + `call_ref` flows for ordinary values and `ref.func` + `return_call_ref` flows for tail positions when a declared callable function with compatible results is available.

## Caveats and supersession

- This refresh narrows the `call_ref` / `return_call_ref` split. It does not supersede the broader function/import/export authoring snapshot, the tail-call guide, or the `ref.func` declaration snapshot.
- The local operand-type wording is deliberately Starshine-specific: the current typechecker asks for a nullable reference to the immediate type index. If WebAssembly spec text, Binaryen, or Starshine later tightens nullability or traps-on-null handling for reference calls, update this manifest and the function/tail-call/reference pages together.
- If Starshine adds ordinary WAST `call_ref`, update [`../../wast/function-call-and-module-authoring.md`](../../wast/function-call-and-module-authoring.md), [`../../fuzzing/wast-arbitrary-parity-plan.md`](../../fuzzing/wast-arbitrary-parity-plan.md), the WAST parser/printer/lowerer tests, and the generator ledger so text support is no longer described as core/binary/generator-only.

## Local code map

- [`../../../../src/lib/types.mbt`](../../../../src/lib/types.mbt): `CallRef`, `ReturnCallRef`, and constructors.
- [`../../../../src/binary/decode.mbt`](../../../../src/binary/decode.mbt): binary opcode decode for `0x14` / `0x15`.
- [`../../../../src/binary/encode.mbt`](../../../../src/binary/encode.mbt): binary opcode encode for `0x14` / `0x15`.
- [`../../../../src/validate/typecheck.mbt`](../../../../src/validate/typecheck.mbt): stack typing for `call_ref` and `return_call_ref`.
- [`../../../../src/wast/keywords.mbt`](../../../../src/wast/keywords.mbt), [`../../../../src/wast/parser.mbt`](../../../../src/wast/parser.mbt), [`../../../../src/wast/lower_to_lib.mbt`](../../../../src/wast/lower_to_lib.mbt), [`../../../../src/wast/module_wast.mbt`](../../../../src/wast/module_wast.mbt): current WAST support boundary.
- [`../../../../src/validate/gen_valid.mbt`](../../../../src/validate/gen_valid.mbt): generated ordinary and tail reference-call flows.
