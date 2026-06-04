# Reference Call, Cast, And Branch Current Refresh

- Capture date: 2026-06-04
- Source family: current WebAssembly Core 3.0 pages dated 2026-06-03 plus Starshine WAST/core/binary/validator/generator source surfaces
- Purpose: refresh the living WAST reference/call pages without changing the local implementation. This note supersedes neither the 2026-05-20 `call_ref` nor reference-branch refreshes; it narrows the current-source routing and records one source-navigation caveat.

## Primary sources checked

- WebAssembly Core 3.0 syntax instructions, dated 2026-06-03: <https://webassembly.github.io/spec/core/syntax/instructions.html>
- WebAssembly Core 3.0 text instructions, dated 2026-06-03: <https://webassembly.github.io/spec/core/text/instructions.html>
- WebAssembly Core 3.0 binary instructions, dated 2026-06-03: <https://webassembly.github.io/spec/core/binary/instructions.html>
- WebAssembly Core 3.0 validation instructions, dated 2026-06-03: <https://webassembly.github.io/spec/core/valid/instructions.html>
- Function references proposal validation page: <https://webassembly.github.io/function-references/core/valid/instructions.html>
- GC proposal validation page: <https://webassembly.github.io/gc/core/valid/instructions.html>

## Local Starshine sources checked

- [`src/wast/keywords.mbt`](../../../../src/wast/keywords.mbt)
- [`src/wast/parser.mbt`](../../../../src/wast/parser.mbt)
- [`src/wast/lower_to_lib.mbt`](../../../../src/wast/lower_to_lib.mbt)
- [`src/wast/module_wast.mbt`](../../../../src/wast/module_wast.mbt)
- [`src/lib/types.mbt`](../../../../src/lib/types.mbt)
- [`src/binary/decode.mbt`](../../../../src/binary/decode.mbt)
- [`src/binary/encode.mbt`](../../../../src/binary/encode.mbt)
- [`src/validate/typecheck.mbt`](../../../../src/validate/typecheck.mbt)
- [`src/validate/gen_valid.mbt`](../../../../src/validate/gen_valid.mbt)
- [`src/wast/arbitrary.mbt`](../../../../src/wast/arbitrary.mbt)

## Durable takeaways

1. The current official syntax page still classifies `call_ref` as a control instruction and lists `br_on_null`, `br_on_non_null`, `br_on_cast`, and `br_on_cast_fail` as the reference-branch family. It also lists ordinary `ref.test` and `ref.cast` in the reference-instruction family.
2. The current official text page keeps most control instructions, including `call_ref`, on the generic verbatim-control path instead of giving every call-family opcode a separate text subsection. Do not read the lack of a standalone `call_ref` subsection as absence of official text syntax.
3. The current official binary page remains explicit that `call_ref` is opcode `0x14` with a `typeidx` immediate and `return_call_ref` is opcode `0x15` with a `typeidx` immediate. It also keeps the one-byte `br_on_null` / `br_on_non_null` encodings and GC-prefixed `ref.test`, `ref.cast`, `br_on_cast`, and `br_on_cast_fail` encodings.
4. The generated current Core 3.0 validation HTML is strong for ordinary `ref.test` / `ref.cast` result typing but is not the easiest live anchor for branch-on-reference or `call_ref` stack details. Keep the proposal-era function-references / GC pages and Starshine's local typechecker linked as teaching aids while treating Core 3.0 syntax/binary pages as the current portable carrier anchors.
5. Starshine still has a narrower high-level WAST text surface than its core/binary/validator/generator model. `return_call_ref`, basic `ref.*`, and local descriptor-family `ref.test_desc*` / `ref.cast_desc_eq*` parse today. Ordinary non-tail `call_ref`, ordinary `ref.test`, ordinary `ref.cast`, and `br_on_*` still need core builders, binary bytes, or generator/oracle fixtures until WAST keyword/parser/lowerer/printer support is added.

## Starshine implications

- `src/wast/keywords.mbt`, `src/wast/parser.mbt`, `src/wast/lower_to_lib.mbt`, and `src/wast/module_wast.mbt` prove the text split: `return_call_ref` and descriptor cast/test forms exist; ordinary `call_ref`, ordinary `ref.test` / `ref.cast`, and `br_on_*` keyword cases are absent.
- `src/lib/types.mbt`, `src/binary/decode.mbt`, and `src/binary/encode.mbt` prove the wider core/binary split: `CallRef`, `ReturnCallRef`, `RefTest`, `RefCast`, `BrOnNull`, `BrOnNonNull`, `BrOnCast`, and `BrOnCastFail` are real core instructions with byte-level roundtrip coverage.
- `src/validate/typecheck.mbt` remains the most precise local anchor for stack order and refinement: `typecheck_call_ref`, `typecheck_return_call_ref`, `typecheck_br_on_null`, `typecheck_br_on_non_null`, `typecheck_br_on_cast`, `typecheck_br_on_cast_fail`, `typecheck_ref_test`, and `typecheck_ref_cast` own Starshine's current semantic checks.
- `src/validate/gen_valid.mbt` can still generate ordinary core/generator coverage for reference calls, casts, and branches, while `src/wast/arbitrary.mbt` should keep emitting only text-supported shapes.

## Caveats and supersession

- This note refreshes source routing against the 2026-06-03 official pages. It does not claim a Starshine behavior change.
- The earlier 2026-05-20 notes remain useful for the detailed local stack-shape explanations. This note only adds the current-source caveat that Core 3.0 generated validation HTML is less direct than syntax/binary/proposal/local sources for some function-reference branch details.
- If Starshine adds WAST text for ordinary `call_ref`, ordinary `ref.test` / `ref.cast`, or `br_on_*`, update the WAST pages, WAST arbitrary parity plan, generator ledger, parser/lowerer/printer tests, and this source family together.
