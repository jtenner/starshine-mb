# Binaryen `global-effects` current-main recheck

_Status:_ immutable focused source recheck for the `docs/wiki/binaryen/passes/global-effects/` dossier

This file captures a 2026-05-06 current-`main` recheck of the upstream `global-effects` surfaces. It asks one narrow question:

- did current `main` drift in any teaching-relevant way from the existing Binaryen `version_129` contract?

## Pages this manifest supports

- `docs/wiki/binaryen/passes/global-effects/index.md`
- `docs/wiki/binaryen/passes/global-effects/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/global-effects/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/global-effects/metadata-naming-and-consumers.md`
- `docs/wiki/binaryen/passes/global-effects/wat-shapes.md`
- `docs/wiki/binaryen/passes/global-effects/starshine-strategy.md`
- `docs/wiki/binaryen/passes/global-effects/starshine-port-readiness-and-validation.md`

## Primary sources rechecked

- `GlobalEffects.cpp`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/GlobalEffects.cpp>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GlobalEffects.cpp>
- `pass.cpp`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `effects.h`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/effects.h>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
- `wasm.h`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/wasm.h>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm.h>
- dedicated lit tests
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/vacuum-global-effects.wast>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/global-effects_simplify-locals.wast>

## Current-main line anchors from the 2026-05-06 spotcheck

- `GlobalEffects.cpp#L1006-L1035` - stale `PassOptions` comment, `FuncInfo` setup, and the shallow per-function summary shell
- `GlobalEffects.cpp#L1046-L1155` - parallel body scan plus direct-call and unknown-call classification
- `GlobalEffects.cpp#L1329-L1530` - SCC propagation, recursive-cycle trap marking, and per-function `Function.effects` writeback
- `pass.cpp#L2475-L2480` - public `discard-global-effects` registration
- `pass.cpp#L2558-L2561` - public `generate-global-effects` registration
- `pass.cpp#L3687-L3692` - explicit note that `generate-global-effects` still stays out of the default optimize sequence
- `effects.h#L3479-L3525` - direct-call effect lookup on the consumer side
- `vacuum-global-effects.wast#L332-L366` - downstream cleanup payoff shape
- `global-effects_simplify-locals.wast#L471-L543` - downstream locals-precision payoff shape

## Recheck result

The reviewed current-`main` sources still support the same teaching-level contract as the existing dossier:

- the pass still computes per-function summaries instead of rewriting WAT directly;
- the reviewed `pass.cpp` still keeps `generate-global-effects` outside the default optimize sequence;
- `GlobalEffects.cpp` still models shallow local effects plus transitive call propagation, with current-main SCC aggregation as the implementation shape;
- the stale `PassOptions` wording remains a comment-vs-implementation mismatch, not a behavior change;
- the downstream consumer tests still prove the same `vacuum` and `simplify-locals` payoff shapes.

No teaching-relevant current-`main` drift was recorded for the reviewed upstream contract.

## Source provenance

- [`../research/0502-2026-05-06-global-effects-current-main-recheck.md`](../research/0502-2026-05-06-global-effects-current-main-recheck.md)
