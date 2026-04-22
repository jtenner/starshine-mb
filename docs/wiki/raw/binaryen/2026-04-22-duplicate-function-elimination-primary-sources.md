# Binaryen `duplicate-function-elimination` primary-source capture

_Capture date:_ 2026-04-22  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/duplicate-function-elimination/` dossier

## Scope

This file captures the exact primary online sources consulted for the 2026-04-22 `duplicate-function-elimination` follow-up.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/duplicate-function-elimination/index.md`
- `docs/wiki/binaryen/passes/duplicate-function-elimination/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/duplicate-function-elimination/wat-shapes.md`
- `docs/wiki/binaryen/passes/duplicate-function-elimination/type-compaction-and-metadata.md`
- `docs/wiki/binaryen/passes/duplicate-function-elimination/starshine-hot-ir-strategy.md`
- `docs/wiki/binaryen/passes/duplicate-function-elimination/parity.md`

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

- `DuplicateFunctionElimination.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DuplicateFunctionElimination.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/DuplicateFunctionElimination.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `function-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/function-utils.h>
- `hashed.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/hashed.h>
- `opt-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>

### Official test files consulted

- `duplicate-function-elimination_all-features.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/duplicate-function-elimination_all-features.wast>
- `duplicate-function-elimination_annotations.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/duplicate-function-elimination_annotations.wast>
- `duplicate-function-elimination_branch-hints.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/duplicate-function-elimination_branch-hints.wast>
- `duplicate-function-elimination_optimize-level=1.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/duplicate-function-elimination_optimize-level=1.wast>
- `duplicate-function-elimination_optimize-level=2.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/duplicate-function-elimination_optimize-level=2.wast>

## Durable observations from the captured sources

- The reviewed official release surface still anchored cleanly on Binaryen `version_129` for this pass on 2026-04-22, with the tagged release page showing publish date **2026-04-01**.
- The reviewed upstream pass still centers on the same small contract already described by the living dossier: iterate according to optimize/shrink settings, hash only to create candidate buckets, exact-compare only within those buckets, remove later duplicates, and rewrite function references.
- The reviewed upstream tests still prove the same teaching surfaces that matter most for this dossier: all-features function-reference rewriting, semantics-altering annotation mismatches, non-semantic branch-hint tolerance, and the optimize-level-dependent transitive-unlock story.
- The checked current-`main` `DuplicateFunctionElimination.cpp` surface still matched the tagged `version_129` behavior for the reviewed teaching-relevant logic; the visible drift on the inspected file remained a tiny container change from `std::set<Name>` to `std::unordered_set<Name>` for duplicate-name bookkeeping.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
