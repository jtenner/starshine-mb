# Wide Arithmetic Opcode Reconciliation

- Capture date: 2026-07-10
- Source family: official WebAssembly proposal tracker and Wide Arithmetic proposal repository, with current Starshine codec evidence
- Reason for capture: resolve the live wiki's ambiguous “subopcode contradiction” into an operational rule for future Starshine work without claiming that the active proposal is stable Core WebAssembly.
- Status: immutable primary-source bridge for [`../../wasm-wide-arithmetic-boundary.md`](../../wasm-wide-arithmetic-boundary.md), [`../../wasm-feature-status-and-proposal-boundaries.md`](../../wasm-feature-status-and-proposal-boundaries.md), [`../../wast/numeric-instruction-authoring.md`](../../wast/numeric-instruction-authoring.md), and [`../../binary/instruction-and-expression-encoding.md`](../../binary/instruction-and-expression-encoding.md). It supersedes the **exact-opcode interpretation** of [`2026-06-05-wide-arithmetic-boundary-refresh.md`](2026-06-05-wide-arithmetic-boundary-refresh.md); that earlier capture remains historical provenance for the original mismatch and Starshine no-support map.

## Primary sources checked

1. WebAssembly proposals tracker, checked 2026-07-10: <https://github.com/WebAssembly/proposals>
2. Wide Arithmetic proposal overview on the proposal repository `main`, checked 2026-07-10: <https://github.com/WebAssembly/wide-arithmetic/blob/main/proposals/wide-arithmetic/Overview.md>
3. Wide Arithmetic rendered draft binary instructions page, checked 2026-07-10: <https://webassembly.github.io/wide-arithmetic/core/binary/instructions.html>
4. Wide Arithmetic rendered draft validation instructions page, checked 2026-07-10: <https://webassembly.github.io/wide-arithmetic/core/valid/instructions.html>
5. Starshine's current `0xFC` decoder and encoder: [`../../../../src/binary/decode.mbt`](../../../../src/binary/decode.mbt) and [`../../../../src/binary/encode.mbt`](../../../../src/binary/encode.mbt)

## Observed facts

- The official tracker still lists Wide Arithmetic as an active **Phase 3** proposal. Nothing in this recheck promotes it to Core WebAssembly or proves Starshine support.
- The current proposal overview gives an explicit implementation-placement rule: Core/bulk-memory table operations already consume `0xFC` subcodes `13` through `17`; it describes `18` as the expected Memory Control `memory.discard` slot and places Wide Arithmetic at `0xFC` subcodes **`19` through `22`**. In instruction order, those are `i64.add128`, `i64.sub128`, `i64.mul_wide_s`, and `i64.mul_wide_u`.
- The rendered draft binary page remains inconsistent: it still assigns the four Wide Arithmetic instructions to `0xFC 13` through `0xFC 16`. Its rendered header identifies it as a draft Core specification dated **2025-09-21**. Those bytes collide with the current Core table instructions, so that rendered table cannot be used as a Starshine implementation authority.
- Starshine currently decodes and encodes `0xFC 13` through `0xFC 17` as `elem.drop`, `table.copy`, `table.grow`, `table.size`, and `table.fill`, respectively. It has no Wide Arithmetic instruction variants or codec cases, and its generic `0xFC` decoder rejects unrecognized subcodes.
- The proposal validation draft confirms the four stack signatures are multi-result scalar operations, but does not resolve the binary-page lag by itself.

## Durable interpretation

The old sources do not leave an implementation free to choose either range. For a future proposal-gated Starshine slice, use **`0xFC 19..22` only** as the proposal repository's current intended byte placement, while preserving the standards-status caveat that the feature is active Phase 3 rather than final Core.

Treat the rendered `0xFC 13..16` table as a stale/unreconciled proposal artifact, not as an alternate legal encoding. Never add a compatibility decoder for those conflicting bytes: it would reinterpret existing Core table instructions and make currently valid modules ambiguous. Keep `0xFC 18` separate as Memory Control territory unless that proposal's own sources establish a different final assignment.

## Future implementation and external-tool guidance

1. Recheck the tracker, overview, and rendered draft before implementation; record whether the rendered specification has caught up.
2. Add a feature-gated core instruction model, WAST mapping, binary decode/encode, validator stack effects, printer, generator, and invalid-byte tests together.
3. Add positive byte fixtures for `0xFC 19..22`, and negative non-reinterpretation fixtures proving `0xFC 13..17` remain the existing table forms. Do not use the stale `13..16` bytes as Wide Arithmetic probes.
4. Treat tool acceptance as version/flag-specific evidence. The repository's current external-adapter commands do not establish Wide Arithmetic support merely by using broad flags such as `--features all`; capture exact tool versions, flags, and diagnostics before promoting an external result into a local support claim.
5. Keep Binaryen release-note support, WABT/wasm-tools behavior, and Starshine behavior as distinct evidence layers. A tool can lead or lag the active proposal without changing its standard status or Starshine's no-support state.

## Uncertainty and supersession

- The proposal repository's maintained overview supplies the current operational placement, but the proposal remains active and therefore its bytes are not a final Core compatibility promise.
- The rendered binary draft has not reconciled its `13..16` table as of this capture. The wiki records that contradiction explicitly rather than silently editing the older raw capture.
- The prior 2026-06-05 bridge is superseded only for the claim that exact opcode placement is wholly unsettled. Its local-code inventory and historical source record remain useful.
