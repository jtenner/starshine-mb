# Binaryen `remove-unused-types` primary-source capture

_Capture date:_ 2026-04-24  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/remove-unused-types/` dossier

## Scope

This file captures the primary online sources consulted for the 2026-04-24 `remove-unused-types` correction and Starshine status follow-up.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/remove-unused-types/index.md`
- `docs/wiki/binaryen/passes/remove-unused-types/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/remove-unused-types/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/remove-unused-types/closed-world-visibility-and-rec-group-rewrite.md`
- `docs/wiki/binaryen/passes/remove-unused-types/wat-shapes.md`
- `docs/wiki/binaryen/passes/remove-unused-types/starshine-strategy.md`

## Provenance

### Official release pages consulted

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Page observed on 2026-04-24.
  - GitHub showed the publish date as **2026-04-01 14:31** when reviewed in neighboring 2026-04-24 pass ingests; this follow-up reuses `version_129` as the release oracle for the corrected source reading.
- Binaryen GitHub releases index
  - URL: <https://github.com/WebAssembly/binaryen/releases>
  - Page observed on 2026-04-24 in the pass-ingest campaign.

### Official source files consulted

- `RemoveUnusedTypes.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RemoveUnusedTypes.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/RemoveUnusedTypes.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/RemoveUnusedTypes.cpp>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/RemoveUnusedTypes.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- `type-updating.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/type-updating.h>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/ir/type-updating.h>
- `module-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/module-utils.h>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/ir/module-utils.h>

### Official test files consulted

- `remove-unused-types.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-types.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/remove-unused-types.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/remove-unused-types.wast>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/remove-unused-types.wast>

## Durable observations from the captured sources

- The corrected `version_129` source reading is materially different from the older `0149` research note.
- `RemoveUnusedTypes.cpp` is a tiny coordinator. It only checks GC support, fatally rejects explicit open-world execution, and calls `GlobalTypeRewriter(*module).update()`.
- The pass file does **not** contain the older-dossier `optimizeLevel >= 2` early return, direct `ModuleUtils::getPublicHeapTypes(...)` call, custom `UsedTypeScanner`, `Builder newTypeBuilder`, or hand-written loop that copies whole old rec groups. Those older claims are now explicitly superseded for the living dossier.
- The default scheduler context still matters: `pass.cpp` places `remove-unused-types` only in the closed-world GC/type optimization neighborhood under the broader optimization-level gating, while an explicit standalone open-world invocation of the pass itself is a fatal usage error rather than a quiet no-op.
- `GlobalTypeRewriter` in `type-updating.h` owns the real strategy: collect used IR heap types and visibility metadata, identify public groups, derive private predecessor constraints from private supertypes and described-type dependencies, topologically sort private types, rebuild surviving private types into a new private rec group, preserve public groups as anchors, remap type names/indices, and rewrite module-wide type uses.
- The corrected transformed-shape rule is therefore: unused private types disappear, surviving private types are rebuilt into a fresh private group subject to predecessor constraints, and whole old private rec groups are **not** automatically preserved merely because one member is live.
- The official lit file is the best compact proof surface for private removals, public-retention boundaries, group restructuring, and the closed-world usage contract, but helper reading is required to understand the full rewrite.
- A narrow 2026-04-24 current-`main` spot check on the owner file, registration/scheduler surface, helper headers, and dedicated lit file did not surface teaching-relevant drift from the corrected `version_129` story. This is intentionally a narrow check, not a whole-repo equivalence proof.
- Starshine-specific follow-up in this run did not find a local implementation file. The durable local fact is that `remove-unused-types` is a preserved **boundary-only** registry name, not an active HOT or module pass.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages and the corrective research note instead of treating the older `0149` research note as the current algorithm authority.
