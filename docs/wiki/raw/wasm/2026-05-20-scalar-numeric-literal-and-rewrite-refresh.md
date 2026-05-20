---
kind: raw-source-manifest
status: supported
last_reviewed: 2026-05-20
sources:
  - https://webassembly.github.io/spec/core/text/values.html
  - https://webassembly.github.io/spec/core/text/instructions.html
  - https://webassembly.github.io/spec/core/valid/instructions.html
  - https://webassembly.github.io/spec/core/exec/numerics.html
  - ../../../../src/wast/lexer.mbt
  - ../../../../src/wast/parser.mbt
  - ../../../../src/wast/lower_to_lib.mbt
  - ../../../../src/wast/module_wast.mbt
  - ../../../../src/wast/arbitrary.mbt
  - ../../../../src/lib/types.mbt
  - ../../../../src/validate/typecheck.mbt
  - ../../../../src/validate/validate.mbt
related:
  - ../../wast/numeric-instruction-authoring.md
  - ../../validate/constant-expressions.md
  - ../../binary/instruction-and-expression-encoding.md
  - ../../fuzzing/generator-coverage-ledger.md
---

# Scalar Numeric Literal And Rewrite Refresh (2026-05-20)

## Purpose

This targeted refresh extends the broader 2026-05-19 scalar numeric manifest with two details that future fixtures and optimizer work keep needing:

1. the boundary between official numeric literal spellings and Starshine's local WAST lexer / parser / lowering paths; and
2. the rewrite hazards around numeric operations that typecheck similarly but have different trap, saturation, bit-identity, signedness, NaN, or signed-zero behavior.

It does not replace the full scalar numeric instruction snapshot in [`2026-05-19-wast-numeric-instruction-sources.md`](2026-05-19-wast-numeric-instruction-sources.md); it sharpens the literal/rewrite subtopic used by [`../../wast/numeric-instruction-authoring.md`](../../wast/numeric-instruction-authoring.md).

## Primary external sources checked

- WebAssembly core spec, text values: <https://webassembly.github.io/spec/core/text/values.html>
  - Rechecked the current numeric text grammar for natural/integer/float literals, decimal and hexadecimal spellings, digit separators, infinities, and NaN payload spellings. This is the portability target for hand-written WAT/WAST numeric constants.
- WebAssembly core spec, text instructions: <https://webassembly.github.io/spec/core/text/instructions.html>
  - Rechecked that scalar numeric instructions still use literal immediates only for the four `*.const` forms; arithmetic, comparisons, conversions, reinterprets, sign extensions, and saturating truncations receive operands from the stack or folded child expressions.
- WebAssembly core spec, validation instructions: <https://webassembly.github.io/spec/core/valid/instructions.html>
  - Rechecked the stack typing shape: comparisons and integer tests produce `i32`, arithmetic and sign extensions preserve their named numeric type, and conversions/reinterprets have fixed source/result pairs.
- WebAssembly core spec, numeric execution: <https://webassembly.github.io/spec/core/exec/numerics.html>
  - Rechecked why rewrite safety is not just a typechecking question: ordinary float-to-int truncation, integer division/remainder, NaNs, signed zeros, min/max, and bit reinterpretation have semantics that optimizers must preserve rather than normalize by spelling alone.

## Local Starshine sources checked

- [`src/wast/lexer.mbt`](../../../../src/wast/lexer.mbt)
  - `read_num` and `read_hex_num` accept underscore-separated decimal/hex digit runs, and `get_hex_number_token` recognizes hexadecimal float syntax with `p`/`P` exponents. `get_inf_token` and `get_nan_token` recognize infinities and `nan` / payload forms at the token layer.
- [`src/wast/parser.mbt`](../../../../src/wast/parser.mbt)
  - Scalar constant AST nodes preserve the literal text for `i32.const`, `i64.const`, `f32.const`, and `f64.const`; WAST assertion-result parsing treats `nan:canonical` and `nan:arithmetic` as assertion expectations rather than ordinary exact payload values.
  - Index parsing uses bespoke helpers that strip underscores, so index and scalar-constant literal behavior should not be assumed identical.
- [`src/wast/lower_to_lib.mbt`](../../../../src/wast/lower_to_lib.mbt)
  - Scalar integer constant lowering currently delegates to `@string.parse_int64` for `wt_parse_i32` / `wt_parse_i64`, while SIMD-lane and index-adjacent helpers have more explicit unsigned/hex/underscore parsers. Treat non-decimal, separator-heavy, or unsigned-wrap scalar integer constants as a focused-test surface before relying on them broadly.
  - Float lowering recognizes `nan*` text when it reaches `wt_parse_f64`, then otherwise delegates to `@string.parse_double`. Exact payload spelling and printback should remain targeted-test territory.
- [`src/wast/module_wast.mbt`](../../../../src/wast/module_wast.mbt) and [`src/wast/arbitrary.mbt`](../../../../src/wast/arbitrary.mbt)
  - Printing preserves stored scalar constant text for ordinary constants; arbitrary WAST generation emits representative scalar literals including small integers, finite floats, infinities, and `nan`, but it is not a full portability proof for every official literal spelling.
- [`src/validate/typecheck.mbt`](../../../../src/validate/typecheck.mbt) and [`src/validate/validate.mbt`](../../../../src/validate/validate.mbt)
  - Typechecking enforces stack source/result pairs, while Starshine's extended constant-expression allow-list can admit local numeric forms beyond the current official constant-expression predicate. Both gates must be considered when moving numeric code into initializers.

## Durable conclusions

1. For portable hand-written WAT/WAST, cite the official text-value grammar. For current Starshine behavior, cite the lexer/parser/lowerer split as well; a token accepted by the lexer is not automatically proof that scalar lowering, binary roundtrip, assertion parsing, and printing preserve the same spelling.
2. Scalar constant text paths are not all the same. Index parsing strips separators explicitly, ordinary scalar integer lowering delegates to signed parsing, SIMD lanes have bespoke unsigned/hex helpers, and assertion NaN expectations use separate `nan:canonical` / `nan:arithmetic` variants.
3. Numeric rewrite safety must preserve runtime behavior, not only validation types. Non-saturating truncations and integer div/rem can trap; saturating truncations do not trap for the same out-of-range/NaN class; `reinterpret` preserves raw bits; signed and unsigned suffixes change interpretation; floating NaN/signed-zero/min/max behavior needs source- or oracle-backed proof.
4. Starshine's constant-expression policy is a local validation policy. It can accept broader numeric instruction families than the official constant-expression predicate, so pass documentation should say whether it is relying on Starshine-local validation or portable WebAssembly behavior.
5. `[FZG]002` valid-generator coverage and WAST arbitrary numeric text coverage are complementary. Generator coverage proves typed core numeric surfaces; WAST arbitrary coverage proves representative text spelling and roundtrip surfaces.
