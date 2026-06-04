---
kind: concept
status: supported
last_reviewed: 2026-06-04
sources:
  - ../raw/wasm/2026-06-04-simd-lane-validation-current-refresh.md
  - ../raw/wasm/2026-05-20-simd-lane-immediate-validation-refresh.md
  - ../raw/wasm/2026-05-19-wast-simd-sources.md
  - ../../../src/wast/parser.mbt
  - ../../../src/wast/lower_to_lib.mbt
  - ../../../src/binary/decode.mbt
  - ../../../src/binary/encode.mbt
  - ../../../src/fuzz/invalid_binary.mbt
  - ../../../src/validate/typecheck.mbt
  - ../../../src/validate/gen_valid.mbt
  - ../../../src/validate/invalid_fuzzer.mbt
related:
  - module-validation-phases.md
  - ../wast/simd-authoring.md
  - ../binary/instruction-and-expression-encoding.md
  - ../fuzzing/generator-coverage-ledger.md
---

# SIMD Lane Immediate Validation

## Overview

SIMD lane immediates are the small integer fields that pick one lane out of a `v128`. They appear in three common WebAssembly SIMD families:

- `i8x16.shuffle`, which takes sixteen immediates and selects byte lanes from two input vectors;
- lane extract/replace instructions such as `i16x8.extract_lane_s` and `f64x2.replace_lane`;
- lane load/store instructions such as `v128.load32_lane` and `v128.store64_lane`.

The important maintenance rule is that a lane immediate is **not just a byte**. The byte-level instruction may be syntactically present, but validation must prove that the lane number is legal for the selected instruction shape. The current primary-source and Starshine-code refresh is [`../raw/wasm/2026-06-04-simd-lane-validation-current-refresh.md`](../raw/wasm/2026-06-04-simd-lane-validation-current-refresh.md); it supersedes the older 2026-05-20 local-gap manifest where that manifest says the typechecker did not re-check binary-origin lanes. The broader WAST SIMD authoring guide remains [`../wast/simd-authoring.md`](../wast/simd-authoring.md).

## Official Contract In Plain Terms

A `v128` can be viewed as different lane layouts:

| Shape | Lane count | Valid lane immediates |
| --- | ---: | --- |
| `i8x16` / 8-bit lane memory forms | 16 | `0..15` |
| `i16x8` / 16-bit lane memory forms | 8 | `0..7` |
| `i32x4`, `f32x4` / 32-bit lane memory forms | 4 | `0..3` |
| `i64x2`, `f64x2` / 64-bit lane memory forms | 2 | `0..1` |
| `i8x16.shuffle` | sixteen byte selections from two vectors | each immediate is `0..31` |

`i8x16.shuffle` is the special case. It consumes two `v128` values, and each of its sixteen immediate bytes can select from the first vector (`0..15`) or the second vector (`16..31`). Extract/replace and lane memory forms choose one lane from one vector shape, so their range is the shape-specific lane count.

Validation is still ordinary stack validation around those immediates:

- extract forms consume `v128` and produce the scalar lane type;
- replace forms consume `v128` plus the scalar replacement value and produce `v128`;
- load-lane forms consume an address and an old `v128`, then produce the updated `v128`;
- store-lane forms consume address plus `v128` and store only the selected lane;
- shuffle consumes two `v128` values and produces one `v128`.

## Starshine Layer Split

```text
WAST text lane token
  -> parse_lane_index / parse_shuffle_lanes
  -> wt_lane_idx / wt_shuffle_lane checks exact range
  -> Instruction(... LaneIdx ...)
  -> typecheck stack and memory operands

Binary lane byte
  -> Decode for LaneIdx or decode_i8x16_shuffle_lanes
  -> Instruction(... LaneIdx ...)
  -> typecheck stack and memory operands
```

That split used to create a local caveat where WAST-origin SIMD lanes were stricter than binary-origin SIMD lanes. As of the 2026-05-24 FUZ1020 SIMD lane-index slice, typecheck now enforces shape-specific lane bounds for library/binary-origin instructions too. The 2026-06-04 current refresh rechecked the official WebAssembly Core 3.0 syntax/text/binary/validation pages and confirmed the same layer model: binary carries `laneidx` bytes, while validation imposes the selected shape's lane bound.

| Layer | Current Starshine behavior | Evidence |
| --- | --- | --- |
| WAST parse | Parses natural lane tokens and fixed shuffle lane lists. | [`src/wast/parser.mbt`](../../../src/wast/parser.mbt) |
| WAST lower | Checks `i8x16.shuffle` lanes with `0..31`; checks single-lane forms with exact maxima `15`, `7`, `3`, or `1`. | [`wt_shuffle_lane`](../../../src/wast/lower_to_lib.mbt), [`wt_lane_idx`](../../../src/wast/lower_to_lib.mbt) |
| Binary decode | Generic single-lane decoder accepts any lane byte below `16`; shuffle has a separate below-`32` decoder. Decode-stage invalid-binary fuzz locks the coarse byte-overflow boundary for shuffle plus single-lane extract, replace, load-lane, and store-lane fixtures. Shape-specific single-lane bounds are enforced later by validation. | [`Decode for LaneIdx`](../../../src/binary/decode.mbt), [`decode_i8x16_shuffle_lanes`](../../../src/binary/decode.mbt), [`src/fuzz/invalid_binary.mbt`](../../../src/fuzz/invalid_binary.mbt) |
| Typecheck | Checks stack types, scalar result/value types, selected memory, alignment/address rules, and shape-specific lane bounds for extract, replace, load-lane, and store-lane forms. | [`typecheck_lane_index`](../../../src/validate/typecheck.mbt), [`typecheck_lane_extract`](../../../src/validate/typecheck.mbt), [`typecheck_lane_replace`](../../../src/validate/typecheck.mbt), [`typecheck_v128_load_lane`](../../../src/validate/typecheck.mbt), [`typecheck_v128_store_lane`](../../../src/validate/typecheck.mbt) |
| Valid generator | Emits positive valid SIMD coverage rows; do not treat this as invalid lane-bound rejection proof. | [`src/validate/gen_valid.mbt`](../../../src/validate/gen_valid.mbt), [`../fuzzing/generator-coverage-ledger.md`](../fuzzing/generator-coverage-ledger.md) |

## Concrete Examples

### Valid WAST shape-specific lanes

```wat
(module
  (memory 1)
  (func (param v128 i32)
    local.get 0
    i64x2.extract_lane 1
    drop

    local.get 0
    local.get 1
    i32x4.replace_lane 3
    drop

    i32.const 0
    local.get 0
    v128.load16_lane 7
    drop))
```

The `i64x2` lane `1`, `i32x4` lane `3`, and `v128.load16_lane` lane `7` are at the top of their legal ranges; each produced value is dropped so the void function ends with an empty stack.

### Invalid WAST lanes rejected before typecheck

```wat
(module
  (func (param v128)
    local.get 0
    i64x2.extract_lane 2
    drop))
```

This should fail in WAST lowering because `i64x2` has only lanes `0` and `1`. The same applies to `i32x4.extract_lane 4`, `i16x8.replace_lane 8`, or `v128.store32_lane 4`.

### Binary-origin caveat

A binary payload can encode the same semantic mistake as a raw lane byte. Starshine's generic binary `LaneIdx` decoder still accepts single-lane bytes `0..15` before the instruction-specific typechecker sees the instruction, but typecheck now rejects lane bytes above the selected instruction's legal maximum. A binary-origin `i64x2.extract_lane 15`-style instruction therefore decodes but fails validation with the function-body family.

## Pass, Fuzzer, And Test Guidance

1. **Do not use WAST negative tests as proof of binary validation.** WAST lowering already rejects shape-invalid lanes. Add binary or validator-invalid tests when hardening binary-origin behavior. The current binary-invalid decode fixtures prove coarse byte-overflow rejection; FUZ1020 invalid-AST fixtures now prove shape-specific extract, replace, load-lane, and store-lane bounds reject during validation.
2. **Keep shuffle separate.** `i8x16.shuffle` has sixteen immediates and an upper bound of `31`; ordinary `i8x16.extract_lane_*` has one immediate and an upper bound of `15`.
3. **When mutating SIMD instructions, preserve the shape-lane relation.** A pass that changes `i32x4.extract_lane 3` into `i64x2.extract_lane 3` creates an invalid module even though the lane byte still decodes.
4. **For memory-lane instructions, validate both lane and memory facts.** The lane bound depends on load/store lane width; the address stack type, memory existence, alignment, offset width, and memory64 caveats are shared with [`../wast/memory-argument-authoring.md`](../wast/memory-argument-authoring.md).
5. **Generator signoff is positive coverage.** `[FZG]014` through `[FZG]016` prove valid SIMD surfaces. Invalid lane-bound rejection belongs in invalid-AST, invalid-binary, or focused validator tests, not in the valid generator floor.

## Current Gaps And Follow-Ups

- Starshine WAST-origin lane bounds match the official lane-count model for the covered text shapes.
- Starshine binary-origin single-lane bounds now reject at validation time through instruction-specific typecheck. Keep binary-invalid decode fixtures scoped to coarse malformed lane bytes unless decode itself becomes shape-specific.
- If decode becomes shape-specific later, update binary-invalid fuzz strategy expectations so users know bad shape-specific lane bytes fail at decode rather than validation stage.

## Sources

- Current SIMD lane refresh manifest: [`../raw/wasm/2026-06-04-simd-lane-validation-current-refresh.md`](../raw/wasm/2026-06-04-simd-lane-validation-current-refresh.md)
- Original SIMD lane refresh manifest: [`../raw/wasm/2026-05-20-simd-lane-immediate-validation-refresh.md`](../raw/wasm/2026-05-20-simd-lane-immediate-validation-refresh.md)
- Broad WAST SIMD manifest: [`../raw/wasm/2026-05-19-wast-simd-sources.md`](../raw/wasm/2026-05-19-wast-simd-sources.md)
- Official WebAssembly instruction sources: <https://webassembly.github.io/spec/core/text/instructions.html>, <https://webassembly.github.io/spec/core/binary/instructions.html>, <https://webassembly.github.io/spec/core/valid/instructions.html>
- Starshine WAST implementation: [`../../../src/wast/parser.mbt`](../../../src/wast/parser.mbt), [`../../../src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt)
- Starshine binary implementation: [`../../../src/binary/decode.mbt`](../../../src/binary/decode.mbt), [`../../../src/binary/encode.mbt`](../../../src/binary/encode.mbt)
- Starshine validation and generator implementation: [`../../../src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt), [`../../../src/validate/gen_valid.mbt`](../../../src/validate/gen_valid.mbt)
