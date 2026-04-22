# Binaryen `remove-unused-brs` primary-source capture

_Capture date:_ 2026-04-22  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/remove-unused-brs/` dossier

## Scope

This file captures the exact primary online sources consulted for the 2026-04-22 `remove-unused-brs` follow-up.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/remove-unused-brs/index.md`
- `docs/wiki/binaryen/passes/remove-unused-brs/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/remove-unused-brs/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/remove-unused-brs/wat-shapes.md`
- `docs/wiki/binaryen/passes/remove-unused-brs/starshine-hot-ir-strategy.md`
- `docs/wiki/binaryen/passes/remove-unused-brs/parity.md`

## Provenance

### Official release pages consulted

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Page observed on 2026-04-22.
  - GitHub showed the publish date as **2026-04-01**.
- Binaryen GitHub releases index
  - URL: <https://github.com/WebAssembly/binaryen/releases>
  - Page observed on 2026-04-22.
  - Used to confirm that the `version_129` release page was still the reviewed official release surface for this dossier on this run.

### Official source files consulted

- `RemoveUnusedBrs.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RemoveUnusedBrs.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/RemoveUnusedBrs.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `branch-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/branch-utils.h>
- `branch-hints.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/branch-hints.h>
- `effects.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>

### Official test files consulted

- `remove-unused-brs.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-brs.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/remove-unused-brs.wast>
- `remove-unused-brs-gc.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-brs-gc.wast>
- `remove-unused-brs-eh.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-brs-eh.wast>
- `remove-unused-brs_branch-hints-unconditionalize.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-brs_branch-hints-unconditionalize.wast>

## Durable observations from the captured sources

- The reviewed official release surface still anchored cleanly on Binaryen `version_129` for this pass on 2026-04-22, with the tagged release page showing publish date **2026-04-01**.
- The reviewed upstream pass still matched the already-documented teaching-relevant contract: a staged structured-control cleanup pass with main flow cleanup, loop/body reshaping, block sinking, GC `br_on_*` simplification, jump-threading, and a late optimizer that covers `br_if`, `br_table`, `select`, and local-set arm cleanup.
- The reviewed sources still make the policy boundaries explicit: helper logic in `branch-utils.h`, `branch-hints.h`, and `effects.h` continues to matter for unconditionalization, branch-hint preservation, and cost-sensitive control reshaping, so the public pass is still not just a tail-`br` stripper.
- The checked current-`main` `RemoveUnusedBrs.cpp` and dedicated `remove-unused-brs.wast` file still matched the already-documented teaching-relevant surfaces on this run, aside from the folder's existing narrow jump-threader drift note; no broader contract drift was observed while preparing this provenance follow-up.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
