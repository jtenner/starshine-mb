# Binaryen `instrument-memory` research

- Date: 2026-04-21
- Pass: `instrument-memory`
- Upstream tag: `version_129`
- Status in Starshine: upstream-only; not present in `src/passes/optimize.mbt`
- Related local docs: `docs/wiki/binaryen/passes/instrument-locals/`, `docs/wiki/binaryen/passes/global-effects/`, `docs/wiki/binaryen/passes/tracker.md`

## Why this pass, and why now

The tracker no longer had obvious `none` targets, so picking another pass required an explicit justified expansion instead of a routine backlog fill.
`instrument-memory` is justified because:

1. Binaryen exposes it as a real public pass in `pass.cpp`.
2. The neighboring new `instrument-locals` dossier already depends on keeping the split from `instrument-memory` explicit.
3. The public help text is slightly misleading: `pass.cpp` describes both `instrument-locals` and `instrument-memory` as intercepting "all loads and stores", but `InstrumentMemory.cpp` actually covers memory loads/stores, `memory.grow`, and GC `struct.get` / `struct.set` / `array.get` / `array.set` families.
4. `agent-todo.md` has no dedicated `instrument-memory` slice, so the wiki needs to say that explicitly.

## Canonical source set reviewed

Official Binaryen `version_129` sources:

- `src/passes/InstrumentMemory.cpp`
- `src/passes/pass.cpp`
- `test/lit/passes/instrument-memory.wast`
- `test/lit/passes/instrument-memory-filter.wast`
- `test/lit/passes/instrument-memory-gc.wast`
- `test/lit/passes/instrument-memory64.wast`

Current-`main` drift check:

- `src/passes/InstrumentMemory.cpp`
- the same four lit files above

Local repo context reviewed first, per campaign rules:

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`
- `docs/wiki/binaryen/passes/instrument-locals/index.md`
- `docs/wiki/binaryen/passes/instrument-locals/binaryen-strategy.md`

## High-level contract

`instrument-memory` is a small module pass that injects helper imports and then postwalk-rewrites selected operations so the helper imports observe addresses, values, or grow sizes.

It is best understood as three related but distinct instrumentation families:

1. ordinary memory `load` / `store`
2. `memory.grow`
3. GC heap accesses: `struct.get`, `struct.set`, `array.get`, `array.set`

It is **not** a general tracing pass for every memory-adjacent instruction.
It does not instrument:

- `memory.size`
- `memory.copy`
- `memory.fill`
- `memory.init`
- `data.drop`
- atomic RMW or cmpxchg (`TODO` comment in source)
- GC value types outside `i32` / `i64` / `f32` / `f64`
- general reference-typed array/struct payload values

## Public registration and scheduler facts

`pass.cpp` registers a real public pass name:

- `instrument-memory`

It is **not** present in the default optimization pipeline sections in `pass.cpp`, so this is public tooling/debugging surface rather than a preset optimizer phase.

Important wording drift:

- `pass.cpp` describes `instrument-memory` as "instrument the build with code to intercept all loads and stores"
- but the owner file and tests prove that the actual surface also includes `memory.grow` and GC struct/array accesses

That same misleading wording is duplicated for `instrument-locals`, which makes keeping the sibling split in the wiki more important.

## Exact owner-file structure

The entire real implementation lives in one file:

- `InstrumentMemory.cpp`

Important pieces in that file:

- fixed helper-import `Name`s for load/store/grow/GC hooks
- `InstructionFilter = std::optional<std::unordered_set<std::string>>`
- `CHECK_EXPRESSION(...)` macro for filter gating
- `AddInstrumentation : WalkerPass<PostWalker<...>>`
- `visitLoad`
- `visitStore`
- `visitStructGet`
- `visitStructSet`
- `visitArrayGet`
- `visitArraySet`
- `visitMemoryGrow`
- `visitModule` for helper import injection
- `InstrumentMemory : Pass` with `addsEffects() == true`

So unlike many Binaryen passes with helper-heavy ownership graphs, this one is very concentrated.

## Rewrite mechanics by instruction family

### 1. Loads

For a load, Binaryen:

1. increments the shared `id`
2. finds the selected memory's address type (`i32` vs `i64`)
3. converts the static memarg offset into a const pointer literal of that address type
4. replaces the pointer with `call $load_ptr(id, bytes, offset, original_ptr)`
5. wraps the full resulting load in a typed value hook:
   - `load_val_i32`
   - `load_val_i64`
   - `load_val_f32`
   - `load_val_f64`

Unsupported load result types bail out after the pointer rewrite logic is staged in code but before replacement occurs; the source comment says `TODO: other types, unreachable, etc.`

### 2. Stores

For a store, Binaryen:

1. increments the shared `id`
2. rewrites the pointer via `store_ptr(id, bytes, offset, original_ptr)`
3. wraps the stored value in a typed helper call:
   - `store_val_i32`
   - `store_val_i64`
   - `store_val_f32`
   - `store_val_f64`

Unlike loads, the store node itself stays a store; only its pointer and value children are rewritten.

### 3. `memory.grow`

For `memory.grow`, Binaryen uses a pre/post pair:

- `memory_grow_pre(id, delta)` feeds the rewritten delta into the original `memory.grow`
- the whole grow expression is then wrapped by `memory_grow_post(id, memory.grow(...))`

This is the only non-load/store non-GC family in the pass.

### 4. `struct.get` / `struct.set`

These are only instrumented when the module has GC enabled and the field value type is one of:

- `i32`
- `i64`
- `f32`
- `f64`

`struct.get` becomes a typed wrapper call around the original get.
`struct.set` keeps the set but wraps the written value.

General reference payloads are not instrumented.

### 5. `array.get` / `array.set`

Again only under GC.

`array.get` and `array.set` are distinctive because they instrument **both**:

- the index, via `array_get_index` / `array_set_index`
- the scalar payload value, via `array_get_val_*` / `array_set_val_*`

That means one source instruction can consume **two IDs**, unlike ordinary loads, stores, struct gets, struct sets, and memory.grow which consume one each.

## ID numbering details

The pass uses one shared `Index id = 0` counter for the whole walk.

But the numbering pattern is not perfectly uniform:

- loads/stores/memory.grow do `id++` first, then use the incremented value, so the first such rewrite emits ID `1`
- struct/array GC helpers often use `builder.makeConst(int32_t(id++))`, so the first such rewrite can emit ID `0`
- array get/set can consume two IDs because the index and the value wrapper each get their own helper call

So the durable rule is:

- IDs are monotonic walk-order tags
- not stable semantic labels
- not always one-per-source instruction
- and not guaranteed to start at `1`

The official GC lit file makes this visible: the first `struct.get` uses ID `0`, while the first array index hook and array value hook then advance separately.

## Import roster

`visitModule` always injects the scalar helper imports:

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

If GC is enabled, it also injects:

- `struct_get_val_i32/i64/f32/f64`
- `struct_set_val_i32/i64/f32/f64`
- `array_get_val_i32/i64/f32/f64`
- `array_set_val_i32/i64/f32/f64`
- `array_get_index`
- `array_set_index`

All imports are added in module `env` with base name equal to the function name.

One important subtlety: import injection is keyed to module features, not to whether any matching instruction actually survives filter selection.
So a filtered run that instruments only `memory.grow` still gets the standard load/store helper imports too.
The dedicated filter lit file proves this.

## Filter contract

The pass argument is parsed from `getArgumentOrDefault("instrument-memory", "")`.
If the argument string is non-empty, it is split on commas into a string set.

Supported filter keys are the strings checked by the visit methods:

- `load`
- `store`
- `memory.grow`
- `struct.get`
- `struct.set`
- `array.get`
- `array.set`

Filtering happens per visit method through `CHECK_EXPRESSION(...)`.
If the current instruction family is not in the set, that visit method returns without rewriting.

The filter test proves:

- filtered-in load families are instrumented
- filtered-in `memory.grow` is instrumented
- filtered-out stores remain untouched
- helper imports are still injected even when stores are filtered out

## Memory64 behavior

The pass is memory-width aware.
It computes pointer and offset constants using the selected memory's `addressType`.

In the memory64 lit file, this changes:

- `load_ptr` / `store_ptr` signatures to use `i64` address and offset params
- `memory_grow_pre` / `memory_grow_post` to take and return `i64`
- emitted offset/address constants from `i32.const` to `i64.const`

The scalar load/store value hooks keep their normal value types.
Only the pointer-like pieces widen.

## GC behavior

The dedicated GC lit file proves that the pass is broader than ordinary linear memory instrumentation.
It also instruments:

- `struct.get`
- `struct.set`
- `array.get`
- `array.set`

but only for scalar value payloads.

This matters for teaching because the pass name sounds memory-only in the linear-memory sense, yet the real contract is closer to:

- memory and selected heap-access instrumentation

Still, the implementation is conservative:

- no general ref payload hooks
- no typed-funcref payload hooks
- no `v128` payload hooks
- no atomic GC variants here

## Effects and downstream interaction

`InstrumentMemory::addsEffects() override { return true; }`

That means the pass intentionally invalidates effect assumptions.
A memory load that used to be pure-looking from an optimizer's point of view becomes wrapped in imported calls.
So this pass belongs with tooling/debugging/instrumentation surfaces, not semantics-preserving optimization surfaces.

This also explains why the neighboring `instrument-locals` dossier had to mention `instrument-memory`: both are tiny passes whose main semantic consequence is "wrap operations in imported effectful observation helpers."

## Dedicated proof surface

### `instrument-memory.wast`

Primary scalar-memory coverage:

- all scalar load widths and sign modes
- scalar stores
- helper import signatures
- byte-width and offset payloads

### `instrument-memory-filter.wast`

Proves the optional filter argument and the fact that filtered-out families stay untouched while helper imports are still present.

### `instrument-memory-gc.wast`

Proves GC-only struct/array rewrite families and the scalar-only GC payload instrumentation boundary.

### `instrument-memory64.wast`

Proves address-type widening for memory64.

## Current-main drift

A direct raw-file diff check found **no diff** between `version_129` and current `main` for:

- `src/passes/InstrumentMemory.cpp`
- `test/lit/passes/instrument-memory.wast`
- `test/lit/passes/instrument-memory-filter.wast`
- `test/lit/passes/instrument-memory-gc.wast`
- `test/lit/passes/instrument-memory64.wast`

So `version_129` is a safe living oracle for this dossier.

## Porting / teaching checklist

A future faithful port should preserve:

- public pass identity separate from default optimization presets
- one shared postwalk ID stream
- pointer-prehook plus value-posthook split for loads
- pointer-prehook plus value-hook child rewrite for stores
- pre/post split for `memory.grow`
- GC struct/array scalar-only rewrite families
- filter-by-string-set behavior
- unconditional scalar helper import injection plus GC-conditional helper import injection
- memory64 address-type sensitivity
- `addsEffects() == true`
- the current unsupported atomic / ref-typed-payload boundaries

## Explicit repo-context note

`agent-todo.md` currently has **no dedicated `instrument-memory` slice**.
That is acceptable here because this thread's job was documentation expansion, not implementation planning.
But the raw note should record that absence so future port work does not assume a hidden backlog slice already exists.

## Source links

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/InstrumentMemory.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/instrument-memory.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/instrument-memory-filter.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/instrument-memory-gc.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/instrument-memory64.wast>
- <https://github.com/WebAssembly/binaryen/blob/main/src/passes/InstrumentMemory.cpp>
- <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/instrument-memory.wast>
- <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/instrument-memory-filter.wast>
- <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/instrument-memory-gc.wast>
- <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/instrument-memory64.wast>
