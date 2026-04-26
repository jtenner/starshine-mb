---
kind: source-capture
status: supported
last_reviewed: 2026-04-26
sources:
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GlobalEffects.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/GlobalEffects.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.h
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h
  - https://github.com/WebAssembly/binaryen/wiki/Optimizer-Cookbook
related:
  - ./2026-04-25-discard-global-effects-primary-sources.md
  - ./2026-04-24-global-effects-primary-sources.md
  - ../research/0383-2026-04-26-discard-global-effects-implementation-test-map.md
  - ../../binaryen/passes/discard-global-effects/index.md
  - ../../binaryen/passes/discard-global-effects/implementation-structure-and-tests.md
---

# Binaryen `discard-global-effects` implementation/test-map source bridge

Captured: 2026-04-26

## Source set

- `src/passes/GlobalEffects.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GlobalEffects.cpp>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/GlobalEffects.cpp>
  - Reviewed role: owner file for both `GenerateGlobalEffects` and `DiscardGlobalEffects`; the cleanup sibling's `run(...)` walks `module->functions` and calls `func->effects.reset()` on every function.
- `src/passes/pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - Reviewed role: public pass registration for `discard-global-effects` beside `generate-global-effects`, and the pass-runner lifecycle hook that discards stored global-effect summaries before a pass that may add effects runs.
- `src/passes/pass.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.h>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.h>
  - Reviewed role: pass capability API, especially `addsEffects()`, which explains why the pass runner can invalidate old global-effect facts automatically.
- `src/wasm.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm.h>
  - Reviewed role: `Function` owns an optional stored effect-summary pointer, proving the transformed state is function metadata rather than instruction syntax.
- `src/ir/effects.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
  - Reviewed role: `EffectAnalyzer` can read a callee function's stored summary, proving why stale summaries would affect later optimizer correctness.
- Optimizer Cookbook
  - <https://github.com/WebAssembly/binaryen/wiki/Optimizer-Cookbook>
  - Reviewed role: maintainer-authored pass-writing guidance that matches the source lifecycle: passes adding effects must expose that capability so old global-effect analysis is not reused unsafely.

## Durable facts captured

- `discard-global-effects` has one implementation owner file: `GlobalEffects.cpp`.
- The public pass registration is explicit in `pass.cpp`; this is not just an internal helper.
- The cleanup action is all-functions and metadata-only: reset each `Function.effects` summary, leave instruction bodies and declarations unchanged.
- The pass-runner can invoke the same cleanup lifecycle implicitly before passes that report `addsEffects()`, so the public pass and automatic invalidation hook are two surfaces of the same safety rule.
- There is still no dedicated expected-output `discard-global-effects.wast` in the reviewed source set. The strongest tests are therefore producer/consumer tests such as `vacuum-global-effects.wast` and `global-effects_simplify-locals.wast`, plus source-level tests if a downstream binding exposes metadata.

## Current-main drift note

The 2026-04-26 focused recheck found no teaching-relevant drift in the cleanup sibling. Current `main` still keeps the same public registration and summary-reset contract. The producer side of `GlobalEffects.cpp` has its separate SCC/call-graph drift already recorded in [`./2026-04-24-global-effects-primary-sources.md`](./2026-04-24-global-effects-primary-sources.md), but that does not change this cleanup contract.

## Uncertainty and contradiction notes

- The source-backed owner/test map remains asymmetric: the owner-file proof for `discard-global-effects` is direct, while the behavior proof is mostly lifecycle/consumer evidence because printed WAT normally does not change.
- The pass-runner automatic cleanup is broader than the public pass spelling. Docs should avoid implying users must always schedule `discard-global-effects` manually after every effect-adding pass; Binaryen also has internal invalidation through `addsEffects()`.
- Starshine has revision-keyed function-local HOT effect summaries, not Binaryen-style persistent module `Function.effects` metadata. A local public cleanup pass should remain a future design point unless persistent interprocedural effect summaries are added.
