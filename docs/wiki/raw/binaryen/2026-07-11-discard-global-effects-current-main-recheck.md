---
kind: source-capture
status: supported
last_reviewed: 2026-07-11
sources:
  - https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/GlobalEffects.cpp
  - https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/wiki/Optimizer-Cookbook
related:
  - ../../binaryen/passes/discard-global-effects/index.md
  - ../../binaryen/passes/discard-global-effects/binaryen-strategy.md
  - ../../binaryen/passes/discard-global-effects/implementation-structure-and-tests.md
  - ../../binaryen/passes/discard-global-effects/starshine-strategy.md
  - ../../binaryen/passes/global-effects/index.md
---

# Binaryen `discard-global-effects` current-main recheck

_Captured:_ 2026-07-11  
_Scope:_ current Binaryen `main` owner, public registration, pass-runner invalidation, maintainer lifecycle guidance, and the current Starshine analogue.

## Official sources rechecked

- Binaryen current-main [`GlobalEffects.cpp`](https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/GlobalEffects.cpp)
  - `DiscardGlobalEffects::run(Module*)` still loops over `module->functions` and calls `func->effects.reset()` for every function.
  - The producer remains in the same owner file. It computes call-graph/SCC information and may populate `Function::effects` plus `module->indirectCallEffects`; that producer complexity does **not** widen the cleanup pass itself.
- Binaryen current-main [`pass.cpp`](https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp)
  - The public spelling remains `discard-global-effects`, described as discarding global-effect information.
  - `PassRunner::handleAfterEffects(...)` still resets a function's cached global effect summary when a Binaryen-IR-mutating pass advertises `addsEffects()`.
  - The default-pipeline TODO still says that the benefit of automatically placing generate/discard global effects appears minor except for cases such as `call.without.effects`; neither producer nor cleanup is silently scheduled as a standard default-pipeline phase.
- Binaryen's maintainer-authored [Optimizer Cookbook](https://github.com/WebAssembly/binaryen/wiki/Optimizer-Cookbook)
  - Global effects are not automatically recomputed after ordinary optimization passes because those normally only remove effects.
  - A special pass that adds effects must declare `addsEffects`, after which Binaryen automatically discards global effect information.

## Durable current contract

The cleanup pass is still a deliberately small **metadata invalidation pass**:

```text
for every Function in module.functions:
  Function.effects = absent

Wasm bodies, declarations, and printable WAT = unchanged
```

This is not equivalent to clearing every producer-side artifact. In particular, the current source confirms that `DiscardGlobalEffects` resets each `Function::effects` field; it does not itself clear `module->indirectCallEffects`. The latter belongs to the producer's indirect-call analysis state and must not be claimed as an observed cleanup mutation without a separate source/test proof.

## Reconciliation with older captures

- The 2026-05-05 capture correctly described the per-function `effects.reset()` loop, public registration, and `addsEffects()` invalidation rule.
- Its broad phrase “clears stored global-effect summaries” remains correct **only when read as function summaries**. This recheck records the narrower exact field boundary so readers do not infer that the public cleanup pass necessarily clears every module-level producer cache.
- The current owner/registration/lifecycle sources show no behavior-bearing drift from the documented cleanup contract. The source-file comment claiming effects are stored on `PassOptions` remains stale relative to the actual `Function::effects` mutation and should not be used as an ownership description.

## Starshine boundary rechecked

Repository evidence remains sufficient for local status; no executable behavior changed.

- [`src/passes/optimize.mbt`](../../../../src/passes/optimize.mbt) has no `discard-global-effects` spelling. Its boundary-only `global-effects` name is the producer-side compatibility boundary, not this cleanup sibling.
- [`src/ir/analysis_cache.mbt`](../../../../src/ir/analysis_cache.mbt) stores `HotEffectsSummary` in a `HotCacheEntry` keyed by `hot_revision_current(func)` and rebuilds it on a changed revision.
- [`src/passes/pass_common.mbt`](../../../../src/passes/pass_common.mbt) invalidates all HOT analysis cache entries when a pass marks a function mutated.

So the current Starshine analogue is revision-keyed local-cache invalidation. It is not a persistent interprocedural `Function.effects` field, and a public local cleanup pass would not currently clear a Binaryen-equivalent state.

## Evidence and validation consequences

- A standalone WAT diff remains insufficient: successful cleanup normally produces identical Wasm text.
- A future Starshine port needs metadata-observer tests, then producer → cleanup → consumer composition tests.
- A future direct Binaryen test should distinguish the exact observed postcondition (`Function::effects` absent for every function) from unproven claims about `module->indirectCallEffects`.

## Uncertainty

This was a focused source reconciliation, not a full proof of every consumer's behavior or every possible `Function.effects` producer. The owner, public registration, invalidation hook, and Cookbook lifecycle rule were directly rechecked; any broader persistent-metadata design for Starshine still needs a separate module-analysis design and tests.
