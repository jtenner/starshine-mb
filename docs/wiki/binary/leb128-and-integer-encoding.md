---
kind: concept
status: supported
last_reviewed: 2026-07-10
sources:
  - ../raw/wasm/2026-07-10-leb128-core3-recheck.md
  - ../raw/wasm/2026-06-04-leb128-current-refresh.md
  - ../../../src/binary/decode.mbt
  - ../../../src/binary/encode.mbt
  - ../../../src/binary/tests.mbt
  - ../../../src/fuzz/invalid_binary.mbt
  - ../../../src/fuzz/invalid_binary_wbtest.mbt
  - ../../../src/cmd/fuzz_harness.mbt
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

Most WebAssembly binary integers are **LEB128**: a sequence of 7-bit payload groups whose high bit says whether another byte follows. This affects decoding, malformed-input handling, and optimizer byte-cost estimates. It does **not** apply to `f32`, `f64`, or `v128` payloads, which are fixed-width little-endian bytes.

The current official Core 3.0 sources permit **bounded nonminimal** LEB encodings. Therefore Starshine intentionally has two different policies:

| Direction | Rule |
| --- | --- |
| Decode input | Accept every well-formed encoding that fits the declared bit width, including bounded overlong forms. Reject malformed bytes before module validation. |
| Encode output | Emit compact deterministic encodings. |
| Size accounting | Use the compact encoded length, not an arbitrary accepted input spelling. |

The evidence and current-source recheck are in [`../raw/wasm/2026-07-10-leb128-core3-recheck.md`](../raw/wasm/2026-07-10-leb128-core3-recheck.md). The older [`2026-06-04 refresh`](../raw/wasm/2026-06-04-leb128-current-refresh.md) remains provenance for the earlier fuzzing/canonicality work.

## The rule that prevents a common bug

For an `N`-bit integer, at most `ceil(N / 7)` LEB bytes are valid. That is a **maximum**, not a shortest-form requirement.

```text
u8 value 3
  compact:  03
  valid nonminimal form: 83 00
  invalid:  83 80 00       ; three bytes exceeds the u8 bound
```

At the maximum byte count, unused bits in the last 7-bit payload are constrained:

- unsigned values require zero unused bits;
- nonnegative signed values require zero unused bits;
- negative signed values require one/sign-extension unused bits.

These constraints keep a representation inside its declared width. They do not make every shorter encoding canonical or reject a valid shorter overlong encoding.

## Width and value families

| Binary family | Width / form | Typical uses | Starshine owner |
| --- | --- | --- | --- |
| `u32` | unsigned, ≤5 bytes | section sizes, vector lengths, most indices, prefixed subopcodes | [`decode_unsigned(...)`](../../../src/binary/decode.mbt), [`encode_unsigned(...)`](../../../src/binary/encode.mbt) |
| `s32` | signed, ≤5 bytes | `i32.const` | [`Decode for I32`](../../../src/binary/decode.mbt), [`Encode for I32`](../../../src/binary/encode.mbt) |
| `u64` | unsigned, ≤10 bytes | memory64 offsets and limits where the field selects `u64` | binary `U64` codecs |
| `s64` | signed, ≤10 bytes | `i64.const` | binary `I64` codecs |
| `s33` | signed, ≤5 bytes, then narrowed to a nonnegative `u32` | blocktype type-index form and reference heap-type type indices | [`Decode for S33`](../../../src/binary/decode.mbt), [`Encode for S33`](../../../src/binary/encode.mbt) |

`S33` is a binary syntax helper, not a general signed-integer API. Its signed range lets binary syntax share a slot with negative special encodings; Starshine accepts only the nonnegative `u32` subset when that slot represents a type index.

## Starshine decode contract

[`decode_unsigned(...)`](../../../src/binary/decode.mbt) and [`decode_signed(...)`](../../../src/binary/decode.mbt) own byte-layer LEB validity. Their error families distinguish the reason a module did not decode:

| Failure | Unsigned | Signed | Meaning |
| --- | --- | --- | --- |
| Unsupported helper width | `InvalidUnsignedLebBitWidth` | `InvalidSignedLebBitWidth` | The internal codec was asked for `N <= 0` or `N > 64`. |
| Unterminated continuation | `UnexpectedEofInUnsignedLeb` | `UnexpectedEofInSignedLeb` | Input ended while the continuation bit was set. |
| Too many bytes | `UnsignedLebTooManyBytes` | `SignedLebTooManyBytes` | More than `ceil(N / 7)` bytes appeared. |
| Value outside the width | `UnsignedLebOutOfRangeForBitWidth` | `SignedLebOutOfRangeForBitWidth` | Decoded mathematical value does not fit. |
| Illegal max-width terminal payload | `UnsignedLebTerminalHasNonZeroUnusedBits` | `SignedLebPositiveTerminalHasNonZeroUnusedBits` or `SignedLebTerminalHasWrongSignExtensionBits` | Last-byte unused bits do not meet the unsigned/signed rule. |

A decoder error is **not** a later validation error. `validate_module(...)` should only receive a decoded module. See [`../validate/fuzz-hardening.md`](../validate/fuzz-hardening.md) for the stage-aware invalid-input model.

## Encode and byte-size contract

[`encode_unsigned(...)`](../../../src/binary/encode.mbt) and [`encode_signed(...)`](../../../src/binary/encode.mbt) reject out-of-range values and emit a compact representation. [`size_unsigned(...)`](../../../src/binary/encode.mbt) and [`size_signed(...)`](../../../src/binary/encode.mbt) return the matching compact byte count without allocating output bytes.

This is important for optimizer work:

- an accepted input may spend more bytes than Starshine would emit after decode/re-encode;
- integer LEB size changes in steps at 7-bit boundaries, rather than linearly;
- a pass evaluating literal or index profitability must use the real size helper (or an equivalent tested calculation), not informal thresholds.

The related size models are [`const-hoisting`](../binaryen/passes/const-hoisting/index.md) for signed literal values and [`reorder-globals`](../binaryen/passes/reorder-globals/index.md) for unsigned indices.

## Where LEB appears

The table is intentionally grouped. The exhaustive malformed/overwide strategy inventory belongs in [`src/fuzz/invalid_binary.mbt`](../../../src/fuzz/invalid_binary.mbt) and [`src/fuzz/invalid_binary_wbtest.mbt`](../../../src/fuzz/invalid_binary_wbtest.mbt), not in this living overview.

| Carrier group | Examples | Boundary to remember |
| --- | --- | --- |
| Module framing | section payload sizes; code body sizes | A malformed size LEB is different from a well-formed size that underflows or overflows its declared payload frame. |
| Vectors and names | type/import/export counts; local runs; custom/name-section string lengths and maps | A vector/name LEB failure is decode-stage; UTF-8/name content checks are separate. |
| Indices and depths | type/function/table/memory/global/tag/elem/data/local indices; label depths; `br_table` counts | The LEB only transports the number; index-space existence and label depth are validation concerns. |
| Numeric and type immediates | `i32.const`, `i64.const`, blocktypes, reference heap types | Integer constants use signed LEB; block/reference type-index forms use the special S33 path. |
| Instruction prefixes | `0xFB`, `0xFC`, `0xFD`, `0xFE` subopcodes | A malformed/overwide subopcode LEB differs from an assigned-but-unsupported subopcode. |
| Memory/table fields | limits, memarg alignment/offset, selected memory/table indices | Decode preserves bytes and fields; selected-resource width and alignment legality are validation rules. |

Cross-section placement and index-space obligations are in [`module-section-map.md`](module-section-map.md); instruction-stack semantics are in [`instruction-and-expression-encoding.md`](instruction-and-expression-encoding.md).

## Concrete examples

### Valid nonminimal unsigned value

```text
83 00  ->  3 as an unsigned value
```

The first byte continues and contributes payload `3`; the terminal byte contributes zero. The two-byte form is inside the `u8` two-byte maximum, so it is valid input even though `03` is the compact output.

### Valid nonminimal signed value

```text
ff 7f  ->  -1 as a signed value
```

The second payload carries the required sign-extension bits. Starshine locks bounded nonminimal signed/unsigned forms in [`src/binary/tests.mbt`](../../../src/binary/tests.mbt), and the upstream conformance lane is [`tests/spec/binary-leb128.wast`](../../../tests/spec/binary-leb128.wast).

### Malformed terminal or over-limit value

```text
80                 -> unterminated: continuation byte has no terminal byte
80 80 80 80 80 00  -> too many bytes for a 33-bit LEB
```

Both fail in the decoder before module validation. A max-length terminal byte with invalid unused bits also fails, even when a terminal byte exists.

## External-tool differential guidance

The local binary canonicality classifier in [`src/cmd/fuzz_harness.mbt`](../../../src/cmd/fuzz_harness.mbt) keeps byte-spelling policy separate from decoder correctness:

| Input class and outcome | Classification |
| --- | --- |
| Canonical input accepted as expected | `CanonicalAccepted` |
| Bounded nonminimal input accepted by Starshine | `AcceptedNoncanonical` |
| Malformed input rejected | `MalformedRejected` |
| An external tool disagrees only on an accepted-noncanonical case | `ExternalPolicyDisagreement` |
| An external tool disagrees on canonical or malformed input | `DecoderBugDisagreement` candidate |

Do not call an external strictness difference a Starshine decoder defect merely because it involves an overlong spelling. Conversely, the classifier is not proof that every difference is safe: investigate canonical and malformed disagreements with a reduced byte fixture.

## Maintenance and signoff

When changing LEB code or a field that carries a LEB:

1. Add codec tests for compact output and, where the field allows it, bounded nonminimal input in [`src/binary/tests.mbt`](../../../src/binary/tests.mbt).
2. Add negative coverage for EOF, over-limit byte count, out-of-range values, and maximum-width unused/sign-extension bits.
3. For a module corruption, register the carrier in [`src/fuzz/invalid_binary.mbt`](../../../src/fuzz/invalid_binary.mbt) and lock its inventory/expected decode stage in [`src/fuzz/invalid_binary_wbtest.mbt`](../../../src/fuzz/invalid_binary_wbtest.mbt).
4. If Core conformance behavior changes, exercise the static-harness route for [`tests/spec/binary-leb128.wast`](../../../tests/spec/binary-leb128.wast), described in [`../wast/static-assertion-harness.md`](../wast/static-assertion-harness.md).
5. For a size-sensitive pass, measure with `size_unsigned(...)` or `size_signed(...)`; do not estimate from input spelling.

## Sources

- Current primary-source/local reconciliation: [`../raw/wasm/2026-07-10-leb128-core3-recheck.md`](../raw/wasm/2026-07-10-leb128-core3-recheck.md)
- Earlier source/current-state capture: [`../raw/wasm/2026-06-04-leb128-current-refresh.md`](../raw/wasm/2026-06-04-leb128-current-refresh.md)
- Core codec and tests: [`../../../src/binary/decode.mbt`](../../../src/binary/decode.mbt), [`../../../src/binary/encode.mbt`](../../../src/binary/encode.mbt), [`../../../src/binary/tests.mbt`](../../../src/binary/tests.mbt)
- Fuzz inventory and canonicality classification: [`../../../src/fuzz/invalid_binary.mbt`](../../../src/fuzz/invalid_binary.mbt), [`../../../src/fuzz/invalid_binary_wbtest.mbt`](../../../src/fuzz/invalid_binary_wbtest.mbt), [`../../../src/cmd/fuzz_harness.mbt`](../../../src/cmd/fuzz_harness.mbt)
- Spec-suite evidence: [`../../../tests/spec/binary-leb128.wast`](../../../tests/spec/binary-leb128.wast)
