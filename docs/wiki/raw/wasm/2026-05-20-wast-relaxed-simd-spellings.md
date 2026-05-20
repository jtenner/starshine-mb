# WAST Relaxed SIMD Spelling And Arity Refresh (2026-05-20)

This source manifest anchors the 2026-05-20 refresh to [`../../wast/simd-authoring.md`](../../wast/simd-authoring.md). It narrows the relaxed-SIMD part of the broader SIMD authoring guide after a current primary-source check and a local code-map check.

## Primary external sources checked

- WebAssembly 3.0 text instruction source, current page dated 2026-05-14 and checked on 2026-05-20: <https://webassembly.github.io/spec/core/text/instructions.html>. It keeps relaxed SIMD as ordinary vector instruction text inside the instruction grammar rather than a module declaration or custom-section surface.
- WebAssembly 3.0 binary instruction source, current page dated 2026-05-14 and checked on 2026-05-20: <https://webassembly.github.io/spec/core/binary/instructions.html>. It keeps vector instructions under the `0xFD` SIMD prefix and includes the relaxed-SIMD subopcode range used by Starshine's binary codec.
- WebAssembly 3.0 validation instruction source, current page dated 2026-05-14 and checked on 2026-05-20: <https://webassembly.github.io/spec/core/valid/instructions.html>. It validates vector instructions through ordinary stack typing; there is no separate relaxed-SIMD declaration phase.
- WebAssembly relaxed-SIMD proposal overview, checked on 2026-05-20: <https://github.com/WebAssembly/relaxed-simd/blob/main/proposals/relaxed-simd/Overview.md>. It is still the clearest primary-source rationale for relaxed operations: host-dependent / implementation-defined choices, unary relaxed truncation, binary relaxed swizzle/min/max/q15/dot families, ternary FMA/lane-select/dot-add families, and the dot-product names without Starshine's current `relaxed_dot` text prefix.

## Starshine repository evidence checked

- [`src/wast/keywords.mbt`](../../../../src/wast/keywords.mbt) recognizes current Starshine WAST relaxed-SIMD spellings: unary truncations, binary swizzle/min/max/q15/dot, ternary FMA/lane-select/dot-add, and the local `i16x8.relaxed_dot_i8x16_i7x16_s` / `i32x4.relaxed_dot_i8x16_i7x16_add_s` dot spellings.
- [`src/wast/parser.mbt`](../../../../src/wast/parser.mbt) classifies relaxed FMA and lane-select forms as `SimdTernary`; classifies relaxed truncation, swizzle, min/max, q15, and dot forms as `SimdRelaxed`; and routes those no-immediate relaxed forms through ordinary expression parsing.
- [`src/wast/lower_to_lib.mbt`](../../../../src/wast/lower_to_lib.mbt) lowers every current WAST relaxed-SIMD opcode to a corresponding `@lib.Instruction` and has a focused `wast_to_binary_module lowers relaxed SIMD no-immediate ops` test covering all 20 local relaxed opcodes.
- [`src/validate/typecheck.mbt`](../../../../src/validate/typecheck.mbt) stack-types relaxed operations by arity: unary truncations as `v128 -> v128`, binary swizzle/min/max/q15/dot as `v128, v128 -> v128`, and ternary FMA/lane-select/dot-add as `v128, v128, v128 -> v128`.
- [`src/binary/encode.mbt`](../../../../src/binary/encode.mbt) and [`src/binary/decode.mbt`](../../../../src/binary/decode.mbt) map relaxed-SIMD variants to SIMD subopcodes `256..275` under the `0xFD` prefix.
- [`src/lib/types.mbt`](../../../../src/lib/types.mbt) and [`src/ir/hot_lift.mbt`](../../../../src/ir/hot_lift.mbt) carry relaxed-SIMD operations as ordinary instruction variants / HOT SIMD payloads; there is still no dedicated local `remove-relaxed-simd` optimizer pass.

## Reconciled takeaways

- Relaxed SIMD authoring is not a feature-section or declaration task in Starshine WAST. It is ordinary instruction authoring plus ordinary stack typing.
- The high-risk fixture mistake is arity: FMA, lane-select, and dot-add are ternary; relaxed truncations are unary; relaxed swizzle, min/max, q15, and the two-input dot product are binary.
- Current Starshine WAST uses `relaxed_dot` text spellings for the dot-product pair. The relaxed-SIMD proposal overview and Binaryen lit/source notes use dot-product spellings without that text prefix. Keep this as a spelling caveat until the local keyword/printer policy is deliberately changed.
- `remove-relaxed-simd` is an optimizer-pass topic, not an authoring prerequisite. Starshine can parse/lower/validate/encode relaxed operations today while still lacking the Binaryen removal pass.
