# WebAssembly Memory Control Boundary Refresh (2026-06-05)

- Source family: official WebAssembly proposals tracker, Memory Control proposal repository, proposal overview, focused `memory.discard` sub-proposal, and current Starshine memory instruction code paths.
- Capture date: 2026-06-05 (local project date).
- Reason for capture: give the living wiki a focused boundary for the active Memory Control proposal so current `memory.size` / `memory.grow` / `memory.fill` / `memory.copy` / `memory.init`, memory64, multi-memory, shared-memory, and Custom Page Sizes claims do not imply support for discard, commit, protection, mapping, or virtual-memory APIs.
- Status: immutable primary-source bridge. The living page [`../../wasm-memory-control-boundary.md`](../../wasm-memory-control-boundary.md) is canonical for current Starshine routing.

## Primary sources checked

1. WebAssembly proposals repository README, active proposals table, checked 2026-06-05: <https://github.com/WebAssembly/proposals>.
2. WebAssembly Memory Control proposal repository README, checked 2026-06-05: <https://github.com/WebAssembly/memory-control>.
3. Memory Control proposal overview, checked 2026-06-05: <https://github.com/WebAssembly/memory-control/blob/main/proposals/memory-control/Overview.md>.
4. Memory Control `memory.discard` sub-proposal, checked 2026-06-05: <https://github.com/WebAssembly/memory-control/blob/main/proposals/memory-control/discard.md>.
5. Current Starshine memory instruction representation and WAST/binary/validation paths: [`../../../../src/lib/types.mbt`](../../../../src/lib/types.mbt), [`../../../../src/wast/keywords.mbt`](../../../../src/wast/keywords.mbt), [`../../../../src/wast/lower_to_lib.mbt`](../../../../src/wast/lower_to_lib.mbt), [`../../../../src/binary/decode.mbt`](../../../../src/binary/decode.mbt), [`../../../../src/binary/encode.mbt`](../../../../src/binary/encode.mbt), and [`../../../../src/validate/typecheck.mbt`](../../../../src/validate/typecheck.mbt).

## Current source facts

- The official proposals tracker still places **Memory control** in Phase 1 (`Feature Proposal`) as of the 2026-06-05 check. It is not in the finished-proposals table or the Core 3.0 stable instruction set.
- The Memory Control repository describes itself as a proposal for finer-grained control of WebAssembly memory and points readers to an overview plus modified-spec draft work.
- The overview frames current linear memory as contiguous byte-addressable memory that can grow but cannot shrink, and lists the three main motivators as reducing copies into Wasm memory, letting applications control memory footprint, and supporting protection-style use cases.
- The overview explicitly says the proposal is in early stages and splits ideas into sub-proposals that may change, merge, or disappear before Phase 2. Current sub-proposals include BYOB for `WebAssembly.Memory`, `memory.discard`, static memory protection, mappable memory, and virtual mode. Lazy commit / `memory.commit` is discussed as an alternative or possible future sub-proposal, not as a finalized instruction contract.
- The `memory.discard` sub-proposal describes a stack shape of `memory.discard $memidx : [addr:idx size:idx] -> []`, says the operation zeroes the requested range while allowing hosts with virtual memory to release backing resources, aligns the byte range to pages, traps on out-of-bounds ranges, and records a SpiderMonkey prototype opcode of `0xfc 0x12`.
- Current Starshine has no `Instruction` variant, WAST keyword, binary decode/encode case, typechecker rule, valid-generator gate, or pass-helper surface for `memory.discard`, `memory.commit`, memory protection, mappable memory, or virtual mode. Starshine's current memory instruction surface remains scalar loads/stores, `memory.size`, `memory.grow`, ordinary atomics, and Core bulk-memory/table `0xFC` subcodes `8..17`.

## Starshine interpretation rules

1. Treat Memory Control as active Phase-1 proposal evidence only. Do not describe it as stable Core WebAssembly, finished proposal behavior, or current Starshine support.
2. Keep `memory.discard` separate from `data.drop`: `data.drop` invalidates passive data segment reuse, while `memory.discard` would operate on a linear-memory byte range.
3. Keep `memory.discard` separate from `memory.fill`: both can leave zero bytes behind, but `memory.fill` is an ordinary write and does not imply host decommit, protection, mapping, or memory-footprint control semantics.
4. Keep Memory Control separate from memory64/multi-memory/shared-memory/Custom Page Sizes. Those features change address width, selected-memory dimensions, synchronization/sharing, or page-size declarations; Memory Control changes runtime memory-management capabilities.
5. Any future Starshine implementation requires new source and tests across core instruction representation, binary codec, WAST parser/lowerer/printer if text is exposed, typechecker stack/effect/trap rules, generator feature gates, external-validator classification, and pass effect/barrier modeling.

## Durable conclusion

Add a focused living boundary page and route broad feature-status, memory-instruction, binary-instruction, and index readers through it. The wiki should teach Memory Control as an active proposal family with no current local support, while preserving the current ordinary memory instruction docs for implemented Core surfaces.
