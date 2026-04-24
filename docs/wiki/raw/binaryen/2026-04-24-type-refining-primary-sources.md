# Binaryen `type-refining` primary-source capture

_Capture date:_ 2026-04-24  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/type-refining/` dossier

## Scope

This file captures the exact primary online sources consulted for the 2026-04-24 `type-refining` follow-up.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/type-refining/index.md`
- `docs/wiki/binaryen/passes/type-refining/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/type-refining/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/type-refining/normal-vs-gufa-and-fixups.md`
- `docs/wiki/binaryen/passes/type-refining/wat-shapes.md`
- `docs/wiki/binaryen/passes/type-refining/starshine-strategy.md`

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

- `TypeRefining.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/TypeRefining.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/TypeRefining.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/TypeRefining.cpp>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/TypeRefining.cpp>
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
- `lubs.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/lubs.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/lubs.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/lubs.h>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/ir/lubs.h>
- `possible-contents.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/possible-contents.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/possible-contents.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/possible-contents.h>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/ir/possible-contents.h>
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

### Official test files consulted

- `type-refining.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/type-refining.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/type-refining.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/type-refining.wast>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/type-refining.wast>
- `type-refining-gufa.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/type-refining-gufa.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/type-refining-gufa.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/type-refining-gufa.wast>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/type-refining-gufa.wast>
- `type-refining-gufa-exact.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/type-refining-gufa-exact.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/type-refining-gufa-exact.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/type-refining-gufa-exact.wast>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/type-refining-gufa-exact.wast>
- `type-refining-gufa-rmw.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/type-refining-gufa-rmw.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/type-refining-gufa-rmw.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/type-refining-gufa-rmw.wast>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/type-refining-gufa-rmw.wast>

## Durable observations from the captured sources

- The reviewed official release surface still anchored cleanly on Binaryen `version_129` for this pass on 2026-04-24, with the tagged release page showing publish date **2026-04-01 14:31**.
- `pass.cpp` registers both `type-refining` and the companion `type-refining-gufa`; the compact public summary for the base pass is too vague to teach the real contract without `TypeRefining.cpp` and the dedicated lit files.
- `TypeRefining.cpp` owns the pass-specific algorithm: GC and `--closed-world` gates, normal-vs-GUFA inference selection, field-LUB collection, hierarchy-aware propagation, public-type freezing, explicit `struct.get` repair, private struct-type rewriting through `GlobalTypeRewriter`, whole-module refinalization, and post-rewrite write repair for `struct.new`, `struct.set`, RMW, and cmpxchg sites.
- `struct-utils.h` supplies the normal variant's exactness-aware `StructScanner` and `StructValuesMap` machinery, including the fallthrough behavior used to ignore tee / `br_if` copies.
- `lubs.h` supplies the `LUBFinder` summary object used as each field's inferred-content lattice value.
- `possible-contents.h` supplies `ContentOracle`, the whole-program inference engine used by `type-refining-gufa` to see through locals, globals, calls, and cycles that the normal direct-traffic scanner cannot model.
- `type-updating.*` supplies the module-wide type-rewrite machinery and `TypeUpdater` support needed after field declarations change.
- `module-utils.h` supplies public-heap-type discovery, heap-type collection, and module/function traversal surfaces the pass relies on for boundary handling and scan coverage.
- The dedicated lit family proves direct subtype writes, default/nullability behavior, same-field copies, tee-vs-control-flow fallthrough boundaries, public-type freezes, `struct.get` retagging and unreachable replacement, GUFA-only inference wins, exact/custom-descriptor limits, continuation limits, and conservative RMW / cmpxchg handling.
- Starshine-specific follow-up in this run did not find a local implementation file. The durable local fact is that `type-refining` is a preserved **boundary-only** registry name, not an active HOT or module pass; the upstream `type-refining-gufa` sibling is discussed in the wiki but is not separately registered in `src/passes/optimize.mbt` today.
- A narrow 2026-04-24 current-`main` spot check on the owner file, registration surface, helper headers, and dedicated lit files did not surface teaching-relevant contract drift from the reviewed `version_129` story. The durable claim is intentionally narrow, not a whole-repo equivalence proof.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
