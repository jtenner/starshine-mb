---
kind: concept
status: supported
last_reviewed: 2026-05-20
sources:
  - ../raw/wasm/2026-05-20-wast-relaxed-simd-spellings.md
  - ../raw/wasm/2026-05-19-wast-simd-sources.md
  - ../../../src/wast/parser.mbt
  - ../../../src/wast/lower_to_lib.mbt
  - ../../../src/wast/module_wast.mbt
  - ../../../src/wast/keywords.mbt
  - ../../../src/wast/arbitrary.mbt
  - ../../../src/lib/types.mbt
  - ../../../src/binary/decode.mbt
  - ../../../src/binary/encode.mbt
  - ../../../src/validate/typecheck.mbt
  - ../../../src/validate/gen_valid.mbt
  - ../../../src/validate/validate.mbt
related:
  - ../binary/instruction-and-expression-encoding.md
  - ../fuzzing/generator-coverage-ledger.md
  - ../fuzzing/wast-arbitrary-parity-plan.md
  - ../tooling/validation-gates.md
  - ../binaryen/passes/remove-relaxed-simd/index.md
  - resource-declaration-authoring.md
  - memory-argument-authoring.md
---

# WAST SIMD Authoring

## Overview

SIMD is WebAssembly's 128-bit vector instruction family. A value of type `v128` can be interpreted as sixteen 8-bit lanes, eight 16-bit lanes, four 32-bit lanes, two 64-bit lanes, or float lane groups depending on the instruction. Starshine stores SIMD instructions in the ordinary `Instruction` enum and validates them through the ordinary function-body stack typechecker; there is no separate module section or declaration that enables SIMD inside WAST fixtures.

Use this page when writing or reviewing WAST fixtures that mention `v128`, `v128.const`, `i8x16.shuffle`, lane extract/replace instructions, vector loads/stores, or relaxed SIMD. The byte-level `0xFD` encoding overview lives in [`../binary/instruction-and-expression-encoding.md`](../binary/instruction-and-expression-encoding.md); this page focuses on text syntax, lowering, validation, and fuzzer coverage.

The current broad source manifest is [`../raw/wasm/2026-05-19-wast-simd-sources.md`](../raw/wasm/2026-05-19-wast-simd-sources.md). The relaxed-SIMD spelling and arity refresh is [`../raw/wasm/2026-05-20-wast-relaxed-simd-spellings.md`](../raw/wasm/2026-05-20-wast-relaxed-simd-spellings.md). Together they check the official WebAssembly 3.0 text, binary, and validation instruction pages, the relaxed-SIMD proposal overview, and Starshine's parser, lowerer, printer, binary codec, typechecker, valid generator, and WAST arbitrary generator.

## Mental Model

```text
WAST text                    Starshine lowering                 Binary / validation
---------                    ------------------                 -------------------
v128.const i32x4 ...   ->    16 canonical bytes           ->    0xFD opcode + 16 bytes, result v128
i8x16.shuffle lanes    ->    16 LaneIdx immediates        ->    lanes 0..31 select from two vectors
lane extract/replace   ->    shape-specific LaneIdx       ->    stack type v128 <-> scalar lane type
v128.load/store        ->    MemArg + vector instruction  ->    memory address type + v128 result/value
relaxed SIMD op        ->    ordinary SIMD Instruction    ->    ordinary stack-typed instruction
```

The important distinction is between **text shapes** and **core bytes**. `v128.const i16x8 0x0102 ...` is a convenient authoring form, but Starshine lowers it to the same 16-byte `Instruction::V128Const` representation used by the binary codec. Passes should not expect the original lane spelling to survive after lowering.

## Authoring Rules And Examples

### `v128.const` lane shapes

Starshine accepts the official lane-shaped text forms:

```wat
(module
  (func (result v128)
    v128.const i8x16 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15)
  (func (result v128)
    v128.const i16x8 1 2 3 4 5 6 7 8)
  (func (result v128)
    v128.const i32x4 1 2 3 4)
  (func (result v128)
    v128.const i64x2 1 2)
  (func (result v128)
    v128.const f32x4 1 2 3 4)
  (func (result v128)
    v128.const f64x2 1 2))
```

The parser chooses the number of following literals from the shape in [`WastParser::parse_v128_const`](../../../src/wast/parser.mbt): `i8x16` needs 16 literals, `i16x8` needs 8, `i32x4` / `f32x4` need 4, and `i64x2` / `f64x2` need 2. The lowerer then serializes each lane into little-endian bytes in [`wt_v128_const_instr`](../../../src/wast/lower_to_lib.mbt).

Practical edge cases:

- Hex integer lanes are preserved as bytes after little-endian lowering. For example, an `i32x4` lane `0x01020304` lowers to bytes `04 03 02 01`.
- Integer lane bounds are checked during WAST lowering: `i8x16` accepts `-128..255`, `i16x8` accepts `-32768..65535`, `i32x4` accepts `-2147483648..4294967295`, and `i64x2` accepts unsigned 64-bit literal width.
- Float lanes accept ordinary float literals and Starshine's NaN payload spelling path. Malformed NaN payloads are rejected before binary encoding.

### Shuffle lanes select from two vectors

`i8x16.shuffle` consumes two `v128` values and takes exactly 16 immediate lane indices:

```wat
(module
  (func (param v128 v128) (result v128)
    local.get 0
    local.get 1
    i8x16.shuffle 0 1 2 3 4 5 6 7 24 25 26 27 28 29 30 31))
```

The valid lane range is `0..31`, not `0..15`: lanes `0..15` select bytes from the first input vector, and lanes `16..31` select bytes from the second. Starshine has this rule in both text lowering (`wt_shuffle_lane`) and binary decode (`decode_i8x16_shuffle_lanes`). A fixture with lane `32` should fail during WAST lowering.

### Extract, replace, and lane memory forms have shape-specific lane bounds

Single-lane instructions use one immediate lane index, but the maximum depends on the lane shape:

| Family | Valid lanes | Example |
| --- | ---: | --- |
| `i8x16.*_lane`, `v128.load8_lane`, `v128.store8_lane` | `0..15` | `i8x16.extract_lane_s 15` |
| `i16x8.*_lane`, `v128.load16_lane`, `v128.store16_lane` | `0..7` | `i16x8.replace_lane 7` |
| `i32x4.*_lane`, `f32x4.*_lane`, `v128.load32_lane`, `v128.store32_lane` | `0..3` | `f32x4.extract_lane 3` |
| `i64x2.*_lane`, `f64x2.*_lane`, `v128.load64_lane`, `v128.store64_lane` | `0..1` | `i64x2.replace_lane 1` |

Starshine parses lane indices as natural-number immediates in [`WastParser::parse_lane_index`](../../../src/wast/parser.mbt) and checks the shape-specific range while lowering in [`wt_lane_idx`](../../../src/wast/lower_to_lib.mbt). The typechecker treats the already-lowered lane index as an immediate and checks only stack types.

Binary-origin fixtures have a sharper caveat: [`Decode for LaneIdx`](../../../src/binary/decode.mbt) currently accepts any single-lane immediate below `16`, while [`decode_i8x16_shuffle_lanes`](../../../src/binary/decode.mbt) has the special shuffle-only `0..31` rule. That means WAST lowering is the stronger local evidence for shape-specific rejection today; a future binary/validation hardening slice should add per-instruction lane-bound tests and reject decoded `i64x2.extract_lane 15`-style inputs during decode or validation.

### Vector memory operations use ordinary `MemArg` rules

Vector load/store instructions are still memory instructions. They carry the same offset, alignment, and optional explicit memory-index model as scalar memory operations:

```wat
(module
  (memory 1)
  (func (param i32 v128)
    local.get 0
    local.get 1
    v128.store offset=16 align=16)
  (func (param i32) (result v128)
    local.get 0
    v128.load offset=16 align=16))
```

The parser routes SIMD memory arguments through the shared memory-argument parser. The typechecker then uses `memarg_check` to choose the selected memory, address type, alignment legality, and offset-width rule. This matters for memory64 and multi-memory fixtures: a syntactically valid SIMD memory op can still be semantically invalid after memory declarations are rewritten. The ordinary WAST memarg contract and the current text-level nonzero-memory-index gap live in [`memory-argument-authoring.md`](memory-argument-authoring.md); `(memory ...)` declaration syntax and the current WAST memory64/shared limitation live in [`resource-declaration-authoring.md`](resource-declaration-authoring.md).

### Relaxed SIMD is ordinary instruction syntax locally

Starshine's WAST keyword table includes relaxed SIMD spellings such as `f32x4.relaxed_madd`, `f64x2.relaxed_madd`, relaxed min/max, relaxed lane select, relaxed truncation, and dot-product forms. They lower to ordinary `Instruction` variants and encode under the SIMD `0xFD` space. They do not require a custom section, feature declaration, or WAST wrapper.

The current relaxed-SIMD source refresh is [`../raw/wasm/2026-05-20-wast-relaxed-simd-spellings.md`](../raw/wasm/2026-05-20-wast-relaxed-simd-spellings.md). It keeps three boundaries explicit:

| Local WAST family | Stack shape | Local examples | Notes |
| --- | --- | --- | --- |
| Unary relaxed truncations | `v128 -> v128` | `i32x4.relaxed_trunc_f32x4_s`, `i32x4.relaxed_trunc_f64x2_u_zero` | The result is still a `v128`, so write a `drop` or consume it in tests. |
| Binary relaxed operations | `v128, v128 -> v128` | `i8x16.relaxed_swizzle`, `f32x4.relaxed_min`, `f64x2.relaxed_max`, `i16x8.relaxed_q15mulr_s`, `i16x8.relaxed_dot_i8x16_i7x16_s` | Starshine's current dot spelling includes `relaxed_dot`; the proposal/Binaryen spelling caveat below matters for oracle fixtures. |
| Ternary relaxed operations | `v128, v128, v128 -> v128` | `f32x4.relaxed_madd`, `f64x2.relaxed_nmadd`, `i8x16.relaxed_laneselect`, `i32x4.relaxed_dot_i8x16_i7x16_add_s` | These are ordinary three-operand vector expressions, not immediates or attributes on an earlier vector op. |

Example fixture shape:

```wat
(module
  (func (param v128 v128 v128)
    local.get 0
    local.get 1
    i8x16.relaxed_swizzle
    drop

    local.get 0
    i32x4.relaxed_trunc_f32x4_s
    drop

    local.get 0
    local.get 1
    local.get 2
    f32x4.relaxed_madd
    drop))
```

Starshine proves this surface in [`src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt) with a focused WAST-to-core lowering test that covers all 20 local relaxed opcodes; [`src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt) then stack-types them through unary, binary, and ternary `v128` helpers. The binary codec maps the same operations to SIMD subopcodes `256..275` under the `0xFD` prefix in [`src/binary/encode.mbt`](../../../src/binary/encode.mbt) and [`src/binary/decode.mbt`](../../../src/binary/decode.mbt).

Spelling caveat: current Starshine WAST accepts the dot-product pair as `i16x8.relaxed_dot_i8x16_i7x16_s` and `i32x4.relaxed_dot_i8x16_i7x16_add_s`. The relaxed-SIMD proposal overview and Binaryen's removal-pass notes use dot-product names without that `relaxed_dot` text prefix. When reducing Binaryen oracle fixtures or official proposal examples, normalize that spelling deliberately and record which surface the fixture is meant to test.

For pass work, keep the split with Binaryen's [`remove-relaxed-simd`](../binaryen/passes/remove-relaxed-simd/index.md) pass clear: authoring a relaxed SIMD instruction is different from implementing the upstream pass that rewrites relaxed instructions into traps or deterministic alternatives.

## Starshine Code Map

| Layer | Files | What to inspect |
| --- | --- | --- |
| WAST keyword recognition | [`src/wast/keywords.mbt`](../../../src/wast/keywords.mbt) | Text opcode strings for SIMD and relaxed SIMD. |
| WAST parsing | [`src/wast/parser.mbt`](../../../src/wast/parser.mbt) | `parse_v128_const`, `parse_simd_shape`, lane parsing, shuffle lanes, and SIMD memargs. |
| WAST lowering | [`src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt) | `wt_v128_const_instr`, `wt_shuffle_lane`, `wt_lane_idx`, SIMD instruction lowering, and focused positive/negative tests. |
| WAST printing | [`src/wast/module_wast.mbt`](../../../src/wast/module_wast.mbt) | `render_v128_const`, shuffle lane rendering, and instruction text output. |
| Core IR | [`src/lib/types.mbt`](../../../src/lib/types.mbt) | `ValType::v128`, `V128Const`, SIMD instruction variants, and `LaneIdx`. |
| Binary codec | [`src/binary/decode.mbt`](../../../src/binary/decode.mbt), [`src/binary/encode.mbt`](../../../src/binary/encode.mbt) | `0xFD` SIMD decode/encode, `v128.const` bytes, shuffle lane decoding, lane immediates, vector memargs, and relaxed SIMD opcodes. |
| Validation | [`src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt) | Stack effects for vector constants, unary/binary/ternary ops, lane extract/replace, memory ops, and relaxed SIMD forms. |
| Fuzz/generator coverage | [`src/validate/gen_valid.mbt`](../../../src/validate/gen_valid.mbt), [`src/validate/validate.mbt`](../../../src/validate/validate.mbt), [`src/wast/arbitrary.mbt`](../../../src/wast/arbitrary.mbt) | `[FZG]014` through `[FZG]016` valid-generator SIMD feature rows plus the narrower WAST arbitrary prelude. |

## Validation And Signoff Guidance

When changing SIMD WAST support:

1. Add or update WAST lowering tests first in [`src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt). Cover both a positive fixture and the nearest malformed lane/literal case.
2. If the change affects binary bytes or opcode coverage, add binary roundtrip coverage in [`src/binary/tests.mbt`](../../../src/binary/tests.mbt) and keep [`../binary/instruction-and-expression-encoding.md`](../binary/instruction-and-expression-encoding.md) aligned.
3. If the change affects stack effects, update [`src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt) tests and the relevant generator counters in [`../fuzzing/generator-coverage-ledger.md`](../fuzzing/generator-coverage-ledger.md).
4. If the change only widens WAST arbitrary text syntax, keep it in [`../fuzzing/wast-arbitrary-parity-plan.md`](../fuzzing/wast-arbitrary-parity-plan.md) as parser/printer coverage rather than claiming typed valid-generator parity.
5. Run the normal validation gate from [`../tooling/validation-gates.md`](../tooling/validation-gates.md). Pass work that changes SIMD rewrites still needs Binaryen oracle comparison where a matching upstream pass exists.

## Current Gaps And Caveats

- WAST arbitrary currently emits a representative `v128.const` in the widened prelude, not the full SIMD text surface. The valid generator has broader `[FZG]014` through `[FZG]016` deterministic SIMD coverage, but that generator matrix is not relaxed-SIMD coverage today.
- Relaxed-SIMD dot-product spellings are intentionally called out because Starshine's WAST keywords currently use `relaxed_dot` while the proposal/Binaryen spelling does not. Treat this as a fixture-porting caveat, not a semantic difference in the lowered instruction.
- Current relaxed-SIMD evidence comes from WAST/core/binary/typechecker paths and Binaryen oracle fixtures, not from `gen_valid`: a whole-wiki health check on 2026-05-20 found no relaxed-SIMD op generation in [`src/validate/gen_valid.mbt`](../../../src/validate/gen_valid.mbt).
- Starshine's core `V128Const` stores bytes, so exact original text shape is not preserved through WAST-to-core lowering.
- WAST lowering checks lane-index shape rules before typechecking. Binary decode currently has only a coarse single-lane `<16` guard plus the shuffle-specific `<32` guard, so binary-origin hardening should add explicit per-instruction lane-bound tests instead of relying on WAST lowering tests.
- **Vector memory instructions inherit all memory-index, memory64, and alignment hazards from the ordinary memory-argument contract.** Use [`memory-argument-authoring.md`](memory-argument-authoring.md) for the shared `offset=` / `align=` / memory-index model rather than duplicating it in SIMD-only docs.

## Sources

- Relaxed-SIMD spelling/arity manifest: [`../raw/wasm/2026-05-20-wast-relaxed-simd-spellings.md`](../raw/wasm/2026-05-20-wast-relaxed-simd-spellings.md)
- Primary-source manifest: [`../raw/wasm/2026-05-19-wast-simd-sources.md`](../raw/wasm/2026-05-19-wast-simd-sources.md)
- Official WebAssembly instruction sources: <https://webassembly.github.io/spec/core/text/instructions.html>, <https://webassembly.github.io/spec/core/binary/instructions.html>, <https://webassembly.github.io/spec/core/valid/instructions.html>
- WebAssembly relaxed-SIMD proposal overview: <https://github.com/WebAssembly/relaxed-simd/blob/main/proposals/relaxed-simd/Overview.md>
- Starshine WAST and binary implementation: [`../../../src/wast/parser.mbt`](../../../src/wast/parser.mbt), [`../../../src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt), [`../../../src/wast/module_wast.mbt`](../../../src/wast/module_wast.mbt), [`../../../src/binary/decode.mbt`](../../../src/binary/decode.mbt), [`../../../src/binary/encode.mbt`](../../../src/binary/encode.mbt)
- Validation and generators: [`../../../src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt), [`../../../src/validate/gen_valid.mbt`](../../../src/validate/gen_valid.mbt), [`../../../src/validate/validate.mbt`](../../../src/validate/validate.mbt), [`../../../src/wast/arbitrary.mbt`](../../../src/wast/arbitrary.mbt)
