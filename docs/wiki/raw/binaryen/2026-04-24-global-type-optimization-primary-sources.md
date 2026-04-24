# Binaryen `global-type-optimization` primary-source capture

_Capture date:_ 2026-04-24  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/global-type-optimization/` dossier

## Scope

This file captures the exact primary online sources consulted for the 2026-04-24 `global-type-optimization` follow-up.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/global-type-optimization/index.md`
- `docs/wiki/binaryen/passes/global-type-optimization/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/global-type-optimization/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/global-type-optimization/field-removal-subtyping-js-interop-and-traps.md`
- `docs/wiki/binaryen/passes/global-type-optimization/wat-shapes.md`
- `docs/wiki/binaryen/passes/global-type-optimization/starshine-strategy.md`

## Provenance

### Official release pages consulted

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Page observed on 2026-04-24.
  - GitHub showed the publish date as **2026-04-01 14:31**.
  - The page identified the release as the latest release when reviewed.
  - The page showed the tag commit as `d0e2be9` and reported 53 commits to `main` since this release when reviewed.
- Binaryen GitHub releases index
  - URL: <https://github.com/WebAssembly/binaryen/releases>
  - Page observed on 2026-04-24.
  - Used to keep this dossier anchored to the official release surface reviewed in this run.

### Official source files consulted

- `GlobalTypeOptimization.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GlobalTypeOptimization.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/GlobalTypeOptimization.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/GlobalTypeOptimization.cpp>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/GlobalTypeOptimization.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- `struct-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/struct-utils.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/struct-utils.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/struct-utils.h>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/ir/struct-utils.h>
- `type-updating.h` / `type-updating.cpp`
  - `version_129` header: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h>
  - `version_129` implementation: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.cpp>
  - `main` header: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/type-updating.h>
  - `main` implementation: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/type-updating.cpp>
- `module-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/module-utils.h>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/ir/module-utils.h>
- `js-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/js-utils.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/js-utils.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/js-utils.h>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/ir/js-utils.h>
- `wasm-type-ordering.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-type-ordering.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/wasm-type-ordering.h>
- `support/permutations.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/support/permutations.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/support/permutations.h>

### Official test files consulted

- `gto-removals.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gto-removals.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/gto-removals.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/gto-removals.wast>
- `gto-removals-rmw.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gto-removals-rmw.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/gto-removals-rmw.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/gto-removals-rmw.wast>
- `gto-mutability.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gto-mutability.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/gto-mutability.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/gto-mutability.wast>
- `gto-desc.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gto-desc.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/gto-desc.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/gto-desc.wast>
- `gto-jsinterop.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gto-jsinterop.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/gto-jsinterop.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/gto-jsinterop.wast>
- `gto-shared-jsinterop.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gto-shared-jsinterop.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/gto-shared-jsinterop.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/gto-shared-jsinterop.wast>
- `gto-strings-jsinterop.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gto-strings-jsinterop.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/gto-strings-jsinterop.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/gto-strings-jsinterop.wast>
- `gto_and_cfp_in_O.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gto_and_cfp_in_O.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/gto_and_cfp_in_O.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/gto_and_cfp_in_O.wast>
- `signature-refining_gto.wat`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/signature-refining_gto.wat>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/signature-refining_gto.wat>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/signature-refining_gto.wat>

## Durable observations from the captured sources

- The reviewed official release surface still anchored cleanly on Binaryen `version_129` for this pass on 2026-04-24, with the tagged release page showing publish date **2026-04-01 14:31**.
- `pass.cpp` registers the public CLI pass name `gto`; Starshine's local registry uses the longer descriptive spelling `global-type-optimization`.
- `GlobalTypeOptimization.cpp` hard-gates the pass on GC features plus `--closed-world`, scans function bodies and module code, combines runtime `struct.set` / `struct.get` / atomic field traffic, adds JS-interface prototype-field reads, and then computes hierarchy-aware immutability plus removal plans.
- Constructor traffic is intentionally not the main decision evidence: `struct.new` operands still need rewrite and trap preservation, but the source combines `functionSetGetInfos` into the optimization map.
- The main removability split is source-backed: a field can disappear if there are no reads anywhere in the compatible hierarchy, or if only strict subtypes need it and the parent layout can be repaired by reordering/removal.
- Public heap types are frozen before decisions, so private descendants may optimize only where subtype layout remains compatible with public prefixes.
- `js-utils.h` plus the `gto-jsinterop*` lit files define the descriptor-prototype keepalive rule for values that can flow out to JS.
- `updateInstructions(...)` must run before `updateTypes(...)` because old heap types are needed to identify field layouts; removed writes preserve value side effects and null-trap order, removed trapping module initializers become `gto-removed-*` globals, and localization-triggered EH block insertion requires nested-pop repair.
- `GlobalTypeRewriter` owns the module-wide type-use remap after private struct field mutability/removal changes, while `GlobalTypeOptimization.cpp` manually repairs field names because the field permutation is pass-local knowledge.
- A narrow 2026-04-24 current-`main` spot check on the owner file, registration surface, helper headers, and dedicated lit files did not surface teaching-relevant contract drift from the reviewed `version_129` story. The durable claim is intentionally narrow, not a whole-repo equivalence proof.
- Starshine-specific follow-up in this run did not find a local implementation file. The durable local fact is that `global-type-optimization` is a preserved **boundary-only** registry name, not an active HOT or module pass.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
