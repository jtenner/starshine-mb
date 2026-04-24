# Binaryen `type-merging` primary-source capture

_Capture date:_ 2026-04-24  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/type-merging/` dossier

## Scope

This file captures the exact primary online sources consulted for the 2026-04-24 `type-merging` follow-up.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/type-merging/index.md`
- `docs/wiki/binaryen/passes/type-merging/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/type-merging/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/type-merging/dfa-partitions-casts-and-refinalization.md`
- `docs/wiki/binaryen/passes/type-merging/wat-shapes.md`
- `docs/wiki/binaryen/passes/type-merging/starshine-strategy.md`

## Provenance

### Official release pages consulted

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Page observed on 2026-04-24.
  - GitHub showed the publish date as **2026-04-01 14:31**.
  - The page identified the release as the latest release when reviewed.
- Binaryen GitHub releases index
  - URL: <https://github.com/WebAssembly/binaryen/releases>
  - Page observed on 2026-04-24.
  - Used to keep this dossier anchored to the official release surface reviewed in this run.

### Official source files consulted

- `TypeMerging.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/TypeMerging.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/TypeMerging.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/TypeMerging.cpp>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/TypeMerging.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- `wasm-type-ordering.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-type-ordering.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/wasm-type-ordering.h>
- `dfa_minimization.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/support/dfa_minimization.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/support/dfa_minimization.h>
- `module-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/module-utils.h>
- `type-updating.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/type-updating.h>

### Official test files consulted

- `type-merging.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/type-merging.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/type-merging.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/type-merging.wast>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/type-merging.wast>

## Durable observations from the captured sources

- The reviewed official release surface still anchored cleanly on Binaryen `version_129` for this pass on 2026-04-24, with the tagged release page showing publish date **2026-04-01 14:31**.
- `pass.cpp` registers the public CLI name `type-merging` with the compact summary `merge types to their supertypes where possible`; the owner file is required to understand the real closed-world graph-equivalence contract.
- `TypeMerging.cpp` owns the pass-specific algorithm: GC and `--closed-world` gates, private heap-type candidate collection, cast/exact-cast scanning, descriptor-chain treatment, supertype-first ordering, top-level shape grouping, DFA partition refinement, supertype and sibling merge phases, whole-module type mapping, and optional `ReFinalize`.
- `wasm-type-ordering.h` explains why target choice is supertype-first rather than arbitrary iteration.
- `dfa_minimization.h` is central to the equivalence proof; the pass treats heap types as states whose child heap types are transitions.
- `module-utils.h` supplies the private heap-type boundary, and `type-updating.h` supplies the module-wide rewrite/refinalization repair surface after a merge.
- `type-merging.wast` is the dedicated proof surface for direct supertype merges, chain collapse, recursive and sibling families, cast/exactness blockers, public-type boundaries, descriptor-chain behavior, and known precision limits.
- Starshine-specific follow-up in this run did not find a local implementation file. The durable local fact is that `type-merging` is a preserved **boundary-only** registry name, not an active HOT or module pass.
- A narrow 2026-04-24 current-`main` spot check on the owner file, registration surface, helper headers, and dedicated lit file did not surface teaching-relevant contract drift from the reviewed `version_129` story. The durable claim is intentionally narrow, not a whole-repo equivalence proof.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
