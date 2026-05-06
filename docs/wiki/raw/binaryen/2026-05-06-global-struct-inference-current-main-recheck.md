# Binaryen `global-struct-inference` current-main recheck

_Capture date:_ 2026-05-06  
_Status:_ immutable current-main source bridge for the `docs/wiki/binaryen/passes/global-struct-inference/` dossier

## Scope

This bridge refreshes the existing `global-struct-inference` dossier against current Binaryen `main` on the same owner, scheduler, helper, and dedicated-fixture surfaces used by the earlier 2026-04-25 source capture.
It is a no-drift recheck layered on top of the corrected `version_129` reading.

## Official primary sources rechecked

- `GlobalStructInference.cpp`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/GlobalStructInference.cpp>
  - current `main` raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/GlobalStructInference.cpp>
- `pass.cpp`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - current `main` raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- `gsi.wast`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/gsi.wast>
  - current `main` raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/gsi.wast>
- `gsi-desc.wast`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/gsi-desc.wast>
  - current `main` raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/gsi-desc.wast>

## Source-location notes

The checked current-main surfaces still show the same teaching-important structure as the corrected `version_129` contract:

- `GlobalStructInference.cpp` still keeps the same open-world direct-global fast path plus the closed-world `typeGlobals` analysis split, with `requiresNonNullableLocalFixups()` still returning false and the same refinalize/rewrite style contract on the reviewed lines.
- `pass.cpp` still registers the plain `gsi` pass and keeps it in the same early global/module neighborhood.
- `gsi.wast` still provides the broad direct proof surface for the plain pass.
- `gsi-desc.wast` still covers the shared descriptor-read and un-nesting machinery that the plain pass also uses.

## Recheck result

No teaching-relevant current-`main` drift was found.
The current-main surfaces checked on 2026-05-06 still support the same durable contract taught from the corrected 2026-04-25 dossier:

- `gsi` remains layered open-world direct-global optimization plus closed-world candidate-global reasoning.
- `optimize(module)` still runs after the optional closed-world analysis.
- the direct-global path, candidate-grouping path, packed-field repair, atomic-read handling, and un-nesting story are still present on the reviewed owner and lit surfaces.

## Explicit non-changes

The recheck did **not** find evidence to teach any of these as current Binaryen behavior:

- a pass-local general-purpose object-dataflow engine;
- a closed-world-only pass contract;
- a multi-global `select` fallback for arbitrary non-constant expressions;
- a scheduler move that would make `gsi` part of the repo's current open-world no-DWARF path.

## Uncertainties to preserve

- This is a focused source-surface recheck, not a full semantic diff across all Binaryen history after `version_129`.
- The helper-owned type and descriptor rewrite still depends on broad GC/type infrastructure, so this bridge does not replace the older source-correction or port-readiness notes.
- Starshine still keeps a narrower closed-world direct-global subset in-tree; the exact local status remains a separate page.
