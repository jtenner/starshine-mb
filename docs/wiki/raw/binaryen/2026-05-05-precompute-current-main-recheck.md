# Binaryen `precompute` current-main recheck

_Capture date:_ 2026-05-05  
_Status:_ immutable current-main source bridge for the `docs/wiki/binaryen/passes/precompute/` dossier

## Scope

This file records the primary online sources rechecked for the 2026-05-05 `precompute` wiki-health pass.
It extends, rather than replaces, the earlier tagged-source manifest in [`docs/wiki/raw/binaryen/2026-04-22-precompute-primary-sources.md`](../../../raw/binaryen/2026-04-22-precompute-primary-sources.md) and the earlier current-main bridge in [`docs/wiki/raw/binaryen/2026-04-26-precompute-current-main-port-readiness.md`](../../../raw/binaryen/2026-04-26-precompute-current-main-port-readiness.md).
Use the living pages for the teachable contract:

- `docs/wiki/binaryen/passes/precompute/index.md`
- `docs/wiki/binaryen/passes/precompute/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/precompute/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/precompute/propagation-partial-precompute-and-gc-identity.md`
- `docs/wiki/binaryen/passes/precompute/wat-shapes.md`
- `docs/wiki/binaryen/passes/precompute/starshine-hot-ir-strategy.md`
- `docs/wiki/binaryen/passes/precompute/starshine-port-readiness-and-validation.md`

## Official sources consulted

### Binaryen `main`

- `Precompute.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/Precompute.cpp>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/Precompute.cpp>
- `pass.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- `opt-utils.h`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/opt-utils.h>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/opt-utils.h>
- Representative lit surfaces:
  - `precompute.wast`
  - `precompute-propagate.wast`
  - `precompute-effects.wast`
  - `precompute-gc.wast`
  - `precompute-strings.wast`

### Tagged comparison anchor

- `Precompute.cpp` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Precompute.cpp>
- `pass.cpp` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `opt-utils.h` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- Representative lit surfaces at `version_129`:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/precompute.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/precompute-propagate.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/precompute-effects.wast>

## Durable observations

- Current `main` still exposes the same shared `Precompute.cpp` owner file for both public names, with the same plain-vs-propagate split recorded in `pass.cpp` and the same nested `precompute-propagate` scheduler boundary in `opt-utils.h`.
- The reviewed current-main surfaces still teach the same broad contract already captured from `version_129`: semantic compile-time evaluation, child-retention for needed writes, partial precompute for `select`, GC identity awareness, and refinalization after rewrite.
- The dedicated current-main lit families still back the same teaching split between plain arithmetic/effects, partial precompute, GC identity, strings, and sibling propagation behavior.
- No teaching-relevant drift was found in this focused recheck. The useful 2026-05-05 wiki change is therefore freshness and reference hygiene, not a semantic rewrite of the existing strategy pages.

## Uncertainty and follow-up

- This recheck is source-level and documentation-focused. It does not assert byte-for-byte equivalence between `version_129` and current `main`; it only records that the reviewed public contract and teaching examples did not change in a way that affects Starshine wiki guidance.
- The local Starshine status is unchanged by this source recheck: `precompute` remains an active HOT pass, and `precompute-propagate` remains its separate sibling with the same shared owner file.
