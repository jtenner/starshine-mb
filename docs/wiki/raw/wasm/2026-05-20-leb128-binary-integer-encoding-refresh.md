# LEB128 Binary Integer Encoding Refresh

- Capture date: 2026-05-20
- Source family: WebAssembly Core binary integer encoding plus current Starshine binary codec/fuzz evidence
- Primary sources:
  - WebAssembly Core Specification 3.0, binary values, checked 2026-05-20: <https://webassembly.github.io/spec/core/binary/values.html>.
  - WebAssembly Core Specification 3.0, binary conventions, checked 2026-05-20: <https://webassembly.github.io/spec/core/binary/conventions.html>.
  - WebAssembly/spec repository `test/core/binary-leb128.wast`, checked 2026-05-20: <https://github.com/WebAssembly/spec/blob/main/test/core/binary-leb128.wast>.
- Repository evidence checked:
  - [`src/binary/decode.mbt`](../../../../src/binary/decode.mbt)
  - [`src/binary/encode.mbt`](../../../../src/binary/encode.mbt)
  - [`src/binary/tests.mbt`](../../../../src/binary/tests.mbt)
  - [`src/fuzz/invalid_binary.mbt`](../../../../src/fuzz/invalid_binary.mbt)
  - [`src/fuzz/invalid_binary_wbtest.mbt`](../../../../src/fuzz/invalid_binary_wbtest.mbt)
  - [`src/wast/spec_harness.mbt`](../../../../src/wast/spec_harness.mbt)
  - [`tests/spec/binary-leb128.wast`](../../../../tests/spec/binary-leb128.wast)
  - [`docs/wiki/binary/instruction-and-expression-encoding.md`](../../binary/instruction-and-expression-encoding.md)
  - [`docs/wiki/binary/module-section-map.md`](../../binary/module-section-map.md)
  - [`docs/wiki/validate/fuzz-hardening.md`](../../validate/fuzz-hardening.md)

## Durable takeaways

- WebAssembly binary integers use LEB128 encodings rather than fixed-width little-endian bytes for indices, lengths, immediates such as `i32.const`, and signed 33-bit block/type-index forms. Fixed-width byte order still applies to `f32`, `f64`, and `v128` payload bytes.
- The official binary convention is bounded but not canonical-minimal: integer encodings may use extra continuation bytes as long as they stay within the maximum byte count for the bit width and obey the unused-bit constraints in the terminal byte.
- Maximum byte counts used by Starshine match the common Wasm widths: `u32` / `s32` / `s33` fit in at most `5` bytes; `u64` / `s64` fit in at most `10` bytes.
- For unsigned encodings at the maximum byte count, terminal payload bits above the declared width must be zero. For signed encodings at the maximum byte count, terminal payload bits above the declared width must be a valid sign extension.
- Starshine intentionally accepts valid overlong-but-bounded encodings, as locked by tests such as `uleb allows trailing zeros within bound` and `sleb allows extra sign extension within bound` in `src/binary/tests.mbt`.
- Starshine rejects malformed integer encodings at decode time before validation: invalid bit widths, EOF while a continuation is pending, too many bytes, out-of-range decoded values, and malformed terminal unused/sign-extension bits each have distinct `BinaryDecodeError` variants.
- The binary invalid-fuzz lane currently has a focused `malformed-section-size-uleb` strategy that corrupts section-size ULEB bytes; broader LEB-specific malformed immediates are still represented mainly by `src/binary/tests.mbt` and the committed upstream `tests/spec/binary-leb128.wast` static harness fixture.

## Starshine implications

- Do not implement a "canonical shortest LEB only" decoder. That would reject official-compatible overlong encodings and break the current `binary-leb128.wast` evidence lane.
- Do not use a hand-written byte-count approximation when pass profitability depends on encoded integer size unless it is tested against the real encode helpers. Existing pass docs for const hoisting and global/type reordering already depend on true LEB size thresholds.
- Section sizes, vector lengths, indices, blocktype type indices, memory offsets, and integer constants are all byte-layer facts. Validation can reject the decoded module later, but validation should not be used to paper over malformed LEB bytes.
- Any future strictness change must name whether it is a decode-policy change, an encoder-output canonicalization change, or a validator/fuzzer expectation change. Those are separate contracts.

## Follow-up questions

- Should binary invalid fuzzing add targeted overlong-but-valid and terminal-unused-bit malformed mutations for index and instruction immediates, not only section sizes?
- Should public helper docs expose `size_unsigned(...)` / `size_signed(...)` as the preferred pass-side byte-cost primitive for future size passes?
- Should `binary-leb128.wast` skip/pass status be surfaced in validation-gate docs when spec-suite summaries start reporting per-file machine-readable results?
