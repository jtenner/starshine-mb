# Reference Branch And Cast Validation Refresh (2026-05-20)

Purpose: targeted primary-source and local-code refresh for the living guide [`../../wast/reference-instruction-authoring.md`](../../wast/reference-instruction-authoring.md), focused on ordinary `ref.test` / `ref.cast`, `br_on_null` / `br_on_non_null`, and `br_on_cast` / `br_on_cast_fail` branch-outcome semantics.

## Primary and high-quality external sources checked

1. **Current WebAssembly Core 3.0 validation instruction page**
   - URL: <https://webassembly.github.io/spec/core/valid/instructions.html>
   - Checked for ordinary reference-instruction validation rules.
   - Finding: the current generated validation page is the best live HTML anchor for `ref.null`, `ref.func`, `ref.is_null`, `ref.eq`, `ref.as_non_null`, `ref.test`, and `ref.cast`: validation, not binary decode, owns target-reference typing, function-index existence, nullability, cast/test compatibility, and result stack types.

2. **Current WebAssembly Core 3.0 syntax instruction page**
   - URL: <https://webassembly.github.io/spec/core/syntax/instructions.html>
   - Checked for reference-family instruction names and the note listing the branch-on-reference forms.
   - Finding: the split HTML source exposes the ordinary reference family directly and still mentions `br_on_null`, `br_on_non_null`, `br_on_cast`, and `br_on_cast_fail` in the reference-branch note, but the generated pages are less direct than local code for teaching the exact branch/fallthrough stack split.

3. **Current WebAssembly Core 3.0 text and binary instruction pages**
   - URLs: <https://webassembly.github.io/spec/core/text/instructions.html>, <https://webassembly.github.io/spec/core/binary/instructions.html>
   - Checked for the distinction between text authoring, byte opcodes/immediates, and semantic validation.
   - Finding: text and binary syntax are carrier layers. They do not prove `ref.func` declaration membership, cast hierarchy compatibility, or reference-branch label-payload legality.

4. **WebAssembly GC / function-reference proposal lineage pages**
   - URLs: <https://webassembly.github.io/gc/core/valid/instructions.html>, <https://webassembly.github.io/function-references/core/valid/instructions.html>
   - Checked as historical context for branch-on-reference instructions and GC cast/test families that Starshine already models.
   - Finding: use the current Core 3.0 pages as the durable normative anchor where they are explicit; use proposal-era pages only to explain lineage or gaps in the generated split HTML pages.

## Starshine local sources checked

- [`src/wast/keywords.mbt`](../../../../src/wast/keywords.mbt)
  - Confirms current WAST text keywords include `ref.null`, `ref.is_null`, `ref.func`, `ref.eq`, `ref.as_non_null`, and descriptor `ref.test_desc` / `ref.cast_desc_eq` forms, but not ordinary `ref.test`, ordinary `ref.cast`, or `br_on_*` text forms.
- [`src/wast/parser.mbt`](../../../../src/wast/parser.mbt)
  - Confirms parser cases mirror the keyword split and only parse descriptor-family cast/test immediates today.
- [`src/lib/types.mbt`](../../../../src/lib/types.mbt)
  - Confirms the core instruction enum models `BrOnNull`, `BrOnNonNull`, `RefTest`, `RefCast`, `BrOnCast`, and `BrOnCastFail`, and that `CastOp` stores source and target nullability for branch-on-cast instructions.
- [`src/binary/decode.mbt`](../../../../src/binary/decode.mbt) and [`src/binary/encode.mbt`](../../../../src/binary/encode.mbt)
  - Confirms one-byte `0xD5` / `0xD6` handling for `br_on_null` / `br_on_non_null` and `0xFB` subcodes `20` through `25` for ordinary ref test/cast plus branch-on-cast families.
- [`src/validate/typecheck.mbt`](../../../../src/validate/typecheck.mbt)
  - Confirms the local branch split: `br_on_null` branches on null and refines fallthrough to non-null; `br_on_non_null` branches with a non-null reference as the final label payload and consumes the fallthrough operand; `br_on_cast` branches on successful cast and pushes the difference type on fallthrough; `br_on_cast_fail` branches on failed cast and pushes the target type on successful fallthrough.
- [`src/validate/typecheck_negative_tests.mbt`](../../../../src/validate/typecheck_negative_tests.mbt) and the focused tests in [`src/validate/typecheck.mbt`](../../../../src/validate/typecheck.mbt)
  - Confirm representative positive and negative coverage for label-payload slots, incompatible cast hierarchies, and empty-label rejections around branch-on-cast families.
- [`src/validate/gen_valid.mbt`](../../../../src/validate/gen_valid.mbt)
  - Confirms coverage-forced `[FZG]009` generation still emits ordinary `ref.test` / `ref.cast`, `br_on_null`, `br_on_non_null`, and nullable/nonnullable branch-on-cast shapes at the core/binary-AST layer.

## Durable conclusions

1. The 2026-05-19 reference-instruction source snapshot remains valid for the broad WAST/core/binary/validator split. This refresh narrows the teaching focus to branch outcomes and cast/test validation.
2. Starshine's core/binary/validator coverage for ordinary `ref.test`, ordinary `ref.cast`, and `br_on_*` remains broader than the WAST text surface. Human-authored WAST fixtures should still use descriptor text forms or direct core/binary fixtures until parser/printer widening lands.
3. Reference-branch instructions are not just ordinary branches with a reference operand. Each instruction has a branch-path and fallthrough-path type transformation, and the final label-payload slot is special for `br_on_non_null`, `br_on_cast`, and `br_on_cast_fail`.
4. `CastOp` nullability belongs to `br_on_cast` / `br_on_cast_fail` source and target reference types. It is not descriptor exactness and should not be reused as a descriptor-cast flag.
5. A pass that changes labels, block types, reference types, or cast/test targets must rerun validation and should include direct core/binary fixtures for branch-on-reference behavior until WAST text support exists.
6. Keep external-source strength explicit: current Core 3.0 pages are authoritative for ordinary reference validation; branch-on-reference details are also grounded in Starshine code because the split HTML pages are less direct for those forms than the local typed implementation.
