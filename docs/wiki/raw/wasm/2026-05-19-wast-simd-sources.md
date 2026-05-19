---
kind: raw-source-manifest
status: supported
last_reviewed: 2026-05-19
sources:
  - https://webassembly.github.io/spec/core/text/instructions.html
  - https://webassembly.github.io/spec/core/binary/instructions.html
  - https://webassembly.github.io/spec/core/valid/instructions.html
  - ../../../../src/wast/parser.mbt
  - ../../../../src/wast/lower_to_lib.mbt
  - ../../../../src/wast/module_wast.mbt
  - ../../../../src/wast/keywords.mbt
  - ../../../../src/wast/arbitrary.mbt
  - ../../../../src/lib/types.mbt
  - ../../../../src/binary/decode.mbt
  - ../../../../src/binary/encode.mbt
  - ../../../../src/validate/typecheck.mbt
  - ../../../../src/validate/gen_valid.mbt
  - ../../../../src/validate/validate.mbt
related:
  - ../../wast/simd-authoring.md
  - ../../binary/instruction-and-expression-encoding.md
  - ../../fuzzing/generator-coverage-ledger.md
  - ../../fuzzing/wast-arbitrary-parity-plan.md
---

# WAST SIMD Authoring Sources - 2026-05-19

This manifest captures the primary-source and in-repository evidence used to add the focused WAST SIMD authoring guide.

## Official WebAssembly sources checked

- WebAssembly 3.0 core text instructions: vector text syntax includes lane-shaped `v128.const` forms, SIMD lane immediates, memory arguments on vector loads/stores, shuffle/swizzle, splat, lane extract/replace, comparisons, arithmetic, conversions, and relaxed SIMD spellings in the same instruction table. URL: <https://webassembly.github.io/spec/core/text/instructions.html>.
- WebAssembly 3.0 core binary instructions: SIMD instructions use the `0xFD` prefixed opcode space, `v128.const` carries exactly 16 literal bytes, `i8x16.shuffle` carries 16 lane bytes that may select from the two input vectors, and lane/memory immediates are encoded as instruction immediates rather than stack values. URL: <https://webassembly.github.io/spec/core/binary/instructions.html>.
- WebAssembly 3.0 instruction validation: vector instructions are stack-typed through the ordinary validation context. Constants produce `v128`, lane extract/replace move between `v128` and scalar lane types, vector memory operations use the selected memory's address type, and relaxed SIMD instructions remain ordinary stack-typed instructions rather than a separate module section. URL: <https://webassembly.github.io/spec/core/valid/instructions.html>.

## Starshine sources checked

- [`src/wast/keywords.mbt`](../../../../src/wast/keywords.mbt) maps SIMD text opcodes such as `v128.const`, `i8x16.shuffle`, and relaxed SIMD names to WAST opcode variants.
- [`src/wast/parser.mbt`](../../../../src/wast/parser.mbt) parses lane-shaped `v128.const` payloads, lane indices, `i8x16.shuffle` lane lists, and SIMD memory immediates through the shared `MemArg` parser.
- [`src/wast/lower_to_lib.mbt`](../../../../src/wast/lower_to_lib.mbt) lowers lane-shaped text into canonical 16-byte `Instruction::V128Const`, checks lane immediates for WAST-originated extract/replace/load-lane/store-lane/shuffle forms, preserves integer hex literal byte order, accepts float NaN payload spellings, and has focused WAST-to-core tests for positive and negative SIMD fixtures.
- [`src/wast/module_wast.mbt`](../../../../src/wast/module_wast.mbt) prints SIMD instructions back to text, including rendered `v128.const` and shuffle lane lists.
- [`src/lib/types.mbt`](../../../../src/lib/types.mbt) defines `ValType::v128`, `V128Const`, SIMD `Instruction` variants, and `LaneIdx`.
- [`src/binary/decode.mbt`](../../../../src/binary/decode.mbt) decodes `0xFD` SIMD instructions, reads `v128.const` as 16 bytes, uses a coarse generic single-lane decoder that accepts lane bytes below `16`, and has a custom shuffle decoder that accepts lane bytes below `32`.
- [`src/binary/encode.mbt`](../../../../src/binary/encode.mbt) re-emits SIMD instructions under the `0xFD` prefix, including `v128.const`, shuffle, single-lane immediates, vector memory operations, and relaxed SIMD opcodes.
- [`src/validate/typecheck.mbt`](../../../../src/validate/typecheck.mbt) stack-types vector constants, vector unary/binary/ternary operations, lane extract/replace, memory load/store/lane forms, and relaxed SIMD instructions; lane bounds for WAST-originated text are enforced earlier by lowering.
- [`src/validate/gen_valid.mbt`](../../../../src/validate/gen_valid.mbt) and [`src/validate/validate.mbt`](../../../../src/validate/validate.mbt) own the `[FZG]014` through `[FZG]016` valid-generator SIMD feature counters and coverage-forced fixtures.
- [`src/wast/arbitrary.mbt`](../../../../src/wast/arbitrary.mbt) currently emits only a representative WAST `v128.const` shape in the widened arbitrary prelude, so richer SIMD text generation remains an authoring-guide-backed future widening target rather than a completed parser/printer parity claim.

## Durable conclusions

1. SIMD authoring belongs in a WAST-focused page because the most common fixture mistakes are text-shape mistakes: wrong lane count, wrong lane index range, misread `v128.const` byte order, missing memory arguments, or assuming relaxed SIMD needs a separate declaration.
2. Starshine's long-lived core representation stores `v128.const` as raw bytes. Text shapes such as `i16x8` and `i32x4` are authoring conveniences that lower to little-endian byte sequences.
3. `i8x16.shuffle` is special: each immediate lane may address either input vector, so WAST lowering and binary decode accept `0..31`, not only `0..15`.
4. Single-lane extract/replace and load-lane/store-lane forms are shape-specific in WAST lowering: `i8x16` has 16 lanes, `i16x8` has 8, `i32x4` / `f32x4` have 4, and `i64x2` / `f64x2` have 2.
5. Binary-origin lane validation is currently weaker than WAST-origin lane validation: WAST lowering enforces shape-specific bounds, while binary decode accepts any generic single-lane immediate below `16` and the typechecker does not re-check lane ranges. A future hardening slice should add per-instruction binary/validation tests.
6. Generator and WAST arbitrary coverage should not be conflated. `gen_valid` already has three SIMD feature rows, while WAST arbitrary currently proves only representative syntax unless future tests widen it deliberately.
