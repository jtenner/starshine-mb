# Binaryen `merge-similar-functions` primary-source capture

_Capture date:_ 2026-04-25  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/merge-similar-functions/` dossier

## Scope

This file captures the primary online sources consulted for the 2026-04-25 `merge-similar-functions` provenance and Starshine status follow-up. It is provenance-heavy rather than explanatory; use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/merge-similar-functions/index.md`
- `docs/wiki/binaryen/passes/merge-similar-functions/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/merge-similar-functions/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/merge-similar-functions/equivalence-classes-param-derivation-and-thunk-rewrites.md`
- `docs/wiki/binaryen/passes/merge-similar-functions/profitability-indirection-and-type-barriers.md`
- `docs/wiki/binaryen/passes/merge-similar-functions/wat-shapes.md`
- `docs/wiki/binaryen/passes/merge-similar-functions/starshine-strategy.md`

## Provenance

### Official release pages consulted

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Page observed on 2026-04-25.
  - GitHub showed the release as published **2026-04-01 14:31** and linked commit `d0e2be9`.
- Binaryen GitHub releases index
  - URL: <https://github.com/WebAssembly/binaryen/releases>
  - Page observed on 2026-04-25 as release-context support.

### Official source files consulted

- `src/passes/MergeSimilarFunctions.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MergeSimilarFunctions.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/MergeSimilarFunctions.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/MergeSimilarFunctions.cpp>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/MergeSimilarFunctions.cpp>
- `src/passes/pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- `src/pass.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/pass.h>

### Official helper and dependency files consulted

These files matter because `merge-similar-functions` is a module-level rewrite built from Binaryen's generic hashing, expression-comparison, cloning, naming, and limits helpers:

- `src/ir/hashed.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/hashed.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/hashed.h>
- `src/ir/manipulation.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/manipulation.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/manipulation.h>
- `src/ir/module-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.h>
- `src/ir/names.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/names.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/names.h>
- `src/wasm-limits.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-limits.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/wasm-limits.h>

### Official test files consulted

- `test/lit/passes/merge-similar-functions.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-similar-functions.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/merge-similar-functions.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/merge-similar-functions.wast>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/merge-similar-functions.wast>
- `test/lit/passes/merge-similar-functions_all-features.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-similar-functions_all-features.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/merge-similar-functions_all-features.wast>
- `test/lit/passes/merge-similar-functions_types.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-similar-functions_types.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/merge-similar-functions_types.wast>
- `test/lit/passes/merge-similar-functions-param-limit.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-similar-functions-param-limit.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/merge-similar-functions-param-limit.wast>

## Durable observations from the captured sources

- `merge-similar-functions` is a real public Binaryen pass registered in `src/passes/pass.cpp` and scheduled in the late global post-pass phase only when the shrink level is at least `2`.
- The owner file is `src/passes/MergeSimilarFunctions.cpp`; it defines the pass object, `EquivalentClass`, `ParamInfo`, hash grouping, equivalence-class formation, parameter derivation, benefit checks, helper construction, and thunk replacement.
- The source comment in the owner file frames the pass as parameterization of similar functions whose differences are constant payloads and call instruction targets, with post-link merging as the motivating setting.
- The implementation first groups candidate functions by a custom hash, then splits those buckets with structural equality that ignores only the intended difference sites.
- Candidate functions must be defined, have the same top-level function type, and have the same total local count before the deeper comparison is allowed to succeed.
- Synthetic parameters are derived by lockstep traversal over expression slots. Repeated equal per-function difference vectors reuse one parameter instead of creating one parameter per occurrence.
- Literal differences lower to constants in thunks; direct-callee differences lower to `ref.func` payloads only when reference types and GC make function-reference indirection available and the callee type constraints hold.
- Shared helpers are cloned from the primary function, append synthetic parameters after original parameters, rewrite differing sites to `local.get`, and must repair old non-param local indices after the signature grows.
- Original functions remain under their original names as thunks that call or tail-call the generated `byn$mgfn-shared$...` helper.
- Profitability and the `MaxSyntheticFunctionParams` limit are correctness-relevant public behavior for the pass: legal candidate classes still stay unchanged when helper-plus-thunk overhead is too large or the synthetic signature would exceed the limit.
- The dedicated lit files prove the main constant-wrapper positives, repeated-param reuse, local-index repair, feature/type-gated call-target indirection, all-features tail-call cases, and the param-limit boundary.
- A narrow 2026-04-25 current-`main` spot check did not reveal teaching-relevant drift in `src/passes/MergeSimilarFunctions.cpp` or the main dedicated test file. This is not a full audit of every helper dependency on trunk.
- Starshine-specific follow-up in this run did not find a local implementation file. The durable local fact is that `merge-similar-functions` is a **boundary-only** registry name and explicit requests are rejected before any hot or module pass executes.

## Uncertainties and contradictions

- Earlier research notes `0174` and `0201` agree with the core `version_129` source reading. This capture supersedes them only for raw-source provenance and current Starshine status, not for their historical rationale or detailed teaching notes.
- The local Batch 4 map names `merge-similar-functions`, but `agent-todo.md` currently has no active slice for it. Treat the wiki dossier as the durable planning source until an implementation slice exists.
- The current-main check was intentionally narrow. It supports keeping `version_129` as the teaching oracle for this dossier, but it does not prove all current trunk scheduler or helper behavior is unchanged.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages and the 2026-04-25 Starshine follow-up research note.
