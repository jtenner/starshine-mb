---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-memory64-lowering-primary-sources.md
  - ../../../raw/research/0315-2026-04-24-memory64-lowering-primary-sources-and-starshine-followup.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
---

# Binaryen strategy for `memory64-lowering`

## Short version

Binaryen's `memory64-lowering` converts wasm64 memory-indexed code into wasm32 memory-indexed code by changing the memory declarations and explicitly repairing every typed use site.
The sibling `table64-lowering` does the same for table indexes.

The pass is not a profitability optimization. It is an ABI / feature-lowering transform.

## Public pass identity

In Binaryen `version_129`, `pass.cpp` registers:

- `memory64-lowering` - lower 64-bit memory indexes to 32-bit indexes;
- `table64-lowering` - lower 64-bit table indexes to 32-bit indexes.

Both names are public pass names and both point at the same owner-file family captured in [`../../../raw/binaryen/2026-04-24-memory64-lowering-primary-sources.md`](../../../raw/binaryen/2026-04-24-memory64-lowering-primary-sources.md).

## Core rewrite model

### 1. Lower the declaration

A memory/table with 64-bit limits is rewritten to a 32-bit limit form.
After this step, ordinary wasm typing says the same operation now wants `i32` indexes.

### 2. Wrap former `i64` inputs

Any operand that was typed as an address/index/count because of a memory64/table64 declaration must be converted before feeding the lowered instruction:

```wat
;; before: memory64 load expects i64 address
(i32.load (i64.const 40))

;; after: lowered memory32 load expects i32 address
(i32.load (i32.wrap_i64 (i64.const 40)))
```

This same pattern applies to scalar memory ops, SIMD memory ops, atomics, bulk memory/table operations, and table operations whose index/delta/count operand used to be `i64`.

### 3. Extend former `i64` results

Some operations return the address type. After lowering, the operation itself returns `i32`, but the surrounding source-level expression may still require `i64`.
Binaryen repairs that with unsigned extension:

```wat
;; before
(memory.size 0) ;; result type i64 when memory 0 is memory64

;; after
(i64.extend_i32_u (memory.size 0))
```

The same result repair applies to:

- `memory.size`
- `memory.grow`
- `table.size`
- `table.grow`

Unsigned extension is important: memory and table indexes are unsigned quantities.

### 4. Rewrite segment offsets

Active data and element segment offsets are part of module initialization, so lowering is not complete if only function bodies are rewritten.
The pass also repairs offset expressions such as an `i64.const` data offset into 32-bit form.

### 5. Handle mixed-width bulk operations positionally

Bulk operations are the easiest place to get the port wrong.
The destination address, source address, and length operands do not always share one width.
For copy operations, the reviewed Binaryen code treats length as 64-bit only when both participating memories or tables are 64-bit; mixed memory32/memory64 or table32/table64 copies lower only the positions that need lowering.

## What Binaryen does not try to do here

- It does not prove pointer values are in range at runtime. `i32.wrap_i64` is a modulo-style narrowing operation.
- It does not optimize address arithmetic.
- It does not replace neighboring memory-packing, optimize-added-constants, or instrumentation passes.
- It does not make memory64/table64 semantics available in an engine that cannot otherwise allocate the requested 64-bit range.

## Emscripten context

Emscripten's official settings reference documents `MEMORY64=2` as a mode that uses wasm64 internally and lowers to wasm32 before final output.
That is a useful external motivation for the pass, but the mechanics on this page are sourced from Binaryen's `Memory64Lowering.cpp`, `pass.cpp`, and lit tests.

## Current-main freshness

A narrow 2026-04-24 current-`main` spot check of the owner source and the lit filenames did not reveal teaching-level drift from the `version_129` claims captured here.
If a future port depends on exact out-of-range limit behavior, re-open the current source and confirm that detail before implementing.

## Sources

- Raw manifest: [`../../../raw/binaryen/2026-04-24-memory64-lowering-primary-sources.md`](../../../raw/binaryen/2026-04-24-memory64-lowering-primary-sources.md)
- Research note: [`../../../raw/research/0315-2026-04-24-memory64-lowering-primary-sources-and-starshine-followup.md`](../../../raw/research/0315-2026-04-24-memory64-lowering-primary-sources-and-starshine-followup.md)
- Binaryen `Memory64Lowering.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Memory64Lowering.cpp>
- Binaryen `memory64-lowering.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/memory64-lowering.wast>
- Binaryen `table64-lowering.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/table64-lowering.wast>
- Emscripten `MEMORY64` setting: <https://emscripten.org/docs/tools_reference/settings_reference.html#memory64>
