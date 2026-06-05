# 2026-06-05 Wide Arithmetic Boundary Refresh

- Date: 2026-06-05
- Topic: active WebAssembly Wide Arithmetic proposal versus current Starshine numeric/binary/validator support
- Status: source bridge for [`../../wasm-wide-arithmetic-boundary.md`](../../wasm-wide-arithmetic-boundary.md), [`../../wasm-feature-status-and-proposal-boundaries.md`](../../wasm-feature-status-and-proposal-boundaries.md), [`../../wast/numeric-instruction-authoring.md`](../../wast/numeric-instruction-authoring.md), and [`../../binary/instruction-and-expression-encoding.md`](../../binary/instruction-and-expression-encoding.md)

## Sources Checked

1. Official WebAssembly proposals tracker, checked 2026-06-05: <https://github.com/WebAssembly/proposals>
2. Wide Arithmetic proposal repository, checked 2026-06-05: <https://github.com/WebAssembly/wide-arithmetic>
3. Wide Arithmetic proposal overview, checked 2026-06-05: <https://github.com/WebAssembly/wide-arithmetic/blob/main/proposals/wide-arithmetic/Overview.md>
4. Wide Arithmetic draft binary-instruction page, checked 2026-06-05: <https://webassembly.github.io/wide-arithmetic/core/binary/instructions.html>
5. Wide Arithmetic draft validation-instruction page, checked 2026-06-05: <https://webassembly.github.io/wide-arithmetic/core/valid/instructions.html>
6. Binaryen `version_130` release horizon and current wiki release bridge: [`../binaryen/2026-06-04-binaryen-v130-release-horizon-recheck.md`](../binaryen/2026-06-04-binaryen-v130-release-horizon-recheck.md), [`../../binaryen/release-horizon-and-oracles.md`](../../binaryen/release-horizon-and-oracles.md)
7. Starshine local instruction and codec evidence, checked 2026-06-05: [`../../../../src/lib/types.mbt`](../../../../src/lib/types.mbt), [`../../../../src/wast/keywords.mbt`](../../../../src/wast/keywords.mbt), [`../../../../src/wast/lower_to_lib.mbt`](../../../../src/wast/lower_to_lib.mbt), [`../../../../src/binary/decode.mbt`](../../../../src/binary/decode.mbt), [`../../../../src/binary/encode.mbt`](../../../../src/binary/encode.mbt), [`../../../../src/validate/typecheck.mbt`](../../../../src/validate/typecheck.mbt), [`../../../../src/validate/gen_valid.mbt`](../../../../src/validate/gen_valid.mbt)

## Observed Facts

- The current official proposals tracker keeps Wide Arithmetic in the active-proposal area rather than the finished/Core bucket. Treat this as proposal-status evidence only, not a Starshine support claim.
- The proposal overview teaches four scalar integer instructions: `i64.add128`, `i64.sub128`, `i64.mul_wide_s`, and `i64.mul_wide_u`. The add/sub forms consume two 128-bit values represented as pairs of `i64` stack values and produce a 128-bit pair; the multiply forms consume two `i64` values and produce the 128-bit product pair, with signed and unsigned variants.
- The proposal creates multi-value numeric results. That matters even for scalar-numeric readers: a future Starshine implementation would need parser, core-instruction, binary, validation, printer, generator, and optimizer evidence for instructions that push two `i64` results.
- The proposal sources currently have an opcode-routing wrinkle that should stay visible until implementation time. The overview text says existing `0xFC` subcodes `8` through `17` are occupied by bulk memory/table operations, `memory.discard` is expected at `18`, and Wide Arithmetic is expected at `19` through `22`. The draft rendered binary page still lists Wide Arithmetic opcodes in the `0xFC 13` through `0xFC 16` range, which collides with current Core table opcodes in Starshine. Do not implement from one stale-looking table without rechecking the proposal repository, issue history, and any tool implementation chosen as oracle.
- Current Starshine has no focused Wide Arithmetic implementation evidence. Repository search found ordinary scalar `I64Add` / `I64Sub` / `I64Mul` / division / remainder instructions and prefixed `0xFC` saturating/bulk/table instructions, but no `add128`, `sub128`, `mul_wide_s`, `mul_wide_u`, or wide-arithmetic-specific instruction variants, WAST keywords, typecheck cases, encode cases, or generator rows.
- Current Starshine binary `0xFC` decode accepts saturating truncations (`0..7`), bulk memory/table/data/element forms (`8..17`), and rejects other `0xFC` subcodes as invalid instructions. A future Wide Arithmetic slice must widen this deliberately instead of relying on the generic prefixed-opcode lane.
- Binaryen `version_130` release notes mention Wide Arithmetic support. That is Binaryen/tool-oracle evidence, not local Starshine parser/validator support and not a pass-parity contract until a local feature slice or pass explicitly targets it.

## Durable Wiki Implications

1. Add a focused boundary page so maintainers do not infer local support from the broad numeric guide or from Binaryen `v130` release notes.
2. Update the feature-status router with a Wide Arithmetic row instead of leaving it inside the catch-all active-proposal bucket.
3. Update scalar numeric and binary-instruction pages so future fixtures route Wide Arithmetic as active proposal work, not as a missing ordinary scalar numeric opcode.
4. Keep the opcode contradiction explicit. If a future implementation slice starts, recheck the proposal overview, rendered spec pages, issue/PR history, WABT/wasm-tools/Binaryen behavior, and final subopcode assignment before adding bytes or tests.

## No-Support Code Map

| Starshine layer | Current evidence checked | Current result |
| --- | --- | --- |
| WAST keywords/parser | [`../../../../src/wast/keywords.mbt`](../../../../src/wast/keywords.mbt), [`../../../../src/wast/parser.mbt`](../../../../src/wast/parser.mbt) | No `i64.add128`, `i64.sub128`, `i64.mul_wide_s`, or `i64.mul_wide_u` keyword/parser cases. |
| Core instruction model | [`../../../../src/lib/types.mbt`](../../../../src/lib/types.mbt) | Ordinary scalar `I64Add` / `I64Sub` / `I64Mul` exist; no wide-arithmetic variants. |
| Binary decode/encode | [`../../../../src/binary/decode.mbt`](../../../../src/binary/decode.mbt), [`../../../../src/binary/encode.mbt`](../../../../src/binary/encode.mbt) | `0xFC` currently covers `0..17` saturating/bulk/table forms and rejects other subcodes; no wide-arithmetic encode cases. |
| Validation | [`../../../../src/validate/typecheck.mbt`](../../../../src/validate/typecheck.mbt) | Ordinary `i64` binary ops produce one `i64`; no multi-result wide-arithmetic typecheck cases. |
| Generator/fuzz feature gates | [`../../../../src/validate/gen_valid.mbt`](../../../../src/validate/gen_valid.mbt) | No documented Wide Arithmetic feature gate, opcode counts, or valid-generator rows. |
