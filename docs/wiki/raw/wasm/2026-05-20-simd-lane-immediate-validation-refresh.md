---
kind: raw-source-manifest
status: supported
last_reviewed: 2026-05-20
sources:
  - https://webassembly.github.io/spec/core/text/instructions.html
  - https://webassembly.github.io/spec/core/binary/instructions.html
  - https://webassembly.github.io/spec/core/valid/instructions.html
  - ../../../../src/wast/parser.mbt
  - ../../../../src/wast/lower_to_lib.mbt
  - ../../../../src/binary/decode.mbt
  - ../../../../src/binary/encode.mbt
  - ../../../../src/validate/typecheck.mbt
  - ../../../../src/validate/gen_valid.mbt
related:
  - ../../validate/simd-lane-immediates.md
  - ../../wast/simd-authoring.md
  - ../../binary/instruction-and-expression-encoding.md
  - ../../fuzzing/generator-coverage-ledger.md
---

# SIMD Lane Immediate Validation Refresh - 2026-05-20

This manifest refreshes the lane-index slice of SIMD documentation after a wiki-health scan found that the WAST SIMD guide carried the right caveat, but binary, validation, and generator readers still had to infer the full layer split from that one page.

## Primary sources checked

- WebAssembly Core 3.0 text instructions: vector extract/replace and lane-load/store text forms carry lane immediates in the instruction, while `i8x16.shuffle` carries sixteen lane immediates. URL: <https://webassembly.github.io/spec/core/text/instructions.html>.
- WebAssembly Core 3.0 binary instructions: SIMD uses the `0xFD` prefixed opcode space; `v128.const` carries 16 bytes; shuffle carries sixteen `laneidx` immediates; extract/replace and load-lane/store-lane forms carry one `laneidx` immediate. URL: <https://webassembly.github.io/spec/core/binary/instructions.html>.
- WebAssembly Core 3.0 validation instructions: lane extract/replace validation is shape-specific; the immediate lane index must be below the lane count for the selected vector shape, while stack validation handles the `v128` and scalar operands/results. URL: <https://webassembly.github.io/spec/core/valid/instructions.html>.

## Starshine sources checked

- [`src/wast/parser.mbt`](../../../../src/wast/parser.mbt) parses lane immediates as natural-number tokens and parses the fixed sixteen immediate list for `i8x16.shuffle`.
- [`src/wast/lower_to_lib.mbt`](../../../../src/wast/lower_to_lib.mbt) is the strongest current local lane-bound gate: `wt_shuffle_lane` accepts `0..31`, while `wt_lane_idx` is called with `15`, `7`, `3`, or `1` for shape-specific extract/replace and load-lane/store-lane forms.
- [`src/binary/decode.mbt`](../../../../src/binary/decode.mbt) has two decoder shapes: generic `Decode for LaneIdx` accepts any byte below `16`, while `decode_i8x16_shuffle_lanes` accepts shuffle bytes below `32`.
- [`src/binary/encode.mbt`](../../../../src/binary/encode.mbt) re-emits lane immediates from the already-constructed `LaneIdx` values; it does not prove the immediate is legal for the specific instruction shape.
- [`src/validate/typecheck.mbt`](../../../../src/validate/typecheck.mbt) validates SIMD stack effects, selected memory operands, and lane extract/replace scalar types, but currently treats lane immediates as trusted already-lowered values and does not re-check shape-specific bounds for binary-origin modules.
- [`src/validate/gen_valid.mbt`](../../../../src/validate/gen_valid.mbt) exercises valid SIMD rows `[FZG]014` through `[FZG]016`; those rows are positive-coverage evidence and should not be cited as invalid lane-bound rejection evidence.

## Durable conclusions

1. The official contract is layer-split: binary syntax carries lane immediates as bytes, and validation is what makes a lane immediate legal for a specific SIMD instruction shape.
2. `i8x16.shuffle` is special because each immediate may name a byte lane from either input vector; the valid range is `0..31` for each of the sixteen immediates.
3. Single-lane SIMD forms are shape-specific: i8x16 lanes use `0..15`, i16x8 uses `0..7`, i32x4/f32x4 uses `0..3`, and i64x2/f64x2 uses `0..1`. The lane-load/store variants follow the byte-width lane count: 8-bit lanes use `0..15`, 16-bit lanes `0..7`, 32-bit lanes `0..3`, and 64-bit lanes `0..1`.
4. Starshine WAST-origin modules are currently stricter than binary-origin modules for single-lane bounds because the WAST lowerer checks exact bounds before constructing `Instruction` values.
5. Starshine binary-origin modules can currently decode some officially invalid lane immediates, such as an `i64x2.extract_lane` immediate above `1` but below `16`, and the current typechecker does not repair that gap. Treat that as a validation hardening target, not a WebAssembly semantic difference.
6. Future fixes should add tests at the layer that changes: binary malformed/invalid-byte tests if decode rejects shape-specific lanes, validator invalid-family tests if decode remains permissive but validation rejects, and WAST negative tests only for text-origin regression coverage.
