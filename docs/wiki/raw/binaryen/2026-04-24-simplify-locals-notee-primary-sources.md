# Binaryen `simplify-locals-notee` primary-source capture

_Capture date:_ 2026-04-24  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/simplify-locals-notee/` dossier

## Scope

This file captures the primary online sources consulted for the 2026-04-24 `simplify-locals-notee` provenance and Starshine-status refresh.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/simplify-locals-notee/index.md`
- `docs/wiki/binaryen/passes/simplify-locals-notee/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/simplify-locals-notee/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/simplify-locals-notee/variant-boundaries-and-registry-aliases.md`
- `docs/wiki/binaryen/passes/simplify-locals-notee/wat-shapes.md`
- `docs/wiki/binaryen/passes/simplify-locals-notee/starshine-strategy.md`

## Provenance

### Official release pages consulted

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Page observed on 2026-04-24.
  - Neighboring 2026-04-24 pass ingests observed the official GitHub release page showing publish date **2026-04-01**; this dossier uses `version_129` as the stable release oracle for source reading.
- Binaryen GitHub releases index
  - URL: <https://github.com/WebAssembly/binaryen/releases>
  - Page observed on 2026-04-24 in the pass-ingest campaign.

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
  - `linear-execution.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/linear-execution.h>
  - `effects.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
  - `equivalent_sets.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/equivalent_sets.h>
  - `local-utils.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-utils.h>
  - `branch-utils.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/branch-utils.h>
  - `manipulation.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/manipulation.h>

### Official test files consulted

- Dedicated `simplify-locals-notee` tests:
  - `test/passes/simplify-locals-notee.wast`
    - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-notee.wast>
    - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/passes/simplify-locals-notee.wast>
    - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/passes/simplify-locals-notee.wast>
  - `test/passes/simplify-locals-notee.txt`
    - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-notee.txt>
    - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/passes/simplify-locals-notee.txt>
    - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/passes/simplify-locals-notee.txt>
- Nearby variant tests rechecked for contrast:
  - `simplify-locals.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals.wast>
  - `simplify-locals.txt`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals.txt>
  - `simplify-locals-nostructure.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nostructure.wast>
  - `simplify-locals-notee-nostructure.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-notee-nostructure.wast>
  - `simplify-locals-nonesting.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nonesting.wast>

## Durable observations from the captured sources

- `version_129` registers a real public Binaryen pass named `simplify-locals-notee`; it is not only an internal helper mode.
- The implementation is not a separate owner file. `SimplifyLocals.cpp` owns this pass through the shared templated locals-family engine.
- The public factory identity is the core contract: `createSimplifyLocalsNoTeePass()` constructs the shared pass with `allowTee = false`, `allowStructure = true`, and the default `allowNesting = true`.
- The pass therefore still performs direct single-use sinking, structured block / `if` / loop result formation, late equivalent-copy canonicalization, final dead-set cleanup, and refinalization when type changes require it.
- The only disabled major family surface is the multi-use sinking path that would create a fresh `local.tee`.
- This means `simplify-locals-notee` is not the same pass as `simplify-locals-nostructure`, `simplify-locals-notee-nostructure`, or `simplify-locals-nonesting`.
- The dedicated `simplify-locals-notee` tests prove the most visible sibling shape: the pass still forms structured results while refusing tee-introducing rewrites.
- The helper files keep the usual family boundaries in force: linear-execution tracking, directional effect invalidation, local read/write invalidation, branch-payload handling, equivalent-set representative selection, and local set/get cleanup.
- A narrow 2026-04-24 current-`main` spot check confirmed the public pass name, factory surface, and dedicated test paths remain present. This capture does **not** claim whole-file semantic equivalence between `version_129` and current `main` beyond those reviewed surfaces.
- Starshine-specific follow-up in this run found no local implementation of the sibling. The durable local fact is that Starshine tracks the local alias `simplify-locals-no-tee` only as a removed registry name; the exact upstream spelling `simplify-locals-notee` is not itself a local registry entry.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages and `0329` research note instead of relying only on the older `0166` research note or direct online links.
