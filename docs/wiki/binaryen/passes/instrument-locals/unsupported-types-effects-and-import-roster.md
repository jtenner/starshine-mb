---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-instrument-locals-primary-sources.md
  - ../../../raw/research/0287-2026-04-24-instrument-locals-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0227-2026-04-21-instrument-locals-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/InstrumentLocals.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/instrument-locals_all-features_disable-gc.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/instrument-locals_effects.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/instrument-locals-eh-legacy.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./starshine-strategy.md
  - ../global-effects/index.md
---

# `instrument-locals`: unsupported types, effect invalidation, and the helper-import roster

This page covers the part of `instrument-locals` that is easiest to misread if you only skim the pass name. The source set is now captured in [`../../../raw/binaryen/2026-04-24-instrument-locals-primary-sources.md`](../../../raw/binaryen/2026-04-24-instrument-locals-primary-sources.md).

## 1. The helper roster is broader than the actual rewrite surface

`visitModule(...)` always injects scalar helper imports for:

- `get_i32`, `get_i64`, `get_f32`, `get_f64`
- `set_i32`, `set_i64`, `set_f32`, `set_f64`

But the get/set visitors still do this for ordinary `i64` local traffic:

- `return; // TODO`

So a transformed module can contain:

- imported `get_i64` / `set_i64` helper declarations,
- but unchanged raw `local.get` / `local.set` over `i64` locals.

The dedicated all-features lit file proves exactly that surprising split.

This is the single most important beginner correction in the folder.

## 2. Reference support is intentionally narrow

The pass does **not** instrument all reference types.

### Positive reference cases

- nullable `funcref`
- nullable `externref`

### Negative reference cases

- general reference types hit a `WASM_UNREACHABLE("TODO: general reference types")` path on gets
- typed function references are explicitly skipped on sets

So the reviewed contract is not "reference-types aware" in a general sense.
It is a much narrower `funcref` / `externref` instrumentation surface.

## 3. SIMD support is feature-gated but real

When SIMD is enabled, the pass injects and uses:

- `get_v128`
- `set_v128`

So `instrument-locals` is not purely scalar.
But that support is still opt-in through the module feature set.

## 4. `Pop` is intentionally left alone

The owner-file comment and the dedicated legacy-EH lit file agree on a narrow safety rule:

- `local.set ... (pop ...)` must not be instrumented.

The reason is serialization-driven, not arbitrary:

- `pop` is generated when reading binary,
- and deleted when writing binary,
- so wrapping it with local get/set instrumentation would not compose cleanly.

## 5. `unreachable` local-set values are also left alone

`visitLocalSet` returns early on:

- `Type::unreachable`

That is another narrow safety / usefulness boundary.
If the assigned value is already unreachable, there is no meaningful identity-through-helper observation to preserve.

## 6. Why `addsEffects()` matters so much

This pass overrides:

- `addsEffects() -> true`

That means Binaryen must treat the newly inserted helper calls as potentially effectful imported calls.
The result is visible in `instrument-locals_effects.wast`:

- without instrumentation, a local-only helper function can become fully vacuumable after effect analysis;
- with instrumentation, the inserted import call blocks the same cleanup;
- and Binaryen conservatively discards global-effects knowledge more broadly instead of trying to track instrumentation on a per-function basis.

So `instrument-locals` is not merely adding debugging decoration.
It changes what later optimization passes are allowed to remove.

## 7. The pass is intentionally instrumentation, not optimization

Several nearby passes try to erase, sink, or canonicalize local traffic.
`instrument-locals` does the opposite:

- it makes local traffic more observable,
- grows the module import surface,
- and increases effectfulness.

That is why this folder should stay explicitly separated from:

- `simplify-locals*`
- `untee`
- `coalesce-locals`
- `local-cse`

## Practical rule of thumb

If you see a Binaryen-transformed module with:

- new `env` helper imports,
- wrapped `local.get` and `local.set` values,
- unchanged raw `i64` local traffic,
- and less-aggressive later `vacuum` cleanup,

that is exactly what the reviewed Binaryen `instrument-locals` contract predicts.

Current Starshine will not produce this shape because it does not implement or reserve the pass; see [`./starshine-strategy.md`](./starshine-strategy.md).
