# Binaryen `simplify-locals` primary-source capture

_Capture date:_ 2026-04-21  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/simplify-locals/` dossier

## Scope

This file captures the exact primary online sources consulted for the 2026-04-21 `simplify-locals` follow-up.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/simplify-locals/index.md`
- `docs/wiki/binaryen/passes/simplify-locals/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/simplify-locals/wat-shapes.md`
- `docs/wiki/binaryen/passes/simplify-locals/structure-result-lifting-and-carrier-cleanup.md`
- `docs/wiki/binaryen/passes/simplify-locals/starshine-hot-ir-strategy.md`
- `docs/wiki/binaryen/passes/simplify-locals/implementation-map.md`
- `docs/wiki/binaryen/passes/simplify-locals/parity.md`

## Provenance

### Official release pages consulted

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Page observed on 2026-04-21.
  - GitHub showed it as the latest Binaryen release and showed the publish date as **2026-04-01**.
- Binaryen GitHub releases index
  - URL: <https://github.com/WebAssembly/binaryen/releases>
  - Page observed on 2026-04-21.
  - Used to confirm that the tagged `version_129` release page was still the release surface to anchor the dossier against on this run.

### Official source files consulted

- `SimplifyLocals.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SimplifyLocals.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/SimplifyLocals.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `opt-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- `pass.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h>
- `linear-execution.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/linear-execution.h>
- `effects.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
- `equivalent_sets.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/equivalent_sets.h>
- `local-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-utils.h>
- `branch-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/branch-utils.h>
- `find_all.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/find_all.h>
- `manipulation.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/manipulation.h>
- `wasm-builder.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-builder.h>

### Official test files consulted

- `simplify-locals-global.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-locals-global.wast>
- `global-effects_simplify-locals.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/global-effects_simplify-locals.wast>
- `simplify-locals-atomic-effects.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-locals-atomic-effects.wast>
- `simplify-locals-eh.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-locals-eh.wast>
- `simplify-locals-eh-legacy.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-locals-eh-legacy.wast>
- `simplify-locals-gc.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-locals-gc.wast>
- `simplify-locals-gc-nn.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-locals-gc-nn.wast>
- `simplify-locals-gc-validation.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-locals-gc-validation.wast>
- `simplify-locals-strings.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-locals-strings.wast>
- `simplify-locals-table_copy.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-locals-table_copy.wast>
- `simplify-locals-tnh.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-locals-tnh.wast>
- `simplify-locals_rse_fallthrough.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-locals_rse_fallthrough.wast>
- Representative flatness-combo proof files
  - `flatten_simplify-locals-nonesting_enable-gc.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_simplify-locals-nonesting_enable-gc.wast>
  - `flatten_simplify-locals-nonesting_enable-gc.txt`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_simplify-locals-nonesting_enable-gc.txt>

## Durable observations from the captured sources

- GitHub showed `version_129` as the latest Binaryen release page when this capture was made on 2026-04-21, so the simplify-locals dossier now no longer needs the older release-order uncertainty language that some nearby folders preserved for earlier runs.
- `SimplifyLocals.cpp` still contains the full released contract for the family: the templated `allowTee` / `allowStructure` / `allowNesting` axes, the first-cycle single-use bias, the late equivalent-copy cleanup, the one-armed `if` speculative rewrite, the block / if / loop result families, and the `ReFinalize`-relevant direct-sink path.
- On the checked `main` source surface, the meaningful simplify-locals logic still matched `version_129`; the visible drift on the reviewed file was the container cleanup from `std::map` / `std::set` to `std::unordered_map` / `std::unordered_set` in the block-break and unoptimizable-block bookkeeping.
- The reviewed lit roster still matches the dossier's main teaching surfaces: global/table/string/effect ordering, EH/TNH boundaries, GC and nondefaultable-local validation edges, and the `rse`-interaction copy-preservation case.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
