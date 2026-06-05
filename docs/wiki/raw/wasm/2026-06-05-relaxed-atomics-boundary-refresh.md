# Relaxed Atomics Boundary Refresh (2026-06-05)

- Source family: official WebAssembly active proposals tracker, Relaxed Atomics proposal repository/overview, and current Starshine linear-memory atomic / shared-GC atomic implementation surfaces.
- Capture date: 2026-06-05 (local project date).
- Reason for capture: add a focused source bridge and living boundary page so `Relaxed Atomics` claims are not lost inside the broad feature-status table or conflated with Starshine's existing ordinary atomics, `AtomicOrder::AcqRel` for shared-GC `struct.atomic.get*`, or Core/finished relaxed SIMD.
- Status: immutable primary-source bridge. This supplements [`2026-06-04-webassembly-active-proposal-routing-current-refresh.md`](2026-06-04-webassembly-active-proposal-routing-current-refresh.md) and [`2026-06-04-webassembly-proposal-status-current-recheck.md`](2026-06-04-webassembly-proposal-status-current-recheck.md); the living boundary page is [`../../wasm-relaxed-atomics-boundary.md`](../../wasm-relaxed-atomics-boundary.md).

## Primary sources checked

1. WebAssembly proposals repository README, active proposals table, checked 2026-06-05: <https://github.com/WebAssembly/proposals>.
2. Relaxed Atomics proposal repository README, checked 2026-06-05: <https://github.com/WebAssembly/relaxed-atomics>.
3. Relaxed Atomics proposal overview, checked 2026-06-05: <https://github.com/WebAssembly/relaxed-atomics/blob/main/proposals/relaxed-atomics/Overview.md>.
4. Relaxed Atomics proposal directory, checked 2026-06-05: <https://github.com/WebAssembly/relaxed-atomics/tree/main/proposals/relaxed-atomics>.
5. Current Starshine code evidence in [`../../../../src/lib/types.mbt`](../../../../src/lib/types.mbt), [`../../../../src/binary/decode.mbt`](../../../../src/binary/decode.mbt), [`../../../../src/binary/encode.mbt`](../../../../src/binary/encode.mbt), [`../../../../src/validate/typecheck.mbt`](../../../../src/validate/typecheck.mbt), [`../../../../src/validate/gen_valid.mbt`](../../../../src/validate/gen_valid.mbt), [`../../../../src/wast/keywords.mbt`](../../../../src/wast/keywords.mbt), and [`../../../../src/wast/parser.mbt`](../../../../src/wast/parser.mbt).

## Current source facts

- The active proposals tracker still lists `Relaxed Atomics` in Phase 2 (`Proposed Spec Text Available`) and names Conrad Watt and Rezvan Mahdavi Hezaveh as champions. It is not listed in Phase 5 or in the finished-proposals table by this source path.
- The proposal repository describes itself as a prototype specification and implementation repository for adding relaxed atomics support to WebAssembly, and links the proposal overview plus a formatted spec build.
- The proposal overview says the feature adds weaker memory orderings plus spinlock relaxation hints. The concrete source-level additions are: release-acquire (`acqrel`) ordering for linear-memory atomic loads, stores, RMW, and cmpxchg operations, ordering immediates encoded after atomic `memarg`s when a flag bit is present, `atomic.fence` interpreting its immediate as an ordering byte, and a new `pause` instruction at `0xFE 0x04`.
- The proposal overview's memory-access encoding is not the same as current Starshine `MemArg`. Starshine stores alignment exponent, optional memory index, and offset; it has no field for a linear-memory atomic ordering immediate and no decode/encode path for bit-5 ordering-presence signaling.
- Starshine's linear-memory atomic core/binary/typechecker/generator surface currently covers the ordinary threads-style `0xFE` atomic loads, stores, RMW, cmpxchg, wait/notify, and `AtomicFence`, with `AtomicFence` accepted only as subopcode `3` plus zero immediate. `0xFE 0x04` is not decoded as `pause`.
- Starshine also has an `AtomicOrder` enum with `SeqCst` and `AcqRel`, but current code uses it for shared-GC `StructAtomicGet*` immediates and WAST text order spellings, not for linear-memory atomic access ordering. This local enum is therefore not relaxed-atomics support.
- `GenValidProposalFeature` has `RelaxedSimdFeature` and `AtomicsFeature`, but no `RelaxedAtomicsFeature`; `AtomicsFeature` is ordinary current-Starshine-valid linear-memory atomic coverage gated by memories, shared memories, and `allow_atomics`.

## Starshine interpretation rules

1. Treat Relaxed Atomics as active Phase-2 proposal evidence, not stable Core 3.0 and not finished relaxed SIMD.
2. Do not cite ordinary `AtomicsFeature`, `[FZG]017`, `AtomicFence`, or linear-memory `0xFE` codec coverage as relaxed-atomics support unless a future slice adds explicit ordering immediates and `pause` evidence.
3. Do not cite shared-GC `AtomicOrder::AcqRel` or `struct.atomic.get*` parser support as linear-memory relaxed-atomics support. They are a separate shared-GC aggregate surface.
4. A future implementation should start from a design slice that updates the core representation, binary memarg/ordering encoding, validation, WAST syntax/printing policy, generator feature gates, effect model, invalid-binary cases, and external-validator classification together.
5. If external tools accept `pause`, `acqrel`, or nonzero `atomic.fence` ordering bytes before Starshine does, classify that through the feature-status and external-validator adapter vocabulary before treating it as a Starshine bug.

## Durable conclusion

The highest-value living change is a focused boundary page rather than another broad feature-status paragraph. Relaxed Atomics adds linear-memory ordering semantics and `pause`; current Starshine implements ordinary linear-memory atomics and shared-GC atomic-get order spellings, but it has no documented local support for relaxed-atomics ordering immediates, `pause`, a dedicated generator gate, WAST syntax, or validator semantics.
