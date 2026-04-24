# Binaryen `reorder-functions` primary-source capture

_Capture date:_ 2026-04-24  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/reorder-functions/` dossier

## Scope

This file captures the primary online sources consulted for the 2026-04-24 `reorder-functions` follow-up. It is provenance-heavy on purpose. Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/reorder-functions/index.md`
- `docs/wiki/binaryen/passes/reorder-functions/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/reorder-functions/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/reorder-functions/count-surfaces-ordering-and-omissions.md`
- `docs/wiki/binaryen/passes/reorder-functions/module-shapes.md`
- `docs/wiki/binaryen/passes/reorder-functions/starshine-strategy.md`
- `docs/wiki/binaryen/passes/reorder-functions-by-name/index.md`

## Provenance

### Official release pages consulted

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Page observed on 2026-04-24.
  - GitHub showed the publish date as **2026-04-01 14:31**.
- Binaryen GitHub releases index
  - URL: <https://github.com/WebAssembly/binaryen/releases>
  - Page observed on 2026-04-24.
  - Used to confirm that `version_129` was still present on the official release surface reviewed in this run.

### Official source files consulted

- `src/passes/ReorderFunctions.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/ReorderFunctions.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/ReorderFunctions.cpp>
- `src/passes/pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>

### Official test and directory surfaces consulted

- `test/lit/passes/reorder-functions-by-name.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/reorder-functions-by-name.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/reorder-functions-by-name.wast>
- `test/lit/passes` directory listing
  - `version_129`: <https://api.github.com/repos/WebAssembly/binaryen/contents/test/lit/passes?ref=version_129>
  - `main`: <https://api.github.com/repos/WebAssembly/binaryen/contents/test/lit/passes?ref=main>
  - Used only as coverage context for dedicated lit-file presence. It is not a whole-repository test-absence proof.

## Durable observations from the captured sources

- The reviewed official release surface still anchored cleanly on Binaryen `version_129` for this pass on 2026-04-24, with the tagged release page showing publish date **2026-04-01 14:31**.
- `ReorderFunctions.cpp` owns both public pass names: `reorder-functions` and `reorder-functions-by-name`.
- `pass.cpp` still exposes both names as public passes rather than hidden modes. The descriptions keep the intended split explicit: the by-name sibling is debugging-oriented, while `reorder-functions` sorts by access frequency.
- In `version_129`, the `reorder-functions` body-side count scan visits direct `Call` nodes only. The pass then adds serial count bumps for the start function, function exports, and element-segment function names before sorting.
- The ordering rule is source-confirmed: descending count first, then descending internal name on equal counts. Equal-count functions are not source-order-stable.
- The source still records explicit TODO boundaries for counting `ref.func` and declaration-section mentions. Those omissions should remain visible in parity-oriented teaching and future Starshine port planning.
- Both reorder-functions siblings report no nonnullable-local-fixup requirement, reinforcing that Binaryen's source-level mutation is declaration-order-only.
- The dedicated lit surface reviewed here is asymmetric: `reorder-functions-by-name.wast` directly proves the lexical sibling; the plain count-based sibling is best taught from `ReorderFunctions.cpp` plus the directory-listing caveat, not from a dedicated `reorder-functions.wast` golden.
- A narrow 2026-04-24 current-`main` spot check of `ReorderFunctions.cpp`, `pass.cpp`, the sibling lit file, and the pass-test directory listing did not surface teaching-relevant drift beyond the refreshed dossier claims.
- Local Starshine status is a repository fact separate from upstream provenance: current Starshine keeps both `reorder-functions` and `reorder-functions-by-name` as boundary-only registry names in `src/passes/optimize.mbt`, with no module-pass owner file, dispatcher case, active preset slot, or dedicated backlog slice today.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
