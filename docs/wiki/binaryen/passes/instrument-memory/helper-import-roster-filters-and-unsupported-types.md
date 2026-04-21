---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0231-2026-04-21-instrument-memory-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/InstrumentMemory.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/instrument-memory-filter.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/instrument-memory-gc.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/instrument-memory64.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ../instrument-locals/index.md
---

# Helper import roster, filters, IDs, and unsupported types in `instrument-memory`

This page covers the half of the pass that is easiest to mis-teach from the name alone.

A beginner might assume:

- Binaryen instruments exactly the operations that appear in the filter
- helper imports appear only when needed
- every source instruction gets one helper ID
- and the pass probably covers every memory-like instruction or payload type

That is **not** the real rule.

## Import roster: broader than the rewritten subset

`visitModule` injects helper imports based on broad pass capability, not on per-function demand.

### Always-added scalar helpers

These are always added:

- `memory_grow_pre`
- `memory_grow_post`
- `load_ptr`
- `load_val_i32`
- `load_val_i64`
- `load_val_f32`
- `load_val_f64`
- `store_ptr`
- `store_val_i32`
- `store_val_i64`
- `store_val_f32`
- `store_val_f64`

### GC-only helpers

When GC is enabled, Binaryen also adds:

- `struct_get_val_i32/i64/f32/f64`
- `struct_set_val_i32/i64/f32/f64`
- `array_get_val_i32/i64/f32/f64`
- `array_set_val_i32/i64/f32/f64`
- `array_get_index`
- `array_set_index`

### Important consequence

A filtered pass run that only instruments `memory.grow` still gets the scalar load/store helpers injected.
The filter governs rewrites, not the module import roster.

The dedicated filter lit file proves this directly.

## Filter contract: exact string keys

The pass argument is parsed as a comma-separated string set.
The owner file checks exact string names per visitor.

The real keys are:

- `load`
- `store`
- `memory.grow`
- `struct.get`
- `struct.set`
- `array.get`
- `array.set`

This matters because the public help text is vague, but the source contract is not.

### What the filter test proves

`instrument-memory-filter.wast` proves three things that are easy to miss:

1. filtered-in load families are wrapped
2. filtered-in `memory.grow` is wrapped
3. filtered-out stores remain unchanged even though the store helper imports are still present

So a future port must preserve both:

- exact filter string behavior
- import injection that is broader than the filtered rewrite subset

## IDs: shared, monotonic, and not one-per-source-op

The pass keeps one shared `Index id = 0` counter.
That makes the helper IDs look simple at first, but there are three subtleties.

## 1. Different visitors increment differently

Loads, stores, and memory.grow do a preincrement-style pattern:

- first operation emits ID `1`

Struct and array helpers often use postincrement-style expressions:

- first visible GC helper can emit ID `0`

So the IDs are monotonic, but not normalized to a single universal starting convention.

## 2. Some source instructions consume two IDs

`array.get` and `array.set` instrument both:

- the index
- the scalar payload value

That means one source instruction can produce two helper IDs.

So the IDs are best read as:

- helper-observation sequence numbers
- not source-instruction numbers

## 3. Filtering changes the visible ID stream

Because IDs are assigned only when a rewrite happens, filtering out one instruction family changes the numbering of later instrumented observations.

So the IDs are not stable across different filter configurations.

## Unsupported instruction families

Despite the broad name, the pass intentionally does **not** instrument several memory-adjacent or heap-adjacent families.

### Not covered at all in the owner file

- `memory.size`
- `memory.copy`
- `memory.fill`
- `memory.init`
- `data.drop`
- atomic RMW
- cmpxchg

The file even has an explicit `TODO` comment for atomic RMW / cmpxchg support.

## Unsupported result and payload types

The typed scalar wrappers only cover:

- `i32`
- `i64`
- `f32`
- `f64`

That means the pass does **not** currently instrument:

- general ref-valued `struct.get` results
- general ref-valued `array.get` results
- ref-valued `struct.set` / `array.set` payloads
- SIMD value payloads in this pass
- the broad class of "other types, unreachable, etc." explicitly marked `TODO`

So the real contract is "selected scalar payload instrumentation," not "all memory and heap traffic."

## Memory64 boundary

The memory64 lit file proves the pass is careful about address width.

### What changes under memory64

- pointer-side helper signatures use `i64`
- offset/address literals become `i64.const`
- grow helper params/results use `i64`

### What does not change

- scalar value helper signatures remain typed by the observed value, not the address width

This is an easy place for a future port to go wrong by hardcoding all pointer-side helper params as `i32`.

## GC boundary

The GC lit file proves the pass widens beyond linear memory, but still in a conservative way.

### Included under GC

- `struct.get`
- `struct.set`
- `array.get`
- `array.set`
- explicit array index hooks

### Still excluded under GC

- ref-typed field payload wrappers
- ref-typed element payload wrappers
- wider generic heap-observation helpers

So the pass does not become a universal heap tracer just because GC is enabled.

## Public help-text caveat

`pass.cpp` still describes the pass as intercepting all loads and stores.
That under-describes the actual source-backed surface.

The true durable wording should be closer to:

- intercept supported memory loads/stores, `memory.grow`, and selected scalar GC heap accesses through imported helper calls

This same wording drift also exists for the sibling `instrument-locals`, which is why keeping the two folders separate matters.

## Easy-to-miss teaching summary

If someone remembers only one sentence from this page, it should be this:

> Binaryen `instrument-memory` has a broader helper roster than its filtered rewrite subset, a shared but non-uniform ID stream, exact string-key filtering, and deliberately narrow scalar-only type coverage rather than universal memory/heap instrumentation.

## Sources

- [`../../../raw/research/0231-2026-04-21-instrument-memory-binaryen-research.md`](../../../raw/research/0231-2026-04-21-instrument-memory-binaryen-research.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/InstrumentMemory.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/instrument-memory-filter.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/instrument-memory-gc.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/instrument-memory64.wast>
