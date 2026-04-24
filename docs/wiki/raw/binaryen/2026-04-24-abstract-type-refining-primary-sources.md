# Binaryen `abstract-type-refining` primary-source capture

_Capture date:_ 2026-04-24  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/abstract-type-refining/` dossier

## Scope

This file captures the exact primary online sources consulted for the 2026-04-24 `abstract-type-refining` follow-up.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/abstract-type-refining/index.md`
- `docs/wiki/binaryen/passes/abstract-type-refining/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/abstract-type-refining/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/abstract-type-refining/traps-never-happen-exact-casts-and-descriptors.md`
- `docs/wiki/binaryen/passes/abstract-type-refining/wat-shapes.md`
- `docs/wiki/binaryen/passes/abstract-type-refining/starshine-strategy.md`

## Provenance

### Official release pages consulted

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Page observed on 2026-04-24.
  - GitHub showed the publish date as **2026-04-01 14:31**.
  - The page identified the release as the latest release when reviewed.
  - The page showed the tag commit as `d0e2be9` and reported 53 commits to `main` since that release when reviewed.
- Binaryen GitHub releases index
  - URL: <https://github.com/WebAssembly/binaryen/releases>
  - Page observed on 2026-04-24.
  - Used to keep this dossier anchored to the official release surface reviewed in this run.

### Official source files consulted

- `AbstractTypeRefining.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/AbstractTypeRefining.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/AbstractTypeRefining.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/AbstractTypeRefining.cpp>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/AbstractTypeRefining.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- `subtypes.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/subtypes.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/subtypes.h>
- `type-updating.h` / `type-updating.cpp`
  - `version_129` header: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h>
  - `version_129` implementation: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.cpp>
  - `main` header: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/type-updating.h>
  - `main` implementation: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/type-updating.cpp>
- `module-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/module-utils.h>
- `localize.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/localize.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/localize.h>
- `drop.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/drop.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/drop.h>
- `wasm-type.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-type.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/wasm-type.h>

### Official test files consulted

- `abstract-type-refining.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/abstract-type-refining.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/abstract-type-refining.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/abstract-type-refining.wast>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/abstract-type-refining.wast>
- `abstract-type-refining-desc.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/abstract-type-refining-desc.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/abstract-type-refining-desc.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/abstract-type-refining-desc.wast>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/abstract-type-refining-desc.wast>
- `abstract-type-refining-exact.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/abstract-type-refining-exact.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/abstract-type-refining-exact.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/abstract-type-refining-exact.wast>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/abstract-type-refining-exact.wast>
- `abstract-type-refining-tnh-exact-casts.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/abstract-type-refining-tnh-exact-casts.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/abstract-type-refining-tnh-exact-casts.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/abstract-type-refining-tnh-exact-casts.wast>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/abstract-type-refining-tnh-exact-casts.wast>
- `abstract-type-refining-cont.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/abstract-type-refining-cont.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/abstract-type-refining-cont.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/abstract-type-refining-cont.wast>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/abstract-type-refining-cont.wast>

## Durable observations from the captured sources

- The reviewed official release surface still anchored cleanly on Binaryen `version_129` for this pass on 2026-04-24, with the tagged release page showing publish date **2026-04-01 14:31**.
- `pass.cpp` registers the public CLI name `abstract-type-refining` with the compact summary `refine and merge abstract (never-created) types`; the owner file is required to understand the actual creation-evidence, TNH, descriptor, and exact-cast contract.
- `AbstractTypeRefining.cpp` owns the pass-specific algorithm: GC and `--closed-world` gates, `struct.new*` creation scanning, public heap-type keepalive, upward created-subtype propagation, TNH-only unique-child refinement, always-on never-created-family bottomization, descriptor/exact-cast preoptimization, type-use rewriting, declared-supertype preservation, and final `ReFinalize`.
- `subtypes.h` defines the subtype traversal and child-query surface used to compute created-subtype relevance and chained abstract-parent refinements.
- `type-updating.*` supplies the module-wide type-use rewrite surface; the pass deliberately preserves declared supertypes here and leaves subtype-edge cleanup to `unsubtyping`.
- `module-utils.h` supplies the parallel function-body scan and public-heap-type boundary.
- `localize.h` and `drop.h` explain the visible temp/localization and drop-children-plus-`unreachable` scaffolding in descriptor and impossible-allocation rewrites.
- The dedicated lit files cover ordinary TNH refinement, always-on bottomization, descriptor and exact-cast repair, `ref.get_desc`, impossible `struct.new_desc`, exact-bottom local types, and continuation-containing rec-group robustness.
- Starshine-specific follow-up in this run did not find a local implementation file. The durable local fact is that `abstract-type-refining` is a preserved **boundary-only** registry name, not an active HOT or module pass.
- A narrow 2026-04-24 current-`main` spot check on the owner file, registration surface, helper headers, and dedicated lit files did not surface teaching-relevant contract drift from the reviewed `version_129` story. The durable claim is intentionally narrow, not a whole-repo equivalence proof.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
