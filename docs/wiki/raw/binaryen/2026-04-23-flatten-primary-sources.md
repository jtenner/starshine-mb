# Binaryen `flatten` primary-source capture

_Capture date:_ 2026-04-23  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/flatten/` dossier

## Scope

This file captures the exact primary online sources consulted for the 2026-04-23 `flatten` follow-up.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/flatten/index.md`
- `docs/wiki/binaryen/passes/flatten/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/flatten/flat-ir-contract-and-preludes.md`
- `docs/wiki/binaryen/passes/flatten/wat-shapes.md`
- `docs/wiki/binaryen/passes/flatten/starshine-strategy.md`

## Provenance

### Official release pages consulted

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Page observed on 2026-04-23.
  - GitHub showed the publish date as **2026-04-01**.
- Binaryen GitHub releases index
  - URL: <https://github.com/WebAssembly/binaryen/releases>
  - Page observed on 2026-04-23.
  - Used to confirm that `version_129` was still present on the official reviewed release surface for this dossier during this run.

### Official source files consulted

- `Flatten.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Flatten.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/Flatten.cpp>
- `flat.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/flat.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/flat.h>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `passes.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/passes.h>
- Supporting upstream helper surfaces reviewed for the dossier's flatness and EH-repair story
  - `eh-utils.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/eh-utils.h>
  - `branch-utils.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/branch-utils.h>
  - `properties.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
  - `manipulation.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/manipulation.h>

### Official test files consulted

- `flatten.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/flatten.wast>
- `flatten_all-features.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_all-features.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/flatten_all-features.wast>
- `flatten-eh-legacy.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten-eh-legacy.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/flatten-eh-legacy.wast>
- `opt_flatten.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/opt_flatten.wast>
- `flatten_rereloop.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_rereloop.wast>
- `flatten_i64-to-i32-lowering.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_i64-to-i32-lowering.wast>

## Durable observations from the captured sources

- The reviewed official release surface still anchored cleanly on Binaryen `version_129` for this pass on 2026-04-23, with the tagged release page showing publish date **2026-04-01**.
- The reviewed upstream implementation still matched the teaching-important contract already captured in the living dossier: Flat IR is defined formally in `flat.h`, `Flatten.cpp` is a postorder `preludes` plus named-target-temp rewrite, control-value carriers are rewritten through temp locals, and EH repair remains an explicit final step instead of an incidental side effect.
- The reviewed upstream source still carried the same high-value negative contract already called out in the dossier: current Binaryen `flatten` hard-fails on unsupported `BrOn*` and `TryTable` families rather than silently bailing out.
- The reviewed source and tests still showed the same subtle positive/negative split around reference typing already taught in the dossier: `flat.h` keeps nested `ref.as_non_null` as a deliberate special case, some non-null families are covered in the dedicated lit files, and the top-of-file implementation TODO still means support is selective rather than universal.
- The reviewed dedicated and neighboring lit files still demonstrated the same practical teaching surface already captured in the living pages: ordinary flatten positives, legacy EH repair cases, and the way later `rereloop` and `i64-to-i32-lowering` tests depend on already-flattened input.
- A narrow 2026-04-23 current-`main` spot check on `Flatten.cpp`, `flat.h`, `pass.cpp`, `flatten.wast`, `flatten_all-features.wast`, and `flatten-eh-legacy.wast` did not surface a new teaching-relevant contract drift beyond the dossier's existing Binaryen claims.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
