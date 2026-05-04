# Binaryen `precompute-propagate` current-main recheck

_Status:_ immutable focused source recheck for the `docs/wiki/binaryen/passes/precompute-propagate/` dossier

This file captures a 2026-05-04 current-`main` recheck of the upstream `precompute-propagate` surfaces. It narrows the earlier 2026-04-25 code-map refresh to a simple question: did the reviewed Binaryen sources drift in any teaching-relevant way from the existing dossier contract?

## Pages this manifest supports

- `docs/wiki/binaryen/passes/precompute-propagate/index.md`
- `docs/wiki/binaryen/passes/precompute-propagate/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/precompute-propagate/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/precompute-propagate/local-worklist-fallthrough-and-merge-boundaries.md`
- `docs/wiki/binaryen/passes/precompute-propagate/wat-shapes.md`
- `docs/wiki/binaryen/passes/precompute-propagate/starshine-strategy.md`
- `docs/wiki/binaryen/passes/precompute-propagate/starshine-port-readiness-and-validation.md`

## Primary sources rechecked

- `Precompute.cpp`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/Precompute.cpp>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Precompute.cpp>
- `pass.cpp`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `opt-utils.h`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/opt-utils.h>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- `local-graph.h`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/local-graph.h>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h>
- `wasm-interpreter.h`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/wasm-interpreter.h>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-interpreter.h>
- dedicated lit files
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/precompute-propagate-partial.wast>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/precompute-propagate_all-features.wast>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/precompute-propagate-partial.wast>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/precompute-propagate_all-features.wast>

## Recheck result

The reviewed current-`main` sources still support the same teaching-level contract as the existing dossier:

- public `precompute-propagate` remains a real upstream pass name;
- the implementation still shares the `Precompute.cpp` core with plain `precompute`;
- the propagate variant still adds a bounded `LazyLocalGraph`-driven local worklist;
- the variant still reruns the main walk once after propagation;
- the scheduler still uses the sibling for aggressive and nested post-inlining cleanup;
- the local Starshine side still treats the name as removed rather than implemented.

No new teaching-relevant drift was recorded for the reviewed surfaces.

## Source provenance

- [`../../research/0440-2026-05-04-precompute-propagate-current-main-recheck.md`](../../research/0440-2026-05-04-precompute-propagate-current-main-recheck.md)
