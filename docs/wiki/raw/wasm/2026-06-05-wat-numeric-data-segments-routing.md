# WAT Numeric Values In Data Segments Routing (2026-06-05)

- Source family: official WebAssembly active proposal tracker, the `wat-numeric-values` proposal repository, and current Starshine WAST data-segment parser/lowerer code.
- Capture date: 2026-06-05 (local project date).
- Reason for capture: keep WAST data-segment docs from implying that Starshine's current string-only `(data ...)` payload path covers the active `Numeric Values in WAT Data Segments` proposal, while also preserving the deeper fact that Starshine core/binary data segments are byte vectors.
- Status: immutable primary-source bridge. Living routing belongs in [`../../wast/data-segment-authoring.md`](../../wast/data-segment-authoring.md), [`../../wast/text-surface-gap-ledger.md`](../../wast/text-surface-gap-ledger.md), and [`../../wasm-feature-status-and-proposal-boundaries.md`](../../wasm-feature-status-and-proposal-boundaries.md).

## Primary sources checked

1. WebAssembly proposals repository README, active proposals table, checked 2026-06-05: <https://github.com/WebAssembly/proposals>.
2. `WebAssembly/wat-numeric-values` proposal repository README, checked 2026-06-05: <https://github.com/WebAssembly/wat-numeric-values>.
3. Proposal overview, checked 2026-06-05: <https://github.com/WebAssembly/wat-numeric-values/blob/main/proposals/wat-numeric-values/Overview.md>.
4. Current Starshine data parser in [`../../../../src/wast/parser.mbt`](../../../../src/wast/parser.mbt), especially `parse_data(...)` and `parse_data_strings(...)`.
5. Current Starshine WAST lowering in [`../../../../src/wast/lower_to_lib.mbt`](../../../../src/wast/lower_to_lib.mbt) and core data model in [`../../../../src/lib/types.mbt`](../../../../src/lib/types.mbt).

## Current source facts

- The official WebAssembly active proposals README currently lists `Numeric Values in WAT Data Segments` under Phase 2. This is active-proposal routing, not stable Core WebAssembly 3.0 and not local Starshine implementation evidence.
- The proposal README frames the feature as adding numeric forms to WAT data segments.
- The proposal overview's motivation is better human readability and binary diffability for data sections containing structured binary data. Its example transforms an escaped string-byte payload into an explicitly typed sequence such as `(i8 0x01 0x00 0x00 0x00)`, `(i32 1024)`, `(f32 123.5)`, and other numeric groups.
- The proposal overview records little-endian payload encoding for typed numeric groups and explicit static checks for byte ranges, integer ranges, floating-point ranges, group size divisibility, and closed lists. Those rules are proposal-specific and should not be silently inferred from Starshine's current text parser.
- Current Starshine `parse_data(...)` consumes optional data id, optional memory index, optional offset expression, and then only concatenates `Text` tokens through `decode_string(...)`. It does not parse proposal `i8` / `i16` / `i32` / `i64` / `f32` / `f64` / `v128` numeric payload groups in data segments.
- Starshine's core `Data` payload is already bytes, so direct core/binary fixtures can represent the final byte sequence that a numeric WAT data proposal form would lower to. That is byte-vector capability, not source-level numeric data syntax support.

## Starshine interpretation rules

1. Treat numeric data-segment groups as an active Phase-2 proposal text surface. Do not describe them as stable Core 3.0 or current Starshine WAST support.
2. Human-authored Starshine WAST data fixtures should continue to use string literal payloads such as `(data (i32.const 0) "\01\00\00\00")` until a parser/lowerer/printer/test widening slice lands.
3. If a test's point is binary bytes rather than source spelling, use core or binary fixtures and cite the data authoring page. Do not use those fixtures as evidence that proposal text parses.
4. A future Starshine implementation needs focused tests for accepted typed groups, little-endian byte output, range diagnostics, malformed group sizes, mixed string/numeric concatenation if accepted by the proposal grammar, and printer roundtrip policy.
5. Keep this proposal separate from ordinary numeric instructions. `i32.const` in an offset expression is an instruction; `(i32 1024)` inside a data payload is proposed byte-literal syntax.

## Durable conclusion

The current wiki should route `Numeric Values in WAT Data Segments` through the WAST text-surface gap ledger and the data-segment authoring page. The useful wording is: active Phase-2 proposal, Starshine WAST parser currently string-payload-only, core/binary data bytes can still model equivalent payloads, and any future widening needs proposal-specific little-endian and range-check coverage.
