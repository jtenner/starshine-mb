# Binaryen `dead-code-elimination` current-main recheck

_Capture date:_ 2026-05-05  
_Status:_ immutable current-main source bridge for the `docs/wiki/binaryen/passes/dead-code-elimination/` dossier

## Scope

This file records the primary online sources rechecked for the 2026-05-05 `dead-code-elimination` wiki-health pass.
It extends, rather than replaces, the earlier tagged-source manifest in `docs/wiki/raw/binaryen/2026-04-22-dead-code-elimination-primary-sources.md` and the earlier research follow-up in `docs/wiki/raw/research/0203-2026-04-21-dead-code-elimination-source-confirmation-followup.md`.
Use the living pages for the teachable contract:

- `docs/wiki/binaryen/passes/dead-code-elimination/index.md`
- `docs/wiki/binaryen/passes/dead-code-elimination/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/dead-code-elimination/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/dead-code-elimination/typed-control-voidification-and-eh.md`
- `docs/wiki/binaryen/passes/dead-code-elimination/wat-shapes.md`
- `docs/wiki/binaryen/passes/dead-code-elimination/starshine-strategy.md`
- `docs/wiki/binaryen/passes/dead-code-elimination/starshine-hot-ir-strategy.md`

## Official sources consulted

### Binaryen `main`

- `DeadCodeElimination.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/DeadCodeElimination.cpp>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/DeadCodeElimination.cpp>
- `pass.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- `dce_all-features.wast`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/dce_all-features.wast>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/dce_all-features.wast>
- `dce_vacuum_remove-unused-names.wast`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/dce_vacuum_remove-unused-names.wast>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/dce_vacuum_remove-unused-names.wast>
- `dce-eh.wast`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/dce-eh.wast>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/dce-eh.wast>
- `dce-eh-legacy.wast`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/dce-eh-legacy.wast>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/dce-eh-legacy.wast>
- `dce-stack-switching.wast`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/dce-stack-switching.wast>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/dce-stack-switching.wast>

### Tagged comparison anchor

- `DeadCodeElimination.cpp` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DeadCodeElimination.cpp>
- `pass.cpp` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `dce_all-features.wast` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dce_all-features.wast>
- `dce_vacuum_remove-unused-names.wast` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dce_vacuum_remove-unused-names.wast>
- `dce-eh.wast` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dce-eh.wast>
- `dce-eh-legacy.wast` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dce-eh-legacy.wast>
- `dce-stack-switching.wast` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dce-stack-switching.wast>

## Reviewed source surfaces

The recheck focused on the same teaching-relevant surfaces already documented in the living dossier:

- the pass shell and `TypeUpdater`-centered postwalk in `DeadCodeElimination.cpp`
- the `dce` registration and no-DWARF placement in `pass.cpp`
- the ordinary unreachable-shape and EH lit families
- the downstream `vacuum` / `remove-unused-names` neighborhood proof file

## Durable observations

- Current `main` still registers `dce` as `removes unreachable code` and keeps the same small unreachable-shape contract on the reviewed surfaces.
- The owner file still teaches the same source-backed story already captured by the living dossier: preserve earlier executing children as `drop`s before the first unreachable child, trim dead block suffixes, collapse some control-node types to `unreachable`, and run only the narrow EH nested-pop repair.
- The official lit surfaces still contain the same teaching-relevant families: ordinary unreachable-shape cleanup, EH and stack-switching boundaries, and the intended downstream neighborhood with `vacuum` and `remove-unused-names`.
- No teaching-relevant drift was found on the reviewed current-main surfaces.
- The local Starshine story is unchanged by this source refresh: `dead-code-elimination` remains a broader HOT rewrite family with explicit raw-skip and writeback-guard surfaces, not a one-to-one AST port of upstream Binaryen.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
