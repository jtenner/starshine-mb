---
kind: concept
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-discard-global-effects-implementation-test-map.md
  - ../../../raw/binaryen/2026-04-25-discard-global-effects-primary-sources.md
  - ../../../raw/binaryen/2026-04-24-global-effects-primary-sources.md
  - ../../../raw/research/0383-2026-04-26-discard-global-effects-implementation-test-map.md
  - ../../../raw/research/0353-2026-04-25-discard-global-effects-source-dossier.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./metadata-shapes.md
  - ./starshine-strategy.md
  - ../global-effects/implementation-structure-and-tests.md
  - ../vacuum/implementation-structure-and-tests.md
  - ../simplify-locals/implementation-structure-and-tests.md
---

# Upstream implementation structure and tests for `discard-global-effects`

## Main reviewed files

| File | What it proves | Why it matters |
| --- | --- | --- |
| `src/passes/GlobalEffects.cpp` | Owner file for both `GenerateGlobalEffects` and `DiscardGlobalEffects`; the cleanup pass iterates module functions and resets each stored `effects` summary | This is the direct algorithm oracle. |
| `src/passes/pass.cpp` | Public registration for `discard-global-effects` beside `generate-global-effects`, plus the pass-runner lifecycle hook that discards global effects before a pass that may add effects | This proves the cleanup is both user-visible and part of Binaryen's internal metadata invalidation story. |
| `src/passes/pass.h` | Pass capability surface, especially `addsEffects()` | This explains how Binaryen knows a later pass can make old global-effect summaries stale. |
| `src/wasm.h` | `Function` owns the optional effect-summary metadata | This proves the transformed state is function metadata, not WAT syntax. |
| `src/ir/effects.h` | Later `EffectAnalyzer` calls can consult a callee's stored summary | This proves stale metadata would change later optimizer decisions. |
| Binaryen Optimizer Cookbook | Maintainer-authored rule that effect-adding passes must say so because earlier global-effect analysis then has to be discarded | This is independent process evidence for the source-level lifecycle. |
| `test/lit/passes/vacuum-global-effects.wast` | Producer/consumer behavior where generated summaries let `vacuum` remove more | This indirectly proves why clearing stale summaries matters. |
| `test/lit/passes/global-effects_simplify-locals.wast` | Producer/consumer behavior where generated summaries affect `simplify-locals` | This gives a second consumer family without pretending `discard-global-effects` has its own WAT diff. |

## `GlobalEffects.cpp`

This file is the only real implementation owner for the cleanup sibling.

The important structure is deliberately small:

1. enter a module pass,
2. loop over all functions in `module->functions`,
3. clear each function's stored `effects` metadata,
4. do not inspect or rewrite expression trees.

That means the pass is best described as **metadata invalidation**. It is not a call optimizer, not a global optimizer, and not a dead-code pass.

## `pass.cpp`

This file proves two details that belong in any faithful port plan.

### Public pass name

Binaryen registers `discard-global-effects` as a public pass beside `generate-global-effects`. Users can request the cleanup directly.

### Automatic lifecycle hook

The pass runner also clears global-effect summaries before a pass that reports it may add effects. That matters because a transform can stale the metadata even when the user did not explicitly schedule `discard-global-effects`.

The practical rule is:

```text
old Function.effects summaries must not survive an effect-adding transform
```

## `pass.h`

`pass.h` owns the capability declaration used by the pass runner. The key concept for this dossier is `addsEffects()`: passes that can introduce calls, stores, traps, throws, or other relevant effects must advertise that capability.

For beginners, think of this as an invalidation flag. If a later pass can make a function less pure than before, any old “this function has no global effects” summary must be dropped before future consumers see it.

## `wasm.h` and `effects.h`

These two files explain why the pass has no obvious WAT diff.

- `wasm.h` shows the summary is stored on the `Function` object.
- `effects.h` shows later effect analysis can use that stored summary for direct calls.

So the changed state is:

```text
Function.effects: Some(summary) -> None
```

not:

```wasm
(call $x) -> (nop)
```

## Reviewed test surface

There is no dedicated `discard-global-effects.wast` expected-output file in the reviewed source set.

That absence is important but not alarming. A printed WAT test would usually show no difference, because the pass clears metadata that the text writer does not print.

Use these evidence tiers instead:

1. **direct source proof**: `GlobalEffects.cpp` resets all function summaries;
2. **lifecycle source proof**: `pass.cpp` / `pass.h` clear summaries before effect-adding passes;
3. **consumer proof**: `vacuum-global-effects.wast` and `global-effects_simplify-locals.wast` show stored summaries affect later optimization;
4. **future API proof**: a metadata-observing binding could assert summaries disappear after cleanup.

## Validation checklist

A future direct test should prove:

- modules with no summaries stay semantically unchanged,
- summaries created by `generate-global-effects` are gone after `discard-global-effects`,
- summaries are dropped before an `addsEffects()` pass runs,
- downstream consumers no longer use old facts after cleanup,
- printed WAT equality alone is not treated as a failure.

## Starshine implications

Current Starshine does not have Binaryen-style persistent `Function.effects` metadata. Its effect summaries are revision-keyed function-local HOT cache entries; see [`./starshine-strategy.md`](./starshine-strategy.md).

A faithful local pass only becomes meaningful after a persistent interprocedural `global-effects` producer exists. Until then, the correct local analogue is cache invalidation on HOT revision changes, not a public pass that clears nothing.

## Sources

- [`../../../raw/binaryen/2026-04-26-discard-global-effects-implementation-test-map.md`](../../../raw/binaryen/2026-04-26-discard-global-effects-implementation-test-map.md)
- [`../../../raw/binaryen/2026-04-25-discard-global-effects-primary-sources.md`](../../../raw/binaryen/2026-04-25-discard-global-effects-primary-sources.md)
- [`../../../raw/research/0383-2026-04-26-discard-global-effects-implementation-test-map.md`](../../../raw/research/0383-2026-04-26-discard-global-effects-implementation-test-map.md)
