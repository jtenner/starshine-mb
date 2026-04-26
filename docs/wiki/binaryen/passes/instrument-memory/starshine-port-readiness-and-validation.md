---
kind: concept
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-instrument-memory-current-main-port-readiness.md
  - ../../../raw/research/0388-2026-04-26-instrument-memory-port-readiness.md
  - ../../../raw/binaryen/2026-04-24-instrument-memory-primary-sources.md
  - ../../../raw/research/0288-2026-04-24-instrument-memory-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/ir/hot_lift.mbt
  - ../../../../../src/ir/hot_lower.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/binary/decode.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./helper-import-roster-filters-and-unsupported-types.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../instrument-locals/index.md
  - ../global-effects/index.md
  - ../vacuum/index.md
---

# Starshine port-readiness and validation for `instrument-memory`

## Purpose of this page

This page is for future implementers. It answers a narrower question than the main Starshine status page:

> If Starshine ever chooses to implement Binaryen's `instrument-memory`, what is the safe first slice and how should it be validated?

Current status remains unchanged: Starshine does **not** implement or register `instrument-memory` today. See [`./starshine-strategy.md`](./starshine-strategy.md) for the exact current no-registry/no-owner-file status.

## Binaryen contract to preserve

The 2026-04-26 current-main recheck found no teaching-relevant drift from the tagged `version_129` source contract captured earlier.

A faithful Starshine port must preserve these Binaryen behaviors:

1. **Public pass identity**: `instrument-memory` is a named public pass, not a default optimization preset member.
2. **Module-level helper imports**: the pass injects helper imports as part of its output.
3. **Effect addition**: instrumentation helpers are imported calls, and Binaryen declares `addsEffects()`.
4. **Postwalk wrapping order**: children are visited/replaced before the current memory or heap operation is wrapped.
5. **Linear-memory load shape**: rewrite the pointer child with `load_ptr(id, bytes, offset, ptr)` and wrap the loaded scalar with `load_val_*`.
6. **Linear-memory store shape**: rewrite the pointer child with `store_ptr(...)` and the stored scalar with `store_val_*` while preserving the outer store.
7. **`memory.grow` shape**: rewrite the delta through `memory_grow_pre(...)` and wrap the grow result through `memory_grow_post(...)`.
8. **GC scalar extension**: under GC, wrap scalar `struct.get` / `struct.set` / `array.get` / `array.set` payloads and array indices.
9. **Exact filter vocabulary**: `load`, `store`, `memory.grow`, `struct.get`, `struct.set`, `array.get`, `array.set`.
10. **Memory64 address typing**: pointer-like helper params and offset constants widen to `i64` for memory64, but scalar value hooks stay payload-typed.
11. **Unsupported-family preservation**: bulk memory, atomic RMW/cmpxchg, general reference payloads, and SIMD payloads are not silently instrumented.

These are source-backed by the official Binaryen owner file and dedicated lit files in the raw captures.

## Starshine prerequisite map

Existing local code gives useful substrate, not partial support.

| Need | Current local surface | Why it is prerequisite-only |
| --- | --- | --- |
| Pass identity and rejection behavior | `src/passes/optimize.mbt:127-153`, `src/passes/optimize.mbt:156-280`, `src/passes/optimize.mbt:463-465` | The name is absent today; unknown-name rejection is the current behavior, not a hidden compatibility entry. |
| Registry tests | `src/passes/registry_test.mbt` | It tests registry categories and preset expansion but has no `instrument-memory` assertion. |
| Memory instruction representation | `src/lib/types.mbt:566-567`, `src/ir/hot_lift.mbt:715-763` | Starshine can represent and lift `memory.size`, `memory.grow`, loads, and stores; this does not synthesize helper imports or wrappers. |
| GC heap instruction representation | `src/lib/types.mbt:740-752`, `src/ir/hot_lift.mbt:799-810` | Starshine can represent GC struct/array accesses; this does not implement Binaryen's scalar-only instrumentation policy. |
| Binary codec preservation | `src/binary/encode.mbt:2250`, `src/binary/encode.mbt:2629-2751`, `src/binary/decode.mbt:2758`, `src/binary/decode.mbt:2955-3036` | Encode/decode support is required for tests, but it is not a transform. |
| Pipeline memory/import helpers | `src/passes/optimize.mbt:418-453` | Imported-function and memory-presence helpers are validation/pipeline bookkeeping, not helper ABI synthesis. |

## Recommended first Starshine slice

Do **not** begin with every Binaryen surface at once. Start with the smallest observable module transform that proves the architecture.

### Slice 0: registry honesty

Choose and test one of these product states:

- keep `instrument-memory` unknown and document why,
- add it as boundary-only documentation surface,
- or add it as a real module pass.

If it becomes real, add registry tests before implementation so the public behavior is intentional.

### Slice 1: scalar linear memory and grow, no filters

Implement only:

- helper import synthesis for scalar load/store/grow helpers,
- `load_ptr` plus `load_val_*`,
- `store_ptr` plus `store_val_*`,
- `memory_grow_pre` plus `memory_grow_post`,
- monotonic helper IDs for these families,
- effect invalidation/annotation in Starshine's pass machinery.

Defer:

- filters,
- memory64,
- GC struct/array hooks,
- atomics,
- bulk memory,
- ref and SIMD payloads.

This first slice should already be useful and directly comparable to Binaryen on simple MVP modules.

### Slice 2: unsupported-family preservation

Before adding more positives, add negative tests proving these remain unchanged:

- `memory.size`,
- `memory.copy`,
- `memory.fill`,
- `memory.init`,
- `data.drop`,
- atomic RMW/cmpxchg,
- SIMD loads/stores as value payload hooks,
- reference-valued GC fields/elements.

The goal is to prevent future broad pattern matching from over-instrumenting.

### Slice 3: filter parsing

Add exact comma-separated filter parsing with the Binaryen keys:

- `load`,
- `store`,
- `memory.grow`,
- `struct.get`,
- `struct.set`,
- `array.get`,
- `array.set`.

Keep the Binaryen caveat explicit: helper imports may be broader than the filtered rewrite subset.

### Slice 4: memory64 address widening

Add tests where the pointer-side helper params and offset/address constants are `i64`, while scalar value hooks remain `i32`, `i64`, `f32`, or `f64` as appropriate.

### Slice 5: GC scalar heap hooks

Only after the linear-memory side is stable, add GC hooks for:

- scalar `struct.get`,
- scalar `struct.set`,
- scalar `array.get`,
- scalar `array.set`,
- array index hooks.

Keep reference and SIMD payloads preserved unless a future Binaryen source update changes the contract or Starshine intentionally diverges.

## Validation ladder

### Reduced WAT tests first

Use dedicated reduced tests mirroring the official lit split:

1. `instrument-memory` scalar loads/stores,
2. `instrument-memory-filter`,
3. `instrument-memory-gc`,
4. `instrument-memory64`.

For each test, assert both transformed shapes and helper import signatures.

### Oracle comparison

When a local pass exists, compare covered subsets against:

- `wasm-opt --instrument-memory`,
- `wasm-opt --instrument-memory=load,memory.grow`,
- `wasm-opt --mvp-features --instrument-memory` where feature gating matters,
- memory64 and GC fixtures only after those slices are implemented locally.

Treat helper import order, helper names, and helper signatures as ABI-visible output unless a documented local divergence says otherwise.

### Effect-composition tests

Add at least one test where an otherwise-removable memory operation becomes protected by the injected imported helper calls. This ties the pass to Starshine's effect-sensitive optimization story and prevents it from being misclassified as effect-neutral.

If composed with local effect summaries later, compute or invalidate those summaries **after** instrumentation.

### General repo validation

For documentation-only changes, no MoonBit behavior changes are expected. For a real implementation, run the standard local gate:

- `moon info`,
- `moon fmt`,
- `moon test`,
- then targeted Binaryen oracle comparisons if the pass harness supports instrumentation passes.

## Non-goals and traps

- Do not add this pass to default optimize or shrink presets just because Binaryen exposes it publicly.
- Do not infer support from Starshine's existing `Load`, `Store`, `MemoryGrow`, `StructGet`, or `ArrayGet` representations.
- Do not silently instrument bulk memory or atomics; Binaryen's owner file does not do that today.
- Do not merge this work into [`instrument-locals`](../instrument-locals/index.md); helper names, observed operands, and instruction families differ.
- Do not treat helper IDs as stable semantic operation identifiers. They are source-order observation tags with family-specific increment behavior.

## Open decisions for a future port

- Should Starshine expose `instrument-memory` at all, or keep it as upstream-only documentation?
- If exposed, should it exactly match Binaryen's helper import ABI, or deliberately use a Starshine-specific ABI?
- Where should filter parsing live so it does not complicate ordinary optimizer pass expansion?
- How should module-level helper import synthesis interact with Starshine's existing import indexing, name preservation, and validation repair?
- What is the local effect-invalidation API for a module pass that injects imported calls?

Record those decisions in this folder before implementation so future readers can tell deliberate divergence from accidental incompleteness.
