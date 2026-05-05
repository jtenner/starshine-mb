# Binaryen `remove-unused-brs` current-main recheck

_Capture date:_ 2026-05-05  
_Status:_ immutable current-main source bridge for the `docs/wiki/binaryen/passes/remove-unused-brs/` dossier

## Scope

This file records the primary online sources rechecked for the 2026-05-05 `remove-unused-brs` wiki-health pass. It extends, rather than replaces, the earlier tagged-source manifest in `docs/wiki/raw/binaryen/2026-04-22-remove-unused-brs-primary-sources.md` and the earlier current-main bridge in `docs/wiki/raw/research/0247-2026-04-22-remove-unused-brs-primary-sources-and-code-map-followup.md`.
Use the living pages for the teachable contract:

- `docs/wiki/binaryen/passes/remove-unused-brs/index.md`
- `docs/wiki/binaryen/passes/remove-unused-brs/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/remove-unused-brs/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/remove-unused-brs/wat-shapes.md`
- `docs/wiki/binaryen/passes/remove-unused-brs/starshine-strategy.md`
- `docs/wiki/binaryen/passes/remove-unused-brs/starshine-hot-ir-strategy.md`
- `docs/wiki/binaryen/passes/remove-unused-brs/parity.md`

## Official sources consulted

### Binaryen `main`

- `RemoveUnusedBrs.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/RemoveUnusedBrs.cpp>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/RemoveUnusedBrs.cpp>
- `pass.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- `remove-unused-brs.wast`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/remove-unused-brs.wast>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/remove-unused-brs.wast>
- `remove-unused-brs-gc.wast`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/remove-unused-brs-gc.wast>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/remove-unused-brs-gc.wast>
- `remove-unused-brs-eh.wast`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/remove-unused-brs-eh.wast>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/remove-unused-brs-eh.wast>
- `remove-unused-brs_branch-hints-unconditionalize.wast`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/remove-unused-brs_branch-hints-unconditionalize.wast>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/remove-unused-brs_branch-hints-unconditionalize.wast>

### Tagged comparison anchor

- `RemoveUnusedBrs.cpp` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RemoveUnusedBrs.cpp>
- `pass.cpp` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `remove-unused-brs.wast` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-brs.wast>
- `remove-unused-brs-gc.wast` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-brs-gc.wast>
- `remove-unused-brs-eh.wast` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-brs-eh.wast>
- `remove-unused-brs_branch-hints-unconditionalize.wast` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-brs_branch-hints-unconditionalize.wast>

## Durable observations

- The current-main surfaces rechecked here still expose the same staged `remove-unused-brs` contract already captured from `version_129`: flow cleanup, loop cleanup, block sinking, GC `br_on_*` cleanup, jump-threading, and late `br_if` / `br_table` / `select` / local-set-arm cleanup.
- The dedicated lit roster stayed aligned on the reviewed surfaces for this freshness bridge; the useful current-main work is therefore documentation freshness and exact code-map clarity, not a teaching rewrite of the pass contract.
- The living dossier's already-tracked JumpThreader type-equality relaxation remains the only documented upstream-vs-`version_129` drift on the reviewed surface.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
