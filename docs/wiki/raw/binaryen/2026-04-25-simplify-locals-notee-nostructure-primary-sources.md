# Binaryen `simplify-locals-notee-nostructure` primary-source capture

_Capture date:_ 2026-04-25  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/simplify-locals-notee-nostructure/` dossier

## Scope

This file captures the primary online sources consulted for the 2026-04-25 `simplify-locals-notee-nostructure` provenance and Starshine-status refresh.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/simplify-locals-notee-nostructure/index.md`
- `docs/wiki/binaryen/passes/simplify-locals-notee-nostructure/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/simplify-locals-notee-nostructure/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/simplify-locals-notee-nostructure/variant-surface.md`
- `docs/wiki/binaryen/passes/simplify-locals-notee-nostructure/wat-shapes.md`
- `docs/wiki/binaryen/passes/simplify-locals-notee-nostructure/starshine-strategy.md`

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
- `opt-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/opt-utils.h>
- Supporting helper surfaces for the shared locals-family safety story:
  - `local-utils.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-utils.h>
  - `effects.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
  - `equivalent_sets.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/equivalent_sets.h>
  - `linear-execution.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/linear-execution.h>
  - `properties.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
  - `branch-utils.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/branch-utils.h>
  - `manipulation.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/manipulation.h>

### Official test files consulted

- Dedicated `simplify-locals-notee-nostructure` tests:
  - `test/passes/simplify-locals-notee-nostructure.wast`
    - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-notee-nostructure.wast>
    - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/passes/simplify-locals-notee-nostructure.wast>
    - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/passes/simplify-locals-notee-nostructure.wast>
  - `test/passes/simplify-locals-notee-nostructure.txt`
    - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-notee-nostructure.txt>
    - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/passes/simplify-locals-notee-nostructure.txt>
    - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/passes/simplify-locals-notee-nostructure.txt>
- Nearby variant tests rechecked for contrast:
  - `simplify-locals.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals.wast>
  - `simplify-locals.txt`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals.txt>
  - `simplify-locals-notee.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-notee.wast>
  - `simplify-locals-notee.txt`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-notee.txt>
  - `simplify-locals-nostructure.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nostructure.wast>
  - `simplify-locals-nostructure.txt`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nostructure.txt>
  - `simplify-locals-nonesting.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nonesting.wast>
  - `simplify-locals-nonesting.txt`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nonesting.txt>
- Combo lit surfaces used for the aggressive locals-family neighborhood:
  - `flatten_simplify-locals-nonesting_dfo_O3.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_simplify-locals-nonesting_dfo_O3.wast>
  - `flatten_simplify-locals-nonesting_souperify_enable-threads.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_simplify-locals-nonesting_souperify_enable-threads.wast>
  - `flatten_simplify-locals-nonesting_souperify-single-use_enable-threads.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_simplify-locals-nonesting_souperify-single-use_enable-threads.wast>

## Durable observations from the captured sources

- `version_129` registers a real public Binaryen pass named `simplify-locals-notee-nostructure`; it is not only a private helper flag.
- The implementation is not a separate owner file. `SimplifyLocals.cpp` owns this pass through the shared templated locals-family engine.
- The public factory identity is the core contract: `createSimplifyLocalsNoTeeNoStructurePass()` constructs the shared pass with `allowTee = false`, `allowStructure = false`, and default `allowNesting = true`.
- The public-pass description in `pass.cpp` says this variant performs locals-related optimizations with neither tees nor structure. It does **not** say the pass preserves flatness; that stronger wording belongs to `simplify-locals-nonesting`.
- The `-O4` / aggressive scheduling context is the `flatten -> simplify-locals-notee-nostructure -> local-cse` prelude. That placement is source-backed but remains outside the ordinary no-DWARF `-O` / `-Os` top-level path used for the main Starshine parity queue.
- The pass still performs useful cleanup through direct single-use local sinking, conservative linear-execution invalidation, late equivalent-get canonicalization, final dead-set cleanup, and refinalization when a replacement changes inferred types.
- The pass deliberately does not create fresh `local.tee` nodes and does not create block / `if` / loop result carriers from local traffic.
- The pass may still sink into already-existing consumer positions because `allowNesting` remains true. Future Starshine documentation should keep that distinct from the stricter `SimplifyLocals<false, false, false>` / `simplify-locals-nonesting` contract.
- The dedicated `simplify-locals-notee-nostructure` WAT/TXT pair proves the most visible contrast shape: a multi-use local that `simplify-locals-nostructure` can tee is preserved as explicit local traffic by this no-tee sibling, and structured arm/block carriers remain unconverted.
- A narrow 2026-04-25 current-`main` spot check confirmed the public pass name, shared owner file, factory surface, and dedicated test paths remain present. This capture does **not** claim whole-file semantic equivalence between `version_129` and current `main` beyond those reviewed surfaces.
- Starshine-specific follow-up in this run found no active implementation of the sibling. The durable local fact is that Starshine tracks only the local alias `simplify-locals-no-tee-no-structure` as a removed registry name; the exact upstream spelling is not itself a local registry entry.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages and `0333` research note instead of relying only on the older `0129` research note or direct online links.
