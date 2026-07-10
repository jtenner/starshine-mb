---
kind: raw-source
status: current
last_reviewed: 2026-07-10
sources:
  - https://webassembly.github.io/spec/core/binary/values.html
  - https://webassembly.github.io/spec/core/binary/conventions.html
  - https://github.com/WebAssembly/spec/blob/main/test/core/binary-leb128.wast
  - ../../../../src/binary/decode.mbt
  - ../../../../src/binary/encode.mbt
  - ../../../../src/binary/tests.mbt
  - ../../../../src/fuzz/invalid_binary.mbt
  - ../../../../src/fuzz/invalid_binary_wbtest.mbt
  - ../../../../src/cmd/fuzz_harness.mbt
related:
  - ../../binary/leb128-and-integer-encoding.md
  - ../../binary/instruction-and-expression-encoding.md
  - ../../validate/fuzz-hardening.md
---

# LEB128 Core 3.0 Recheck (2026-07-10)

## Capture

Checked the current official WebAssembly Core 3.0 binary-value and binary-convention pages, the upstream `binary-leb128.wast` conformance fixture, and the current Starshine codec, tests, invalid-binary registry, and canonicality classifier.

## Current primary-source facts

- The official **Values** page is part of *WebAssembly 3.0 (2026-07-10)*. It defines all integer encodings as signed or unsigned LEB128 and bounds each `uN` / `sN` representation to `ceil(N / 7)` bytes.
- The same page explicitly permits non-shortest encodings inside that bound: `0x03` and `0x83 0x00` both encode `u8` value `3`. At the maximum length, unused terminal payload bits must be zero for nonnegative values and one for negative values.
- The official **Conventions** page separately says implementations of decoders must support all valid alternative encodings, while encoders may choose any allowed form.
- The upstream `test/core/binary-leb128.wast` still carries nonminimal unsigned/signed positives across section sizes, vector counts, indices, and integer constants, followed by malformed over-limit cases. It is conformance evidence for the byte contract, not an encoder-output policy.

## Starshine reconciliation

- `src/binary/decode.mbt` implements the spec split: byte-count limits, EOF and range checks, and max-width terminal unused-bit/sign-extension checks in `decode_unsigned(...)` and `decode_signed(...)`; `Decode for S33` then additionally narrows the signed result to a nonnegative `u32` type-index carrier.
- `src/binary/encode.mbt` and `size_unsigned(...)` / `size_signed(...)` choose compact valid forms and enforce the same declared width range. Compact output is a local deterministic-output policy, not a condition imposed on input bytes.
- `src/binary/tests.mbt` locks compact encoder examples, accepted bounded overlong unsigned/signed examples, S33 boundaries, and malformed terminal/over-limit cases. The checked-in upstream `tests/spec/binary-leb128.wast` gives the spec-suite lane.
- `src/fuzz/invalid_binary.mbt` and `src/fuzz/invalid_binary_wbtest.mbt` are the exhaustive local inventory for malformed/overwide LEB carriers. Do not duplicate their growing strategy-id list in a living overview page.
- `src/cmd/fuzz_harness.mbt` deliberately classifies an external disagreement on a known accepted-noncanonical input as `ExternalPolicyDisagreement`; canonical or malformed disagreements remain `DecoderBugDisagreement` candidates.

## No upstream contradiction found

This recheck confirms, rather than supersedes, the 2026-06-04 refresh. The difference is source currency: the official pages now explicitly identify WebAssembly 3.0 dated July 10, 2026. Historical source captures remain useful provenance; the living page is the current explanation.
