---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-instrument-locals-primary-sources.md
  - ../../../raw/research/0287-2026-04-24-instrument-locals-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0227-2026-04-21-instrument-locals-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/InstrumentLocals.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/instrument-locals_all-features_disable-gc.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/instrument-locals_effects.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/instrument-locals-eh-legacy.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./unsupported-types-effects-and-import-roster.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
---

# `instrument-locals` implementation structure and tests

The immutable primary-source manifest for this owner/test map is [`../../../raw/binaryen/2026-04-24-instrument-locals-primary-sources.md`](../../../raw/binaryen/2026-04-24-instrument-locals-primary-sources.md).

## Owner file map

## `src/passes/InstrumentLocals.cpp`

This is the real owner file for the pass.
It contains:

- the helper import name constants
- the `InstrumentLocals` `WalkerPass<PostWalker<...>>`
- `addsEffects()`
- `visitLocalGet(...)`
- `visitLocalSet(...)`
- `visitModule(...)`
- the private `id` counter
- the `addImport(...)` helper
- the public factory `createInstrumentLocalsPass()`

There is no second major analysis file hiding the algorithm elsewhere.
The reviewed public contract is overwhelmingly concentrated here.

## `src/passes/pass.cpp`

`pass.cpp` is the public registration surface.
It proves that Binaryen exposes a real CLI pass name:

- `instrument-locals`

with public help text and a direct factory hook.
That matters because this is not an internal debugging-only helper hidden behind another pass.

## `src/passes/passes.h`

`passes.h` is the declaration surface for:

- `createInstrumentLocalsPass()`

This is a tiny detail, but it confirms that the pass belongs to the ordinary public pass roster rather than a one-off tool entrypoint.

## Dedicated proof surface in shipped tests

## `test/lit/passes/instrument-locals_all-features_disable-gc.wast`

This is the broad main proof file.
It demonstrates:

- helper type declarations and helper import injection
- scalar positive rewrites for `i32`, `f32`, and `f64`
- nullable `funcref` and `externref` rewrites with reference types enabled but GC disabled
- SIMD `v128` rewrites when SIMD is enabled
- mixed get/set call-id sequencing
- the practical `i64` gap: helper imports exist, but ordinary `i64` local traffic stays uninstrumented

This is the best single file for teaching the pass's real shape.

## `test/lit/passes/instrument-locals_effects.wast`

This is the neighboring-pass interaction proof file.
It demonstrates:

- `generate-global-effects -> instrument-locals -> vacuum` behaves more conservatively than a non-instrumenting lane
- Binaryen discards existing global-effects knowledge because the pass adds import calls
- a function that was previously vacuumable after local-only work can stop being vacuumable once instrumentation is inserted

This file is the clearest proof that `addsEffects() == true` is part of the real contract, not decoration.

## `test/lit/passes/instrument-locals-eh-legacy.wast`

This is the narrow EH safety file.
It demonstrates:

- `local.set` of a legacy-EH `pop` payload stays untouched

That is the direct official proof for the `Pop` skip rule documented in the owner file comment.

## What the dedicated tests do **not** imply

The lit files prove the public contract well, but they do **not** mean:

- every reference-typed local is instrumented
- `i64` instrumentation is complete
- the pass is effect-neutral
- the pass optimizes locals
- the pass instruments memory accesses

Those would all overstate what `InstrumentLocals.cpp` actually does.

## Current-`main` drift check

A 2026-04-24 spot check re-reviewed these surfaces between `version_129` and current `main`:

- `src/passes/InstrumentLocals.cpp`
- `test/lit/passes/instrument-locals_all-features_disable-gc.wast`
- `test/lit/passes/instrument-locals_effects.wast`
- `test/lit/passes/instrument-locals-eh-legacy.wast`

No teaching-relevant contract drift was found on the inspected surfaces. This was a narrow source check, not a full upstream audit.

## Starshine implementation map

There is no local owner-file or test map yet because Starshine does not implement or reserve `instrument-locals` today.
For exact local registry/status locations, see [`./starshine-strategy.md`](./starshine-strategy.md).
