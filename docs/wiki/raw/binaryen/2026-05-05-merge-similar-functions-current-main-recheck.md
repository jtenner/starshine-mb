# Binaryen `merge-similar-functions` current-main recheck

_Capture date:_ 2026-05-05  
_Status:_ immutable current-main source bridge for the `docs/wiki/binaryen/passes/merge-similar-functions/` dossier

## Scope

This file records the primary online sources rechecked for the 2026-05-05 `merge-similar-functions` wiki-health pass.
It extends, rather than replaces, the earlier tagged-source manifest in `docs/wiki/raw/binaryen/2026-04-25-merge-similar-functions-primary-sources.md` and the earlier research note in `docs/wiki/raw/research/0332-2026-04-25-merge-similar-functions-primary-sources-and-starshine-followup.md`.
Use the living pages for the teachable contract:

- `docs/wiki/binaryen/passes/merge-similar-functions/index.md`
- `docs/wiki/binaryen/passes/merge-similar-functions/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/merge-similar-functions/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/merge-similar-functions/equivalence-classes-param-derivation-and-thunk-rewrites.md`
- `docs/wiki/binaryen/passes/merge-similar-functions/profitability-indirection-and-type-barriers.md`
- `docs/wiki/binaryen/passes/merge-similar-functions/wat-shapes.md`
- `docs/wiki/binaryen/passes/merge-similar-functions/starshine-strategy.md`
- `docs/wiki/binaryen/passes/merge-similar-functions/starshine-port-readiness-and-validation.md`

## Official sources consulted

### Binaryen `main`

- `MergeSimilarFunctions.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/MergeSimilarFunctions.cpp>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/MergeSimilarFunctions.cpp>
- `pass.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- `hashed.h`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/hashed.h>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/ir/hashed.h>
- `manipulation.h`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/manipulation.h>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/ir/manipulation.h>
- `module-utils.h`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/module-utils.h>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/ir/module-utils.h>
- `names.h`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/names.h>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/ir/names.h>
- `wasm-limits.h`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/wasm-limits.h>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/wasm-limits.h>
- Dedicated lit tests
  - `merge-similar-functions.wast`
  - `merge-similar-functions_all-features.wast`
  - `merge-similar-functions_types.wast`
  - `merge-similar-functions-param-limit.wast`

### Tagged comparison anchor

- `MergeSimilarFunctions.cpp` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MergeSimilarFunctions.cpp>
- `pass.cpp` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `hashed.h` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/hashed.h>
- `manipulation.h` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/manipulation.h>
- `module-utils.h` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.h>
- `names.h` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/names.h>
- `wasm-limits.h` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-limits.h>
- Tests at `version_129`: the four dedicated lit files listed above.

## Durable observations

- Current `main` still exposes `merge-similar-functions` as the same late whole-module shrink pass: the core owner remains `src/passes/MergeSimilarFunctions.cpp`, the public pass constructor remains in `pass.cpp`, and the registry/scheduler surface remains unchanged on the reviewed path.
- The current-main source still teaches the same helper-plus-thunk family already captured from `version_129`: hash prefiltering, exact class splitting, lockstep diff-vector derivation, helper cloning, thunk replacement, and the `255` synthetic-param limit.
- The same high-value correctness boundaries remain visible in the official sources: import/signature/local-count mismatches bail out early, repeated diff-vectors reuse one synthetic param, direct-callee parameterization is feature-gated by reference types plus GC, and profitability can leave a legal class unchanged.
- The dedicated current-main lit files still exercise the same beginner-through-advanced teaching families: constant-wrapper positives, local-index repair, feature-gated call-target indirection, all-features tail-call cases, and the param-limit boundary.
- No teaching-relevant drift was found in this focused recheck on the reviewed owner and test surfaces.
- The local Starshine status is unchanged by this source refresh: `merge-similar-functions` remains a removed-registry known name and explicit requests are still rejected before any hot or module pass executes.

## Uncertainty and follow-up

- This recheck is source-level and documentation-focused. It does not assert byte-for-byte equivalence between `version_129` and current `main`; it only records that the reviewed public contract and teaching examples did not change in a way that affects Starshine wiki guidance.
- The local status correction in this run is separate from the upstream source refresh: the pass is removed-registry in Starshine, not boundary-only.
