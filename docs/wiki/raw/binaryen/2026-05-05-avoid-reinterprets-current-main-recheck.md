# Binaryen `avoid-reinterprets` current-main recheck

_Capture date:_ 2026-05-05  
_Status:_ immutable current-main source bridge for the `docs/wiki/binaryen/passes/avoid-reinterprets/` dossier

## Scope

This file records the official primary sources rechecked for the 2026-05-05 `avoid-reinterprets` wiki-health pass.
It extends, rather than replaces, the earlier tagged-source manifest in `docs/wiki/raw/binaryen/2026-04-24-avoid-reinterprets-primary-sources.md` and the earlier current-main bridge in `docs/wiki/raw/binaryen/2026-04-26-avoid-reinterprets-port-readiness-primary-sources.md`.
Use the living pages for the teachable contract:

- `docs/wiki/binaryen/passes/avoid-reinterprets/index.md`
- `docs/wiki/binaryen/passes/avoid-reinterprets/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/avoid-reinterprets/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/avoid-reinterprets/single-load-chains-and-bailouts.md`
- `docs/wiki/binaryen/passes/avoid-reinterprets/wat-shapes.md`
- `docs/wiki/binaryen/passes/avoid-reinterprets/starshine-strategy.md`
- `docs/wiki/binaryen/passes/avoid-reinterprets/starshine-port-readiness-and-validation.md`

## Official sources consulted

### Binaryen `main`

- `AvoidReinterprets.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/AvoidReinterprets.cpp>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/AvoidReinterprets.cpp>
- `pass.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- `local-graph.h`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/local-graph.h>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/ir/local-graph.h>
- `properties.h`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/properties.h>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/ir/properties.h>
- Dedicated lit test `avoid-reinterprets.wast`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/avoid-reinterprets.wast>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/avoid-reinterprets.wast>
- Dedicated lit test `avoid-reinterprets64.wast`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/avoid-reinterprets64.wast>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/avoid-reinterprets64.wast>

### Tagged comparison anchor

- `AvoidReinterprets.cpp` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/AvoidReinterprets.cpp>
- `pass.cpp` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `local-graph.h` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h>
- `properties.h` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
- `avoid-reinterprets.wast` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/avoid-reinterprets.wast>
- `avoid-reinterprets64.wast` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/avoid-reinterprets64.wast>

## Durable observations

- Current `main` still exposes the same `avoid-reinterprets` contract on the reviewed surfaces: a narrow extra-load rewrite that duplicates a full-width load in the reinterpret result type instead of becoming generic reinterpret elimination.
- The reviewed current-main lit surfaces still teach the same direct / indirect / mixed-use / partial-load / memory64 families already captured from `version_129`.
- No teaching-relevant drift was found in this focused recheck.
- The useful 2026-05-05 wiki change is therefore freshness plus local-code anchor hygiene, not a semantic rewrite of the existing strategy pages.

## Uncertainty and follow-up

- This recheck is source-level and documentation-focused. It does not assert byte-for-byte equivalence between `version_129` and current `main`; it only records that the reviewed public contract and teaching examples did not change in a way that affects Starshine wiki guidance.
- The local Starshine story is now active-partial rather than removed-name only: direct full-width `reinterpret(load)` flips are landed, while the indirect local-chain family remains future work.
