---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0231-2026-04-21-instrument-memory-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/InstrumentMemory.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/instrument-memory.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/instrument-memory-filter.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/instrument-memory-gc.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/instrument-memory64.wast
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/InstrumentMemory.cpp
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./helper-import-roster-filters-and-unsupported-types.md
  - ./wat-shapes.md
  - ../instrument-locals/index.md
---

# Binaryen strategy for `instrument-memory`

## What the pass really is

The reviewed implementation is a small public **instrumentation** pass.
It injects helper imports and rewrites selected operations so the helpers can observe:

- pointer addresses
- memory-access byte widths
- static memarg offsets
- loaded or stored scalar values
- `memory.grow` deltas and results
- selected GC scalar field/element values and array indices

So the best mental model is:

- **effectful observation wrappers over memory and heap-access operations**
- not optimization
- not profiling baked into the default presets
- not a general-purpose IR tracing framework

## Public registration and non-default placement

`src/passes/pass.cpp` registers a real public pass name:

- `instrument-memory`

But the pass is absent from the default optimization phases in `PassRunner::addDefault*Passes()`.
So it is public CLI / tooling surface, not part of Binaryen's ordinary optimize pipeline.

### Small but important wording drift

`pass.cpp` describes the pass as:

- instrumenting the build to intercept all loads and stores

That is incomplete.
The owner file and lit tests prove the real surface also includes:

- `memory.grow`
- `struct.get`
- `struct.set`
- `array.get`
- `array.set`

This is worth documenting because the neighboring `instrument-locals` registration uses the same misleading wording.

## Owner-file structure

Almost the whole contract lives in `InstrumentMemory.cpp`.
The file has three layers.

### Layer 1: helper names and filter setup

The file declares fixed helper names like:

- `load_ptr`
- `load_val_i32/i64/f32/f64`
- `store_ptr`
- `store_val_i32/i64/f32/f64`
- `memory_grow_pre`
- `memory_grow_post`
- GC-only helpers like `struct_get_val_*`, `array_set_val_*`, `array_get_index`, `array_set_index`

It also defines:

- `InstructionFilter = std::optional<std::unordered_set<std::string>>`
- `CHECK_EXPRESSION(...)` for per-family filter bailouts

### Layer 2: the postwalk rewriter

`AddInstrumentation` is a `WalkerPass<PostWalker<...>>`.
That means children are visited first, then the current node is wrapped or mutated.

### Layer 3: the public `Pass`

`InstrumentMemory` itself is tiny:

- `addsEffects() override { return true; }`
- parse optional `instrument-memory` pass argument into a string set
- run the postwalker

## Main rewrite families

## 1. Scalar memory loads

`visitLoad` does two different observations.

First it instruments the pointer child:

- `load_ptr(id, bytes, offset, original_ptr)`

Then it wraps the full load value in a typed helper:

- `load_val_i32`
- `load_val_i64`
- `load_val_f32`
- `load_val_f64`

Important details:

- the byte count comes from `curr->bytes`
- the static offset becomes a const pointer literal in the memory's address type
- the selected memory's address width controls both pointer and offset helper param types

So a load becomes a **prehooked pointer plus posthooked scalar value**.

## 2. Scalar memory stores

`visitStore` is similar, but the outer store remains a store.

Binaryen rewrites:

- the pointer child through `store_ptr(id, bytes, offset, original_ptr)`
- the stored scalar child through `store_val_* (id, original_value)`

So the store itself stays structurally a store, but both meaningful inputs are now observed.

## 3. `memory.grow`

`visitMemoryGrow` uses a different pattern:

- rewrite the delta with `memory_grow_pre(id, delta)`
- then wrap the whole grow expression in `memory_grow_post(id, memory.grow(...))`

This family is important because it proves the pass is broader than ordinary load/store traffic.

## 4. GC `struct.get` / `struct.set`

With GC enabled, Binaryen also instruments selected field traffic.

### `struct.get`

Binaryen wraps the entire get in a typed scalar helper call.

### `struct.set`

Binaryen keeps the `struct.set`, but wraps only the value child.

### Scalar-only value coverage

The supported field value types are only:

- `i32`
- `i64`
- `f32`
- `f64`

Reference-valued fields are not instrumented here.

## 5. GC `array.get` / `array.set`

Arrays are the most interesting family because the pass instruments both:

- the index
- the scalar payload value

`array.get` becomes:

- index rewritten via `array_get_index`
- then whole get wrapped via `array_get_val_*`

`array.set` becomes:

- index rewritten via `array_set_index`
- value rewritten via `array_set_val_*`

This is the main reason one source instruction can consume two IDs.

## ID numbering model

The pass has one shared module-walk `id` counter.
But the counter usage is not normalized to exactly one helper-id per source instruction.

### One-ID families

These use one observation ID per source op:

- `load`
- `store`
- `memory.grow`
- `struct.get`
- `struct.set`

### Two-ID families

These use separate IDs for index and value hooks:

- `array.get`
- `array.set`

### Start-at-1 versus start-at-0 surprise

Loads, stores, and memory.grow use preincrement style, so their first emitted ID is `1`.
Some GC helpers use postincrement style, so the first GC-visible ID can be `0`.

That means the IDs are:

- monotonic walk-order tags
- not semantic operation-class identifiers
- not guaranteed one-per-source op
- not guaranteed to start at `1`

## Filter model

The public pass argument is a comma-separated string list.
If empty, Binaryen instruments every supported family.
If non-empty, each visit method checks an exact string key.

The real filter vocabulary is:

- `load`
- `store`
- `memory.grow`
- `struct.get`
- `struct.set`
- `array.get`
- `array.set`

This is a source-backed exact string contract, not inference.
The dedicated filter lit file shows both positive and negative examples.

## Import injection strategy

`visitModule` adds helper imports.
This is not demand-driven per individual rewritten node.

### Always-added scalar helpers

The scalar memory and grow helpers are always added.

### GC-conditional helpers

The GC helper family is added whenever `curr->features.hasGC()`.

### Important consequence

A filtered run that only instruments `memory.grow` still receives the scalar load/store helper imports.
The filter affects rewrites, not the owner file's broad import-setup logic.

## Memory64 strategy

The pass is explicitly address-type aware.
It looks up the selected memory and uses its `addressType` for:

- the pointer param in `load_ptr` / `store_ptr`
- the offset param in those hooks
- the grow delta/result params in `memory_grow_pre` / `memory_grow_post`
- emitted pointer-like constants

So the memory64 variant is not a separate algorithm.
It is the same pass with widened pointer-side helper signatures and `i64.const` offset/address literals.

## GC strategy versus linear-memory strategy

The pass bundles both under one public name, but the shapes are intentionally different.

### Linear-memory side

- observes pointer, bytes, offset, and scalar value
- supports memory64 address widening
- uses `load_ptr` / `store_ptr`

### GC side

- no byte-count or static-offset concept
- observes scalar field/element values
- instruments array indices explicitly
- only exists when GC features are enabled

The shared theme is observation through identity-style helper calls, not a single common address API.

## Unsupported and deliberately preserved families

The reviewed `version_129` implementation deliberately leaves several surfaces alone.

### Not implemented in the owner file

- `memory.size`
- `memory.copy`
- `memory.fill`
- `memory.init`
- `data.drop`
- atomic RMW / cmpxchg (`TODO` comment)

### Type-limited scalar wrappers

- no general ref-valued struct/array payload hooks
- no typed-funcref payload hooks
- no SIMD value hooks here

So the pass is broader than its public help text suggests, but narrower than its name alone might suggest.

## Effects contract

The public pass object returns `addsEffects() == true`.
That is a major semantic fact.

Why it matters:

- instrumentation helpers are imported calls
- imported calls are effectful unless proven otherwise
- later effect-sensitive analysis and cleanup must become more conservative

This is the same basic instrumentation-story neighborhood as `instrument-locals`, which is why the sibling split belongs in the wiki tracker.

## Current-main drift check

A raw-file diff check found no diff between `version_129` and current `main` for:

- `InstrumentMemory.cpp`
- `instrument-memory.wast`
- `instrument-memory-filter.wast`
- `instrument-memory-gc.wast`
- `instrument-memory64.wast`

So the tagged release remains a stable oracle for this dossier.

## Nearby-pass relationship map

### Versus `instrument-locals`

- `instrument-locals` wraps local traffic
- `instrument-memory` wraps memory/grow/selected-GC traffic
- both inject imported helper calls
- both intentionally add effects

### Versus `global-effects`

Because `instrument-memory` adds imported-call effects, any later effect summary must be computed after instrumentation if you want the instrumented semantics.

### Versus optimizer passes like `vacuum`

After instrumentation, many operations that previously looked removable will now be protected by helper-call effects.

## What a future Starshine port must preserve

A faithful port should preserve:

- public pass identity separate from default optimization presets
- postwalk wrapping order
- pointer-prehook plus value-posthook split for loads
- pointer/value child rewrite split for stores
- pre/post grow hooks
- GC-only struct/array extension
- exact filter string vocabulary
- unconditional scalar import injection plus GC-conditional extra imports
- memory64 address-type sensitivity
- one shared monotonic ID stream, including array two-ID behavior
- explicit effect addition
- current unsupported atomic / ref-payload boundaries

## Easy-to-miss teaching summary

If someone remembers only one sentence, it should be this:

> Binaryen `instrument-memory` is not just a load/store tracer: it is a small public postwalk that injects helper imports and wraps linear-memory loads/stores, `memory.grow`, and selected scalar GC heap accesses with effectful observation calls, while preserving exact address-width and filter semantics.

## Sources

- [`../../../raw/research/0231-2026-04-21-instrument-memory-binaryen-research.md`](../../../raw/research/0231-2026-04-21-instrument-memory-binaryen-research.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/InstrumentMemory.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/instrument-memory.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/instrument-memory-filter.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/instrument-memory-gc.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/instrument-memory64.wast>
- <https://github.com/WebAssembly/binaryen/blob/main/src/passes/InstrumentMemory.cpp>
