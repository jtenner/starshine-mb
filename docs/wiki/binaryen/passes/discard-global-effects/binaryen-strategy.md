---
kind: concept
status: supported
last_reviewed: 2026-07-11
sources:
  - https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/GlobalEffects.cpp
  - ../../../raw/research/0460-2026-05-05-discard-global-effects-current-main-recheck.md
  - ../../../raw/research/0493-2026-05-05-discard-global-effects-current-main-line-anchor-refresh.md
  - ../../../raw/research/0353-2026-04-25-discard-global-effects-source-dossier.md
  - ./index.md
related:
  - ./implementation-structure-and-tests.md
  - ./metadata-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../global-effects/binaryen-strategy.md
---

# Binaryen strategy for `discard-global-effects`

## One-sentence strategy

Binaryen's `discard-global-effects` walks the module's functions and clears stored global-effect summaries, leaving Wasm code and declarations unchanged.

## Source-backed algorithm

The reviewed `version_129` implementation lives in `src/passes/GlobalEffects.cpp`, the same owner file as `generate-global-effects`.

The strategy is intentionally tiny:

1. enter the module-level pass,
2. iterate over every function in the module,
3. reset the function's optional global-effect summary,
4. return without rewriting instruction bodies.

`src/passes/pass.cpp` registers `discard-global-effects` as a public pass next to `generate-global-effects`, making the cleanup lifecycle explicit rather than hidden. The same pass-runner layer also clears stored global-effect summaries before a pass that reports it can add effects, using the `addsEffects()` capability surfaced from `src/passes/pass.h`.

## Current-main semantic anchors

Current `main` is deliberately routed through stable owner symbols rather than brittle line numbers:

- `GlobalEffects.cpp`, `DiscardGlobalEffects::run(Module*)` - loops over module functions and clears each `Function::effects` field.
- `pass.cpp`, public-pass registration - retains the `discard-global-effects` spelling.
- `pass.cpp`, `PassRunner::handleAfterEffects(...)` - owns the automatic `addsEffects()` invalidation path.
- `pass.cpp`, default-pipeline TODO - preserves the boundary that global-effect producer/cleanup work is not silently a standard default-pipeline phase.

The direct source URLs in Binaryen current-main [`GlobalEffects.cpp`](https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/GlobalEffects.cpp) and [`pass.cpp`](https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp) define this scope.

## Why the pass exists

`generate-global-effects` lets later effect-sensitive passes treat direct calls more precisely than a generic opaque call. That is powerful but only while the summaries are valid.

If a later pass adds a call, store, trap path, throw path, memory operation, or global mutation, old summaries can become wrong. `discard-global-effects` is the public mechanism for erasing those facts, while Binaryen's pass runner uses the same invalidation rule automatically for passes that declare they may add effects.

The Binaryen Optimizer Cookbook reinforces this lifecycle: passes that may add effects must report that capability so earlier global-effect analysis is discarded before they run. The public cleanup pass and the pass-authoring rule tell the same story from two directions.

## What it does not do

`discard-global-effects` does not:

- recompute summaries,
- inspect instruction effects,
- remove dead calls,
- canonicalize locals,
- change validation types,
- strip custom sections,
- edit names or ABI-visible declarations.

Those behaviors belong to other passes.

## Important correctness rule

The pass must be broad rather than clever. Clearing all function summaries is safer than trying to prove which summaries survived an arbitrary transform.

The important observed invariant is:

```text
after discard-global-effects, no later pass can observe an old Function.effects summary
```

Do not widen that claim without evidence. The current implementation resets the per-function field; the producer also owns module-level indirect-call analysis state, but the public cleanup loop is not source proof that it resets that separate state.

## Current-main status

A 2026-07-11 focused recheck of Binaryen `main` found no behavior-bearing drift for the cleanup sibling itself. Current `main` still publicly registers the pass, resets `Function.effects` for every function, and keeps the pass-runner invalidation path for effect-adding passes. The recheck also preserves the default-pipeline boundary: Binaryen still does not silently make producer/cleanup a standard phase merely because the metadata exists.

The sibling producer `generate-global-effects` still has the known implementation-shape drift in current `main` versus `version_129`: it now uses an SCC/call-graph propagation structure. The retained 2026-05-05 current-main recheck records that drift, but it does not change `discard-global-effects`' cleanup contract.

The 2026-07-11 recheck supersedes the older freshness claim; it does not alter the pass model, but it makes the `Function.effects` field boundary explicit.

## Testing and validation implications

A standalone expected-output WAT test is a weak oracle because the pass does not need to change printed WAT.

Better tests are composed:

- generate summaries,
- show a later consumer can use them,
- mutate effects or explicitly discard summaries,
- show future consumers no longer trust the old facts.

The reviewed source set did not reveal a dedicated `discard-global-effects.wast` lit file, so this dossier treats source reading plus lifecycle reasoning as the primary evidence.

## Relationship to `global-effects`

Keep the split sharp:

| Pass | Upstream name | Main action | Typical visible effect |
| --- | --- | --- | --- |
| producer | `generate-global-effects` | writes per-function summaries | later passes may optimize more |
| cleanup sibling | `discard-global-effects` | clears per-function summaries | printed module may be unchanged |

See [`../global-effects/binaryen-strategy.md`](../global-effects/binaryen-strategy.md) for the producer strategy.

## Sources

- Binaryen current-main [`GlobalEffects.cpp`](https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/GlobalEffects.cpp)
- [`../../../raw/research/0460-2026-05-05-discard-global-effects-current-main-recheck.md`](../../../raw/research/0460-2026-05-05-discard-global-effects-current-main-recheck.md)
- [`../../../raw/research/0383-2026-04-26-discard-global-effects-implementation-test-map.md`](../../../raw/research/0383-2026-04-26-discard-global-effects-implementation-test-map.md)
- [`../../../raw/research/0353-2026-04-25-discard-global-effects-source-dossier.md`](../../../raw/research/0353-2026-04-25-discard-global-effects-source-dossier.md)
