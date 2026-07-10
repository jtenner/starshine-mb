---
kind: raw-source-manifest
status: supported
last_reviewed: 2026-07-10
sources:
  - https://github.com/WebAssembly/binaryen/pull/8882
  - https://github.com/WebAssembly/binaryen/commit/db30c15
  - https://github.com/WebAssembly/binaryen/blob/db30c15/src/passes/MemoryPacking.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/MemoryPacking.cpp
  - https://github.com/WebAssembly/binaryen/releases/tag/version_130
  - ../../../../src/passes/memory_packing.mbt
  - ../../../../src/passes/memory_packing_test.mbt
related:
  - ../../binaryen/passes/memory-packing/index.md
  - ../../binaryen/passes/memory-packing/binaryen-strategy.md
  - ../../binaryen/passes/memory-packing/implementation-structure-and-tests.md
  - ../../binaryen/passes/memory-packing/wat-shapes.md
  - ../../binaryen/passes/memory-packing/starshine-hot-ir-strategy.md
  - ../../binaryen/passes/memory-packing/parity.md
  - ../../binaryen/release-horizon-and-oracles.md
---

# Binaryen `memory-packing` imported-overlap current-main refresh

_Capture date:_ 2026-07-10  
_Status:_ immutable primary-source manifest for a post-`version_130` current-main drift

## Scope

This capture reconciles the earlier `memory-packing` dossier claim that Binaryen `main` still matched `version_130` / `version_129` on its active-segment-overlap gate.

That claim was true for the 2026-06-07 comparison, but is now stale. Binaryen PR [#8882](https://github.com/WebAssembly/binaryen/pull/8882), merged to `main` as [`db30c15`](https://github.com/WebAssembly/binaryen/commit/db30c15) on 2026-07-10, changes `MemoryPacking.cpp`. The current public release baseline remains [`version_130`](https://github.com/WebAssembly/binaryen/releases/tag/version_130); this is a current-main drift watch, **not** a claim that the released oracle changed.

## Primary sources checked

- [PR #8882](https://github.com/WebAssembly/binaryen/pull/8882), **“Allow optimizing overlapping segments on imported memory (when in allocation)”**.
- The merged [`db30c15` `MemoryPacking.cpp` diff](https://github.com/WebAssembly/binaryen/blob/db30c15/src/passes/MemoryPacking.cpp).
- [`version_130` `MemoryPacking.cpp`](https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/MemoryPacking.cpp), the previously reviewed release-side source.
- The current local implementation and focused tests:
  - [`src/passes/memory_packing.mbt`](../../../../src/passes/memory_packing.mbt)
  - [`src/passes/memory_packing_test.mbt`](../../../../src/passes/memory_packing_test.mbt)

## Current-main delta

Before `db30c15`, Binaryen's whole-module `canOptimize(...)` gate rejected an active-data overlap unconditionally.

After `db30c15`, the source has a narrow imported-memory exception:

1. It still records active ranges with `DisjointSpans` and identifies an overlap with an earlier active segment.
2. It still bails out unless both conditions hold:
   - `zeroFilledMemory` is enabled; and
   - the sole memory is imported.
3. For that exception, it calls `provablyInBounds(...)`. An overlap may proceed only if the segment is entirely within the imported memory's declared initial allocation; the helper uses overflow-safe page-to-byte comparison and preserves the memory32 versus memory64 address-width distinction.
4. It then calls `zeroOutTrampledData(...)` before the usual range/profitability analysis. That helper finds portions of an earlier segment overwritten by later active segments and writes zeroes into those earlier payload positions. Subsequent packing can omit the trampled bytes without accidentally retaining a value that the original later segment overwrote.

This is neither a blanket "overlaps are safe" rule nor generic symbolic overlap reasoning. Dynamic active offsets, overlaps outside the declared allocation, non-imported memory, and calls without `zeroFilledMemory` remain conservative bailouts.

### Conceptual shape

```wat
;; The later segment tramples the earlier byte.
(import "env" "memory" (memory 1))
(data (i32.const 1024) "X")
(data (i32.const 1024) "\00")
```

In the new current-main special case, Binaryen can first recognize that the later `\00` overwrites the earlier `X`, zero the earlier payload in its working view, and then apply normal zero-run packing—but only under the imported-memory / zero-filled / in-bounds proof above. The example is a conceptual ordering explanation, not a new Starshine fixture or proof that every overlapping layout is eligible.

## Starshine comparison on 2026-07-10

Starshine currently accepts imported memory for `memory-packing` only when `HotPipelineOptions.zero_filled_memory` is true, but [`mp_can_optimize(...)`](../../../../src/passes/memory_packing.mbt) still returns the sorted-span disjointness result for every multi-segment active layout. The focused test [`memory-packing bails out when active segments overlap`](../../../../src/passes/memory_packing_test.mbt) locks that conservative behavior.

Therefore this is a **current-main Binaryen parity gap**, not a Starshine correctness failure and not evidence that existing non-overlap results changed. A future port needs all of the upstream proof shape together:

- source-order-aware trampling neutralization before range selection;
- the imported-memory plus explicit zero-filled gate;
- exact in-allocation proof using checked page/byte arithmetic for memory32 and memory64; and
- red-first positive and negative tests for eligible overlap, no-option, non-imported, out-of-allocation, dynamic-offset, and overflow boundaries.

## Supersession and limits

- The 2026-06-07 statement that `version_130` and then-current `main` were byte-identical remains historical evidence for that date. It is superseded for current-main claims by this capture.
- `version_130` remains the public release baseline. Existing release-anchored signoff is not silently retagged to a post-release commit.
- No local code or test behavior changed in this documentation run.
