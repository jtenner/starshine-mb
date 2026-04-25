# Binaryen `simplify-locals-nonesting` primary-source capture

_Capture date:_ 2026-04-25  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/simplify-locals-nonesting/` dossier

## Scope

This file captures the primary online sources consulted for the 2026-04-25 `simplify-locals-nonesting` provenance and Starshine-status refresh.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/simplify-locals-nonesting/index.md`
- `docs/wiki/binaryen/passes/simplify-locals-nonesting/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/simplify-locals-nonesting/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/simplify-locals-nonesting/flatness-variant-boundaries.md`
- `docs/wiki/binaryen/passes/simplify-locals-nonesting/wat-shapes.md`
- `docs/wiki/binaryen/passes/simplify-locals-nonesting/starshine-strategy.md`

## Provenance

### Official release pages consulted

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Page observed on 2026-04-25.
  - Neighboring 2026-04-24 and 2026-04-25 pass ingests observed the official GitHub release page showing publish date **2026-04-01**; this dossier uses `version_129` as the stable released source oracle.
- Binaryen GitHub releases index
  - URL: <https://github.com/WebAssembly/binaryen/releases>
  - Page observed on 2026-04-25 in the pass-ingest campaign.

### Official source files consulted

- `SimplifyLocals.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SimplifyLocals.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/SimplifyLocals.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/SimplifyLocals.cpp>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/SimplifyLocals.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- `passes.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/passes.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/passes.h>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/passes.h>
- Supporting helper surfaces for the shared locals-family safety story:
  - `linear-execution.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/linear-execution.h>
  - `effects.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
  - `equivalent_sets.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/equivalent_sets.h>
  - `local-utils.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-utils.h>
  - `branch-utils.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/branch-utils.h>
  - `manipulation.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/manipulation.h>

### Official test files consulted

- Dedicated `simplify-locals-nonesting` tests:
  - `test/passes/simplify-locals-nonesting.wast`
    - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nonesting.wast>
    - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/passes/simplify-locals-nonesting.wast>
    - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/passes/simplify-locals-nonesting.wast>
  - `test/passes/simplify-locals-nonesting.txt`
    - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nonesting.txt>
    - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/passes/simplify-locals-nonesting.txt>
    - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/passes/simplify-locals-nonesting.txt>
- Combo lit surfaces proving flatten-neighbor use:
  - `flatten_simplify-locals-nonesting_dfo_O3.wast`
    - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_simplify-locals-nonesting_dfo_O3.wast>
    - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/flatten_simplify-locals-nonesting_dfo_O3.wast>
  - `flatten_simplify-locals-nonesting_souperify_enable-threads.wast`
    - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_simplify-locals-nonesting_souperify_enable-threads.wast>
    - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/flatten_simplify-locals-nonesting_souperify_enable-threads.wast>
  - `flatten_simplify-locals-nonesting_souperify-single-use_enable-threads.wast`
    - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_simplify-locals-nonesting_souperify-single-use_enable-threads.wast>
    - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/flatten_simplify-locals-nonesting_souperify-single-use_enable-threads.wast>
- Nearby variant tests rechecked for contrast:
  - `simplify-locals.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals.wast>
  - `simplify-locals-notee.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-notee.wast>
  - `simplify-locals-nostructure.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nostructure.wast>
  - `simplify-locals-notee-nostructure.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-notee-nostructure.wast>

## Durable observations from the captured sources

- `version_129` registers a real public Binaryen pass named `simplify-locals-nonesting`; it is not only an internal helper flag.
- The implementation is not a separate owner file. `SimplifyLocals.cpp` owns this pass through the shared templated locals-family engine.
- The public factory identity is the core contract: `createSimplifyLocalsNoNestingPass()` constructs the shared pass with `allowTee = false`, `allowStructure = false`, and `allowNesting = false`.
- The `pass.cpp` public description says the pass performs locals-related optimizations with no nesting and preserves flatness. That public wording is the source-backed distinction from `simplify-locals-notee-nostructure`.
- The pass still performs useful cleanup through flat copy retargeting, same-parent `local.set` value substitution, late equivalent-copy canonicalization, final dead-set cleanup, and refinalization when a replacement changes inferred types.
- The pass deliberately does not create fresh `local.tee` nodes, structured block / `if` / loop result carriers, or ordinary consumer nesting for non-copy values.
- The dedicated `simplify-locals-nonesting` WAT/TXT pair proves visible local-traffic cleanup while preserving a flat-looking output shape.
- The combo lit files prove a real flatten-neighbor role before `dfo`, `souperify`, and `souperify-single-use`; this pass is not merely a dormant test variant.
- A narrow 2026-04-25 current-`main` spot check confirmed the public pass name, factory surface, and dedicated test paths remain present. This capture does **not** claim whole-file semantic equivalence between `version_129` and current `main` beyond those reviewed surfaces.
- Starshine-specific follow-up in this run found no local implementation of the sibling. The durable local fact is that Starshine tracks the local alias `simplify-locals-no-nesting` only as a removed registry name; the exact upstream spelling `simplify-locals-nonesting` is not itself a local registry entry.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages and `0331` research note instead of relying only on the older `0186` research note or direct online links.
