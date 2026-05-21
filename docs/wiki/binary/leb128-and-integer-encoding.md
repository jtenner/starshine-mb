---
kind: concept
status: supported
last_reviewed: 2026-05-20
sources:
  - ../raw/wasm/2026-05-20-leb128-binary-integer-encoding-refresh.md
  - ../raw/wasm/2026-05-13-instruction-expression-encoding-sources.md
  - ../raw/wasm/2026-05-13-instruction-expression-binary-sources.md
  - ../../../src/binary/decode.mbt
  - ../../../src/binary/encode.mbt
  - ../../../src/binary/tests.mbt
  - ../../../src/fuzz/invalid_binary.mbt
  - ../../../src/wast/spec_harness.mbt
  - ../../../tests/spec/binary-leb128.wast
related:
  - module-section-map.md
  - instruction-and-expression-encoding.md
  - data-element-and-datacount-sections.md
  - function-import-export-and-code-sections.md
  - type-table-memory-global-tag-sections.md
  - ../validate/fuzz-hardening.md
  - ../wast/static-assertion-harness.md
  - ../binaryen/passes/const-hoisting/index.md
  - ../binaryen/passes/reorder-globals/index.md
---

# LEB128 And Binary Integer Encoding

## Overview

WebAssembly binary modules use **LEB128** for most integers that are not fixed-size floating-point or vector payloads. LEB128 is a variable-length byte encoding: small values usually take one byte, while larger values take more continuation bytes. In Starshine, this matters for both correctness and size-sensitive optimization:

- section payload lengths, vector lengths, indices, memory offsets, and integer constants are LEB-encoded byte-layer facts;
- `f32`, `f64`, and `v128` payloads are fixed-width little-endian byte sequences and are not LEB-encoded;
- a decoded LEB value can still be semantically invalid later, but malformed LEB bytes must be rejected before validation.

The 2026-05-20 source refresh in [`../raw/wasm/2026-05-20-leb128-binary-integer-encoding-refresh.md`](../raw/wasm/2026-05-20-leb128-binary-integer-encoding-refresh.md) rechecked the current official WebAssembly binary values/conventions pages, the upstream `binary-leb128.wast` fixture, and Starshine's binary codec, tests, fuzzing, and static harness evidence.

## The Most Important Rule: Bounded Does Not Mean Shortest

A beginner-friendly mental model is:

```text
payload bits per byte: 7
high bit per byte:     continuation flag
maximum bytes:         ceil(bit_width / 7)
```

For example, `u32`, `s32`, and the signed-33-bit type-index form all fit in at most five bytes; `u64` and `s64` fit in at most ten bytes. Starshine names those local constants in [`src/binary/encode.mbt`](../../../src/binary/encode.mbt): `MAX_LEB128_BYTES_32`, `MAX_LEB128_BYTES_33`, and `MAX_LEB128_BYTES_64`, with coverage in `src/binary/tests.mbt`.

The subtle part is that WebAssembly does **not** require the shortest possible encoding. Starshine deliberately accepts overlong-but-bounded forms such as:

```text
value 3 as u8-like unsigned LEB:
  canonical-looking:  0x03
  overlong but valid: 0x83 0x00
```

That is why tests such as `uleb allows trailing zeros within bound` and `sleb allows extra sign extension within bound` exist in [`src/binary/tests.mbt`](../../../src/binary/tests.mbt). A decoder that rejects all non-minimal LEBs would be too strict for the official binary convention and would break the committed [`tests/spec/binary-leb128.wast`](../../../tests/spec/binary-leb128.wast) evidence lane.

## Starshine Decode Contract

[`decode_unsigned(...)`](../../../src/binary/decode.mbt) and [`decode_signed(...)`](../../../src/binary/decode.mbt) are the byte-layer owners. They reject malformed encodings before a module reaches validation.

| Failure family | Unsigned error | Signed error | Meaning |
| --- | --- | --- | --- |
| Bad helper width | `InvalidUnsignedLebBitWidth` | `InvalidSignedLebBitWidth` | Internal caller asked for `nbits <= 0` or `nbits > 64`. |
| Unterminated bytes | `UnexpectedEofInUnsignedLeb` | `UnexpectedEofInSignedLeb` | A continuation bit was set but the byte stream ended. |
| Too many bytes | `UnsignedLebTooManyBytes` | `SignedLebTooManyBytes` | Encoding exceeded `ceil(nbits / 7)` bytes. |
| Value out of range | `UnsignedLebOutOfRangeForBitWidth` | `SignedLebOutOfRangeForBitWidth` | Decoded value does not fit the requested width. |
| Terminal unused bits | `UnsignedLebTerminalHasNonZeroUnusedBits` | `SignedLebPositiveTerminalHasNonZeroUnusedBits` / `SignedLebTerminalHasWrongSignExtensionBits` | At the maximum byte count, payload bits outside the declared width are not legal zero/sign-extension bits. |

Two advanced details prevent common mistakes:

1. **Unused-bit checks are terminal-byte checks at the maximum width.** A shorter overlong encoding can still be valid when its decoded value fits the width.
2. **Signed terminal bits must match the sign.** Positive signed values need zero unused bits; negative signed values need sign-extension bits.

## Starshine Encode And Size Contract

[`encode_unsigned(...)`](../../../src/binary/encode.mbt) and [`encode_signed(...)`](../../../src/binary/encode.mbt) write bounded, valid encodings. [`size_unsigned(...)`](../../../src/binary/encode.mbt) and [`size_signed(...)`](../../../src/binary/encode.mbt) compute the corresponding byte counts and are the right model for future size-sensitive pass work.

The encoder should normally produce a compact form, but the decoder must remain more permissive than the encoder. That asymmetry is intentional:

- **encoder output** can be deterministic and compact;
- **decoder input** must accept every official-compatible bounded encoding;
- **validator logic** should only see decoded values, not byte spelling choices.

This split matters for pass docs that mention LEB size. For example, [`const-hoisting`](../binaryen/passes/const-hoisting/index.md) profitability depends on signed integer literal byte width, while [`reorder-globals`](../binaryen/passes/reorder-globals/index.md) depends on unsigned index byte width. Those passes should use or mirror the real binary helpers instead of approximating with rough value ranges.

## Where LEB Shows Up

| Binary field | Encoding family | Main Starshine owner | Notes |
| --- | --- | --- | --- |
| Section payload length | `u32`-style unsigned LEB | [`decode_module_with_detail(...)`](../../../src/binary/decode.mbt), [`write_section(...)`](../../../src/binary/encode.mbt) | Corruptions here are covered by the invalid-binary `malformed-section-size-uleb` strategy. |
| Vector lengths | unsigned LEB | Binary `Decode` / `Encode` impls | Used for type vectors, imports, functions, locals, element/data payloads, and many name/custom maps. The invalid-binary lane now includes `malformed-custom-section-name-length-uleb` and `malformed-name-subsection-size-uleb` for custom/name-section length carriers. |
| Indices | unsigned LEB | Section and instruction codecs | Includes `TypeIdx`, `FuncIdx`, `TableIdx`, `MemIdx`, `GlobalIdx`, `TagIdx`, `ElemIdx`, `DataIdx`, `LocalIdx`, and label depths. The invalid-binary lane now includes `malformed-local-index-uleb`, `malformed-local-set-index-uleb`, `malformed-local-tee-index-uleb`, `malformed-global-index-uleb`, `malformed-global-set-index-uleb`, `malformed-call-func-index-uleb`, `malformed-return-call-func-index-uleb`, `malformed-ref-func-index-uleb`, `malformed-call-indirect-type-index-uleb`, `malformed-call-indirect-table-index-uleb`, `malformed-return-call-indirect-type-index-uleb`, `malformed-return-call-indirect-table-index-uleb`, `malformed-call-ref-type-index-uleb`, `malformed-return-call-ref-type-index-uleb`, `malformed-throw-tag-index-uleb`, `malformed-try-table-catch-count-uleb`, `malformed-try-table-catch-tag-index-uleb`, `malformed-try-table-catch-label-index-uleb`, `malformed-struct-new-type-index-uleb`, `malformed-struct-get-field-index-uleb`, `malformed-array-new-data-type-index-uleb`, `malformed-array-new-data-index-uleb`, `malformed-br-label-index-uleb`, `malformed-br-if-label-index-uleb`, `malformed-br-table-target-count-uleb`, `malformed-br-table-target-label-index-uleb`, `malformed-br-table-default-label-index-uleb`, `malformed-table-index-uleb`, `malformed-table-set-index-uleb`, `malformed-table-size-index-uleb`, `malformed-table-grow-index-uleb`, `malformed-table-fill-index-uleb`, `malformed-memory-size-memory-index-uleb`, `malformed-memory-grow-memory-index-uleb`, `malformed-memory-copy-dst-index-uleb`, `malformed-memory-copy-src-index-uleb`, `malformed-table-copy-dst-index-uleb`, `malformed-table-copy-src-index-uleb`, `malformed-data-index-uleb`, `malformed-memory-init-data-index-uleb`, `malformed-memory-init-memory-index-uleb`, `malformed-elem-index-uleb`, `malformed-table-init-elem-index-uleb`, and `malformed-table-init-table-index-uleb` as instruction-immediate index/count carriers; `malformed-data-segment-memory-index-uleb` and `malformed-element-segment-table-index-uleb` as active segment descriptor resource-index carriers; `malformed-export-func-index-uleb`, `malformed-export-table-index-uleb`, `malformed-export-memory-index-uleb`, `malformed-export-global-index-uleb`, and `malformed-export-tag-index-uleb` as export descriptor index carriers; `malformed-function-section-type-index-uleb` as a function-section type-index carrier; `malformed-import-func-type-index-uleb` and `malformed-import-tag-type-index-uleb` as import descriptor type-index carriers; plus `malformed-tag-type-index-uleb` as a section-entry index carrier; `malformed-select-type-count-uleb` covers a typed-select immediate vector count. |
| `i32.const` / `i64.const` | signed LEB | [`Decode for I32/I64`](../../../src/binary/decode.mbt), [`Encode for I32/I64`](../../../src/binary/encode.mbt) | Numeric rewrite passes must preserve value semantics and account for signed-LEB size when size is the goal. The invalid-binary lane now includes `malformed-i32-const-sleb` and `malformed-i64-const-sleb` as signed instruction-immediate carriers. |
| Block type type indices | signed 33-bit LEB | [`Decode for S33`](../../../src/binary/decode.mbt), [`Encode for S33`](../../../src/binary/encode.mbt), [`Decode for BlockType`](../../../src/binary/decode.mbt) | Starshine decodes the nonnegative type-index subset into `TypeIdx`; value-type and void blocktypes are handled by their special byte forms first. |
| Limits minimum sizes | unsigned LEB | Table and memory section codecs | The invalid-binary lane covers malformed memory/table minimum-size fields with `malformed-memory-min-uleb` and `malformed-table-min-uleb`, separate from invalid limits flag bytes. |
| Memory alignment immediates | unsigned LEB | [`MemArg`](../../../src/lib/types.mbt), binary memarg codec | The invalid-binary lane keeps the legacy `malformed-memarg-immediate` carrier and now also names load/store alignment carriers explicitly with `malformed-load-memarg-align-uleb` and `malformed-store-memarg-align-uleb`. |
| Memory offset immediates | unsigned LEB width through `U64` | [`MemArg`](../../../src/lib/types.mbt), binary memarg codec | Semantic legality still depends on selected memory width and lives in validation / WAST memory-argument docs. The invalid-binary lane covers malformed load and store offset ULEBs with `malformed-load-memarg-offset-uleb` and `malformed-store-memarg-offset-uleb`, separate from memarg alignment carriers. |

Section placement and index-space repair guidance lives in [`module-section-map.md`](module-section-map.md). Instruction opcode and stack-validation guidance lives in [`instruction-and-expression-encoding.md`](instruction-and-expression-encoding.md).

## Concrete Examples

### Valid overlong unsigned encoding

```text
bytes: 0x83 0x00
meaning: unsigned value 3
why valid: continuation from first byte, terminal payload 0, total byte count still within width bound
```

Starshine locks this with a `decode_unsigned(b"\x83\x00", 0, 8)` test.

### Invalid unterminated encoding

```text
bytes: 0x80
meaning: no terminal byte
why invalid: continuation is set, but the byte stream ends
```

Starshine reports `UnexpectedEofInUnsignedLeb` or `UnexpectedEofInSignedLeb` depending on the helper.

### Invalid too-wide section size

```text
section id:   0x01
payload size: 0x80 0x80 0x80 0x80 0x80
```

A section payload length cannot run forever. The invalid-binary fuzzer's `malformed-section-size-uleb` strategy writes this kind of corrupt payload-size field in [`src/fuzz/invalid_binary.mbt`](../../../src/fuzz/invalid_binary.mbt), while section-payload strategies such as `malformed-start-func-index-uleb`, `malformed-datacount-uleb`, `malformed-code-body-size-uleb`, `malformed-code-local-decl-count-uleb`, and `malformed-code-local-run-count-uleb` keep the section size well-formed and corrupt an unsigned LEB inside the payload. The same invalid-binary matrix also covers well-formed but too-small declared sizes with `type-section-size-underflow`, `function-section-size-underflow`, `import-section-size-underflow`, `export-section-size-underflow`, `table-section-size-underflow`, `memory-section-size-underflow`, `global-section-size-underflow`, `element-section-size-underflow`, `data-section-size-underflow`, `tag-section-size-underflow`, `start-section-size-underflow`, `datacount-section-size-underflow`, and `code-body-size-underflow`, which end the declared payload/body before the enclosed type, function type index, import/export descriptor, table or memory limit, global initializer, segment descriptor, tag type index, start function index, data segment count, or expression can be decoded. It also covers too-large but well-formed declared sizes with `type-section-size-overflow`, `code-section-size-overflow`, `function-section-size-overflow`, `import-section-size-overflow`, `export-section-size-overflow`, `table-section-size-overflow`, `memory-section-size-overflow`, `global-section-size-overflow`, `element-section-size-overflow`, `data-section-size-overflow`, `tag-section-size-overflow`, `start-section-size-overflow`, and `datacount-section-size-overflow`, where the payload frame extends beyond the bytes available for the section. Focused tests in [`src/fuzz/invalid_binary_wbtest.mbt`](../../../src/fuzz/invalid_binary_wbtest.mbt) expect decode-stage rejection for these malformed carriers.

### Signed 33-bit blocktype boundary

Blocktype type indices use a signed-33-bit LEB form so the same syntactic slot can distinguish special negative value-type bytes from nonnegative type indices. Starshine models the decoded nonnegative subset as [`S33(UInt)`](../../../src/lib/types.mbt), then turns that into `TypeIdx` in [`Decode for BlockType`](../../../src/binary/decode.mbt). Encoding rejects recursive-index blocktypes because stable binary output must use absolute type indices.

## Validation And Fuzzing Guidance

When touching LEB or integer-immediate code:

1. Add binary codec tests in [`src/binary/tests.mbt`](../../../src/binary/tests.mbt) for both minimal and valid overlong encodings.
2. Add negative tests for EOF, too many bytes, out-of-range values, and terminal unused/sign-extension bits.
3. If the mutation is a module-level corruption, add or refresh invalid-binary strategy coverage in [`src/fuzz/invalid_binary.mbt`](../../../src/fuzz/invalid_binary.mbt) and the strategy registry/floor tests in [`src/fuzz/invalid_binary_wbtest.mbt`](../../../src/fuzz/invalid_binary_wbtest.mbt).
4. If spec-suite behavior changes, run or update the static harness path documented in [`../wast/static-assertion-harness.md`](../wast/static-assertion-harness.md), especially the committed `tests/spec/binary-leb128.wast` fixture.
5. For optimizer profitability changes, prefer exact `size_unsigned(...)` / `size_signed(...)`-style accounting over threshold folklore.

## Edge Cases And Invariants

- **Malformed LEB is not a validation issue.** It is a binary decode issue and should not reach `validate_module(...)`.
- **Valid overlong LEB is not a malformed module.** Preserve this distinction when adding fuzzing or strict-mode tests.
- **Signed and unsigned unused-bit rules differ.** Unsigned needs zero unused bits; signed needs sign extension.
- **Terminal-byte constraints do not imply canonical shortest output.** They prevent values from escaping the declared bit width.
- **Byte-size pass models must use real encoding widths.** LEB boundaries are stepped, not linear; indices below `128` all cost one byte, and larger thresholds jump at powers of `2^7`.
- **S33 is a binary convenience, not a general signed integer API.** In Starshine it is used to carry nonnegative type-index immediates after special blocktype byte forms have been handled.

## Sources

- Source refresh: [`../raw/wasm/2026-05-20-leb128-binary-integer-encoding-refresh.md`](../raw/wasm/2026-05-20-leb128-binary-integer-encoding-refresh.md)
- Earlier instruction-expression snapshots: [`../raw/wasm/2026-05-13-instruction-expression-encoding-sources.md`](../raw/wasm/2026-05-13-instruction-expression-encoding-sources.md), [`../raw/wasm/2026-05-13-instruction-expression-binary-sources.md`](../raw/wasm/2026-05-13-instruction-expression-binary-sources.md)
- Binary codec and tests: [`../../../src/binary/decode.mbt`](../../../src/binary/decode.mbt), [`../../../src/binary/encode.mbt`](../../../src/binary/encode.mbt), [`../../../src/binary/tests.mbt`](../../../src/binary/tests.mbt)
- Invalid binary fuzzing: [`../../../src/fuzz/invalid_binary.mbt`](../../../src/fuzz/invalid_binary.mbt), [`../../../src/fuzz/invalid_binary_wbtest.mbt`](../../../src/fuzz/invalid_binary_wbtest.mbt), [`../validate/fuzz-hardening.md`](../validate/fuzz-hardening.md)
- Spec harness evidence: [`../../../src/wast/spec_harness.mbt`](../../../src/wast/spec_harness.mbt), [`../../../tests/spec/binary-leb128.wast`](../../../tests/spec/binary-leb128.wast), [`../wast/static-assertion-harness.md`](../wast/static-assertion-harness.md)
