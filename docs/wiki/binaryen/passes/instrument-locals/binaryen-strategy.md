---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0227-2026-04-21-instrument-locals-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/InstrumentLocals.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./unsupported-types-effects-and-import-roster.md
  - ./wat-shapes.md
  - ../global-effects/index.md
---

# Binaryen strategy for `instrument-locals`

## One-sentence contract

Binaryen `version_129` `instrument-locals` is a small effectful postwalk pass that wraps supported `local.get` and `local.set` / `local.tee` traffic in imported identity-style helper calls and injects those helpers into the module.

## Public pass identity

`pass.cpp` registers:

- `instrument-locals`
  - description: instrument the build with code to intercept all loads and stores

That help text is slightly broader than the actual owner file.
The reviewed implementation only touches **locals**.
It does not instrument memory loads and stores here; that is the neighboring `instrument-memory` family.

## Main algorithm shape

## Phase 1: declare the helper-name surface

`InstrumentLocals.cpp` starts by defining stable helper names for both get and set sides:

- scalar helpers: `get_i32`, `get_i64`, `get_f32`, `get_f64`, `set_i32`, `set_i64`, `set_f32`, `set_f64`
- SIMD helpers: `get_v128`, `set_v128`
- reference helpers: `get_funcref`, `set_funcref`, `get_externref`, `set_externref`

That name surface matters because the pass later injects matching `env` imports for the supported feature set.

## Phase 2: declare the pass as effectful

The pass overrides:

- `addsEffects() -> true`

That is a real semantic boundary.
Once instrumentation inserts imported calls into the module, Binaryen must assume those calls may have effects.
The dedicated `instrument-locals_effects.wast` file proves the downstream consequence: previously computed global-effects information is no longer usable for the same cleanup opportunities.

## Phase 3: rewrite supported `local.get`

For each visited `LocalGet`, Binaryen chooses a helper import based on the get's type.

### Positive type surface for gets

Plain supported scalar cases:

- `i32`
- `f32`
- `f64`

Feature-gated / reference cases:

- `v128` when SIMD is enabled
- nullable `funcref`
- nullable `externref`

### Explicit no-op and hard-boundary cases for gets

- `i64` immediately returns unchanged (`TODO`)
- general reference types hit `WASM_UNREACHABLE("TODO: general reference types")`
- `none` and `unreachable` are treated as impossible here

### Rewritten shape for gets

The original node is replaced by:

- `call $get_TYPE(i32.const call_id, i32.const local_id, original_local_get)`

The helper result type matches the original local-get type, so the rewritten node can remain in value position.

## Phase 4: rewrite supported `local.set` / `local.tee`

`visitLocalSet` keeps the outer local-write node and rewrites only its value child.

### First boundary: skip `Pop`

If the value is `Pop`, the pass returns immediately.
The source comment explains why:

- `pop` is created when reading binary and deleted when writing binary,
- so it does not compose safely with local instrumentation.

That is why the legacy-EH test file exists.

### Second boundary: skip typed function references on sets

If the value is a function reference but not heap type `func`, the pass returns early with a `FIXME: support typed function references` note.
So typed function references are not part of the current rewrite surface.

### Positive type surface for sets

Plain supported scalar cases:

- `i32`
- `f32`
- `f64`

Feature-gated / reference cases:

- `v128` when SIMD is enabled
- nullable `funcref`
- nullable `externref`

### Explicit no-op and hard-boundary cases for sets

- `i64` returns unchanged (`TODO`)
- `Type::unreachable` returns unchanged because there is nothing useful to instrument there
- general reference types outside nullable `funcref` / `externref` hit `WASM_UNREACHABLE`

### Rewritten shape for sets

The pass rewrites:

- `curr->value = call $set_TYPE(i32.const call_id, i32.const local_id, old_value)`

and leaves the outer `local.set` / `local.tee` in place.

That means the helper is an identity-through-interception function whose result becomes the stored value.

## Phase 5: use one shared call-id counter

The pass keeps one private field:

- `Index id = 0;`

Both get and set rewrites use `id++`.
So call IDs are:

- monotonic across the whole pass run
- shared across gets and sets
- not reset per function
- not grouped per local index

The all-features lit file shows this in the emitted sequence of `i32.const 0`, `1`, `2`, ... for mixed accesses.

## Phase 6: inject helper imports at module scope

`visitModule` adds helper imports to the module.

### Unconditional scalar/helper imports

Always added:

- `get_i32`, `get_i64`, `get_f32`, `get_f64`
- `set_i32`, `set_i64`, `set_f32`, `set_f64`

### Feature-gated helper imports

Added when reference types are enabled:

- `get_funcref`, `set_funcref`
- `get_externref`, `set_externref`

Added when SIMD is enabled:

- `get_v128`, `set_v128`

### Important surprise: helper roster is broader than rewrite coverage

Even though `visitLocalGet` and `visitLocalSet` currently leave ordinary `i64` traffic untouched, `visitModule` still injects:

- `get_i64`
- `set_i64`

The dedicated all-features lit file proves that split directly.
This is one of the easiest parts of the pass to mis-teach.

## Helper ABI and import construction

`addImport(...)` constructs each helper as an `env` import using `Builder::makeFunction(...)`.

All helpers have the same shape template:

- params: `(i32 call_id, i32 local_id, value)`
- results: `value`

So the pass assumes imported helpers that can:

- observe the access,
- potentially log or intercept it,
- and then hand the value back unchanged in type shape.

## What this pass does **not** do

The reviewed `version_129` source does **not** do any of these things here:

- instrument memory loads or stores
- instrument arbitrary expression results
- instrument all reference types
- instrument ordinary `i64` local traffic yet
- instrument `Pop`
- preserve existing global-effects summaries
- perform local optimization or cleanup

Those non-goals matter because the pass name can sound broader than its real implementation.

## Practical neighboring-pass interactions

The most important neighboring-pass interaction is with `generate-global-effects` and later cleanup such as `vacuum`.

Because `instrument-locals` adds imported calls and declares itself effectful:

- code that previously looked removable after a local write may stop being removable,
- and Binaryen conservatively discards prior global-effects metadata rather than tracking instrumentation on a per-function basis.

That exact interaction is the point of `instrument-locals_effects.wast`.

## Current-source drift note

A 2026-04-21 spot check found the reviewed `version_129` owner file and all three dedicated lit files unchanged on current `main`.
So the tagged release contract here is still current on the inspected surfaces.
