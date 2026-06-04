---
kind: raw-source-manifest
status: supported
last_reviewed: 2026-06-04
sources:
  - https://webassembly.github.io/spec/core/syntax/instructions.html
  - https://webassembly.github.io/spec/core/text/instructions.html
  - https://webassembly.github.io/spec/core/binary/instructions.html
  - https://webassembly.github.io/spec/core/valid/instructions.html
  - ../../../../src/wast/parser.mbt
  - ../../../../src/wast/lower_to_lib.mbt
  - ../../../../src/binary/decode.mbt
  - ../../../../src/binary/encode.mbt
  - ../../../../src/validate/typecheck.mbt
  - ../../../../src/validate/invalid_fuzzer.mbt
  - ../../../../src/validate/gen_invalid.mbt
  - ../../../../src/validate/gen_invalid_tests.mbt
  - ../../../../src/fuzz/invalid_binary.mbt
  - ../../../../src/fuzz/invalid_binary_wbtest.mbt
related:
  - ../../validate/simd-lane-immediates.md
  - ../../wast/simd-authoring.md
  - ../../binary/instruction-and-expression-encoding.md
  - ../../validate/fuzz-hardening.md
---

# SIMD Lane Validation Current Refresh - 2026-06-04

This manifest refreshes the SIMD lane-immediate contract after a wiki-health check found stale wording in the WAST and binary guides. The old 2026-05-20 manifest correctly described the then-open gap: Starshine WAST lowering enforced exact shape bounds, while binary/library-origin `LaneIdx` values could pass the coarse byte decoder and were not yet rechecked by the typechecker. That local gap was closed by the 2026-05-24 FUZ1020 SIMD lane-index slice; this 2026-06-04 refresh records the current official-source baseline plus the current Starshine layer split.

## Primary sources checked

- WebAssembly Core 3.0 syntax instructions, current page dated 2026-06-03: <https://webassembly.github.io/spec/core/syntax/instructions.html>. The vector grammar defines lane shapes by lane type and dimension, defines `laneidx` as an unsigned byte immediate, gives `i8x16.shuffle` a lane-index list whose length equals the byte-shape dimension, and gives extract/replace forms one lane-index immediate.
- WebAssembly Core 3.0 text instructions, current page dated 2026-06-03: <https://webassembly.github.io/spec/core/text/instructions.html>. The text grammar keeps `v128.const` shape descriptors and lane-index operands in the SIMD text surface, including `i8x16.shuffle` with exactly sixteen lane indices and shape-specific extract/replace names.
- WebAssembly Core 3.0 binary instructions, current page dated 2026-06-03: <https://webassembly.github.io/spec/core/binary/instructions.html>. Vector instructions use the `0xFD` prefix with variable-length unsigned subopcodes; shuffle is followed by sixteen `laneidx` immediates, and lane instructions are followed by one `laneidx` immediate.
- WebAssembly Core 3.0 validation instructions, current page dated 2026-06-03: <https://webassembly.github.io/spec/core/valid/instructions.html>. Validation, not just byte syntax, imposes the shape rules: each shuffle lane must be below twice the byte-lane dimension, while extract and replace lanes must be below the selected shape dimension and must type with the shape's unpacked lane type.

## Starshine sources checked

- [`src/wast/parser.mbt`](../../../../src/wast/parser.mbt) parses natural lane-index tokens and the fixed shuffle lane list before lowering.
- [`src/wast/lower_to_lib.mbt`](../../../../src/wast/lower_to_lib.mbt) still rejects WAST-origin bad lanes before constructing core instructions: `wt_shuffle_lane` accepts `0..31`, while `wt_lane_idx` receives exact maxima `15`, `7`, `3`, or `1` for extract, replace, load-lane, and store-lane forms.
- [`src/binary/decode.mbt`](../../../../src/binary/decode.mbt) remains intentionally coarse for single-lane bytes: generic `Decode for LaneIdx` accepts byte values below `16`, and the shuffle decoder accepts lane bytes below `32`. This is byte-layer well-formedness, not the final shape-validity proof.
- [`src/validate/typecheck.mbt`](../../../../src/validate/typecheck.mbt) now owns the library/binary-origin shape proof through `typecheck_lane_index`, `typecheck_lane_extract`, `typecheck_lane_replace`, `typecheck_v128_load_lane`, and `typecheck_v128_store_lane`. The instruction dispatcher passes lane counts `16`, `8`, `4`, or `2` according to the selected SIMD lane family.
- [`src/validate/invalid_fuzzer.mbt`](../../../../src/validate/invalid_fuzzer.mbt) has invalid-AST strategies for shape-specific lane bounds: `i64x2.extract_lane 2`, `i16x8.replace_lane 8`, `v128.load64_lane 2`, and `v128.store32_lane 4` reject with `FunctionBodyFamily`, while repaired maximum-in-range variants validate.
- [`src/validate/gen_invalid.mbt`](../../../../src/validate/gen_invalid.mbt) and [`src/validate/gen_invalid_tests.mbt`](../../../../src/validate/gen_invalid_tests.mbt) expose those strategies as stable ids `invalid-function-body-simd-extract-lane-index`, `invalid-function-body-simd-replace-lane-index`, `invalid-function-body-simd-load-lane-index`, and `invalid-function-body-simd-store-lane-index`.
- [`src/fuzz/invalid_binary.mbt`](../../../../src/fuzz/invalid_binary.mbt) and [`src/fuzz/invalid_binary_wbtest.mbt`](../../../../src/fuzz/invalid_binary_wbtest.mbt) keep the separate malformed-byte lane: shuffle lanes above `31` and generic single-lane bytes above `15` still reject during decode, while shape-specific but byte-well-formed mistakes are validator responsibilities.

## Durable conclusions

1. The official contract is unchanged from the earlier manifests: `laneidx` is a byte-shaped immediate in syntax/binary, but validation is where that immediate becomes legal for a particular SIMD shape.
2. The old Starshine caveat has been superseded locally. Binary/library-origin single-lane immediates may still decode through a coarse `<16` byte guard, but they now fail module validation when the selected instruction's lane count is smaller.
3. The decode/validation split is still important for tests and fuzzing. Use decode-rejected invalid-binary fixtures for malformed or overwide lane bytes (`>=16` for ordinary single-lane forms and `>=32` for shuffle). Use invalid-AST or validator-stage fixtures for shape-specific lane errors that fit in the byte envelope, such as `i64x2.extract_lane 2`.
4. WAST lowering remains the earliest and strongest text-origin guard, so WAST negative tests are useful parser/lowerer regressions but should not be cited as binary-origin validation proof.
5. Optimizer passes must preserve the shape/lane relation when changing SIMD opcodes. A byte-preserved `LaneIdx(3)` can be legal for `i32x4.extract_lane` and invalid for `i64x2.extract_lane`.

## Supersession note

This manifest supersedes the local-gap claims in [`2026-05-19-wast-simd-sources.md`](2026-05-19-wast-simd-sources.md) and the initial [`2026-05-20-simd-lane-immediate-validation-refresh.md`](2026-05-20-simd-lane-immediate-validation-refresh.md) where they say Starshine's typechecker does not re-check binary-origin shape-specific lane bounds. Those older manifests remain useful immutable provenance for the original gap and the test-layer plan.
