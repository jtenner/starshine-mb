# WAST reference-instruction source snapshot (2026-05-19)

Purpose: primary-source and local-code manifest for the living guide [`../../wast/reference-instruction-authoring.md`](../../wast/reference-instruction-authoring.md). This source snapshot covers ordinary reference instructions, GC cast/test instructions, reference-branch instructions, and the current Starshine WAST text-surface boundary.

## Primary and high-quality external sources checked

1. **Current WebAssembly core syntax instruction page**
   - URL: <https://webassembly.github.io/spec/core/syntax/instructions.html>
   - Checked for the abstract instruction vocabulary around `ref.null`, `ref.func`, `ref.is_null`, `ref.eq`, `ref.as_non_null`, `ref.test`, `ref.cast`, `br_on_null`, `br_on_non_null`, `br_on_cast`, and `br_on_cast_fail`.
   - Finding: the current generated split HTML exposes the reference-family core instruction syntax, including `ref.test` and `ref.cast`; the generated page is less useful for the full branch-on-reference vocabulary than the current W3C release PDF / bikeshed-derived sources below.

2. **Current WebAssembly core text instruction page**
   - URL: <https://webassembly.github.io/spec/core/text/instructions.html>
   - Checked for text grammar around heap-type immediates, function indices, and folded/plain reference instruction authoring.
   - Finding: text-level reference instructions are ordinary instructions that use heap-type, reference-type, function-index, label-index, and cast-op immediates depending on the instruction family; Starshine's current WAST parser implements only a subset of that text surface.

3. **Current WebAssembly core binary instruction page**
   - URL: <https://webassembly.github.io/spec/core/binary/instructions.html>
   - Checked for opcode/immediate split between one-byte reference instructions (`0xD0` through `0xD6`) and GC-prefixed reference test/cast / branch forms under `0xFB`.
   - Finding: binary encoding is a syntax-level carrier; semantic checks such as `ref.func` declaration membership, cast compatibility, branch label payloads, and nullability refinements belong in validation/typechecking.

4. **Current WebAssembly core validation instruction page**
   - URL: <https://webassembly.github.io/spec/core/valid/instructions.html>
   - Checked for stack effects and validation constraints for `ref.null`, `ref.func`, `ref.is_null`, `ref.eq`, `ref.as_non_null`, `ref.test`, and `ref.cast`.
   - Finding: validation rather than decode decides index existence, allowed `ref.func` targets, nullable-reference requirements, cast/test compatibility, and the result type pushed after casts.

5. **W3C WebAssembly Core Specification 3.0 Recommendation PDF**
   - URL: <https://www.w3.org/TR/wasm-core-3/_download/WebAssembly.pdf>
   - Checked with PDF text search for `br_on_null`, `br_on_non_null`, `br_on_cast`, and `br_on_cast_fail` because the generated split HTML pages can be harder to navigate for these names.
   - Finding: the current W3C release artifact is the more direct primary-source anchor for teaching the branch-on-reference instruction names alongside the ordinary reference instruction family.

6. **WebAssembly GC / function-reference proposal-era specification pages**
   - URLs: <https://webassembly.github.io/gc/core/text/instructions.html>, <https://webassembly.github.io/gc/core/valid/instructions.html>, and <https://webassembly.github.io/function-references/core/text/instructions.html>
   - Checked only as lineage/context for the reference instruction families that Starshine already models.
   - Finding: use the current core/W3C sources above as normative for durable wiki claims. Proposal-era pages are useful when explaining why Starshine has local surfaces such as `br_on_*` and GC cast/test operators, but they should not override the current core spec.

## Starshine local sources checked

- [`src/wast/keywords.mbt`](../../../../src/wast/keywords.mbt)
  - Registers `ref.null`, `ref.is_null`, `ref.func`, `ref.eq`, `ref.as_non_null`, descriptor-family `ref.test_desc` / `ref.cast_desc_eq` keywords, but no ordinary `ref.test` / `ref.cast` / `br_on_*` WAST text keywords in this snapshot.
- [`src/wast/parser.mbt`](../../../../src/wast/parser.mbt)
  - Parses `ref.null` immediates, `ref.func` indices, ordinary no-argument `ref.is_null`, `ref.eq`, `ref.as_non_null`, and descriptor test/cast forms; parser tests cover abstract heap refs and exact `ref.null` shapes.
- [`src/wast/lower_to_lib.mbt`](../../../../src/wast/lower_to_lib.mbt)
  - Resolves `ref.func` through the module function-id map, resolves `ref.null` heap/type immediates into core nullable reference types, and lowers descriptor test/cast type immediates to `Instruction::ref_test_desc` / `Instruction::ref_cast_desc_eq`.
- [`src/wast/module_wast.mbt`](../../../../src/wast/module_wast.mbt)
  - Prints the WAST-supported subset (`ref.null`, `ref.is_null`, `ref.func`, `ref.eq`, `ref.as_non_null`, descriptor-family forms) but has no text rendering for ordinary `ref.test`, `ref.cast`, or branch-on-reference forms.
- [`src/lib/types.mbt`](../../../../src/lib/types.mbt)
  - Core `Instruction` already models `RefNull`, `RefIsNull`, `RefFunc`, `RefEq`, `RefAsNonNull`, `BrOnNull`, `BrOnNonNull`, `RefTest`, `RefCast`, `RefTestDesc`, `RefCastDescEq`, `BrOnCast`, and `BrOnCastFail`.
- [`src/binary/decode.mbt`](../../../../src/binary/decode.mbt) and [`src/binary/encode.mbt`](../../../../src/binary/encode.mbt)
  - Decode/encode one-byte `0xD0`-`0xD6` reference opcodes and GC-prefixed `0xFB` test/cast/branch subcodes; the byte codec does not decide semantic validity.
- [`src/validate/typecheck.mbt`](../../../../src/validate/typecheck.mbt)
  - Owns stack effects and semantic checks for `ref.null`, `ref.func`, `ref.is_null`, `ref.eq`, `ref.as_non_null`, ordinary `ref.test` / `ref.cast`, descriptor test/cast, `br_on_null`, `br_on_non_null`, `br_on_cast`, and `br_on_cast_fail`.
- [`src/validate/validate.mbt`](../../../../src/validate/validate.mbt)
  - Owns `ref_func_declarations` whole-module checking and generator-coverage assertions for the basic-reference instruction surface.
- [`src/validate/gen_valid.mbt`](../../../../src/validate/gen_valid.mbt)
  - Coverage-forced valid generation emits widened basic-reference shapes, including ordinary ref test/cast and reference-branch core instructions behind the reference-type feature gate.
- [`src/wast/arbitrary.mbt`](../../../../src/wast/arbitrary.mbt)
  - WAST arbitrary includes descriptor reference test/cast forms in its widened text prelude, but does not prove ordinary `ref.test` / `ref.cast` / `br_on_*` text support because those parser/printer surfaces are currently absent.

## Durable conclusions

1. Reference instructions span four separate contracts: WAST text authoring, core `Instruction` representation, binary opcode/immediate syntax, and validator/typechecker semantics.
2. Starshine's WAST text surface is intentionally narrower than its core/binary/validator surface in this snapshot. Text fixtures can directly author `ref.null`, `ref.is_null`, `ref.func`, `ref.eq`, `ref.as_non_null`, and descriptor `ref.test_desc` / `ref.cast_desc_eq`, but not ordinary `ref.test`, ordinary `ref.cast`, `br_on_null`, `br_on_non_null`, `br_on_cast`, or `br_on_cast_fail`.
3. Core/binary/validator support for the missing WAST text forms is real local evidence. Tests for those forms should use core/binary fixtures or first widen WAST keywords, parser, lowerer, printer, and tests.
4. `ref.func` has an extra whole-module declaration invariant beyond ordinary stack typing; the focused validator page remains canonical for declaration sources and the current start-section local/spec divergence.
5. Reference-branch instructions combine reference typing and control-flow label payloads. Their WAST authoring gap belongs in the new focused reference guide, while ordinary label-depth and `br_if`/`br_table` mechanics remain in the control-flow guide.
6. Keep external-source claims explicit: proposal-era GC/function-reference pages can explain lineage, but current WebAssembly core/W3C sources are the durable authority for normative syntax and validation claims.
