---
kind: raw-source
status: current
last_reviewed: 2026-06-04
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

# LEB128 Current Refresh (2026-06-04)

## Why this note exists

The older 2026-05-20 LEB128 refresh captured the core WebAssembly rule correctly, but it predated most of Starshine's later invalid-binary LEB carrier widening and the command-harness canonicality classifier. This note keeps the living LEB128 page source-current without replacing the older source snapshot, which remains useful history for the initial policy decision.

## Sources checked

Checked on 2026-06-04:

- Current WebAssembly Core binary values and conventions pages.
- Current upstream `test/core/binary-leb128.wast` in the official WebAssembly/spec repository.
- Starshine `src/binary/decode.mbt`, `src/binary/encode.mbt`, and `src/binary/tests.mbt` LEB decode/encode/size helpers and boundary tests.
- Starshine invalid-binary strategy registry and white-box tests in `src/fuzz/invalid_binary.mbt` and `src/fuzz/invalid_binary_wbtest.mbt`.
- Starshine command-harness binary canonicality classification helpers in `src/cmd/fuzz_harness.mbt`.

## Durable takeaways

- The official rule remains unchanged for Starshine purposes: LEB128 encodings are bounded by the declared bit width and terminal unused-bit/sign-extension constraints, but they are not required to be shortest-form encodings.
- Starshine's core policy remains a deliberate asymmetric split: decoders accept official-compatible bounded overlong encodings, encoders emit deterministic compact encodings, and malformed byte-layer failures are rejected before validation.
- The live invalid-binary lane is now much broader than the 2026-05-20 note described. It covers malformed and overwide LEB carriers across section sizes, section/vector counts, function/code body sizes, custom/name string lengths and name-map counts, resource limits, import/export descriptors, code locals, instruction indices, blocktypes and heaptypes, prefixed subopcodes, memargs, SIMD/atomic operand-context memargs, data/element carriers, and integer constants.
- `src/cmd/fuzz_harness.mbt` now has a policy-facing canonicality classifier: accepted noncanonical input plus external strict-tool rejection is an `ExternalPolicyDisagreement`, while disagreements on canonical or malformed inputs are possible decoder-bug signals. This vocabulary prevents official-compatible overlong input from being misfiled as a generic decoder defect.
- The living page should keep carrier-map lists readable enough for maintainers, but the authoritative exhaustive strategy inventory is the registry and white-box strategy tests, not prose alone.

## Starshine implications

1. Do not narrow `decode_unsigned(...)` or `decode_signed(...)` to canonical-shortest encodings without a deliberate spec-compatibility policy change.
2. Do not cite the encoder's compact output as evidence that the decoder may reject bounded overlong input.
3. When adding a malformed-byte strategy, classify whether it corrupts a LEB carrier, a fixed-width immediate, a UTF-8/name byte sequence, an opcode/subopcode byte, a section frame, or a validation-stage semantic condition.
4. When comparing against external validators, route bounded-overlong disagreements through binary canonicality policy rather than validator semantic parity.
5. Size-sensitive passes should use the real `size_unsigned(...)` / `size_signed(...)` helpers or test against equivalent threshold tables.

## Links checked

- Core binary values: <https://webassembly.github.io/spec/core/binary/values.html>
- Core binary conventions: <https://webassembly.github.io/spec/core/binary/conventions.html>
- Official LEB128 conformance fixture: <https://github.com/WebAssembly/spec/blob/main/test/core/binary-leb128.wast>
