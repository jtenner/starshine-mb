# Binaryen `signature-refining` primary-source capture

_Capture date:_ 2026-04-24  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/signature-refining/` dossier

## Scope

This file captures the primary online sources consulted for the 2026-04-24 `signature-refining` follow-up.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/signature-refining/index.md`
- `docs/wiki/binaryen/passes/signature-refining/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/signature-refining/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/signature-refining/params-results-publicity-and-intrinsics.md`
- `docs/wiki/binaryen/passes/signature-refining/wat-shapes.md`
- `docs/wiki/binaryen/passes/signature-refining/starshine-strategy.md`

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

- `SignatureRefining.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SignatureRefining.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/SignatureRefining.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/SignatureRefining.cpp>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/SignatureRefining.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- `lubs.h` / `lubs.cpp`
  - `version_129` header: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/lubs.h>
  - `version_129` implementation: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/lubs.cpp>
  - `main` header: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/lubs.h>
  - `main` implementation: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/lubs.cpp>
- `module-utils.h` / `module-utils.cpp`
  - `version_129` header: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.h>
  - `version_129` implementation: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.cpp>
  - `main` header: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/module-utils.h>
  - `main` implementation: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/module-utils.cpp>
- `type-updating.h` / `type-updating.cpp`
  - `version_129` header: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h>
  - `version_129` implementation: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.cpp>
  - `main` header: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/type-updating.h>
  - `main` implementation: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/type-updating.cpp>
- `subtypes.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/subtypes.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/subtypes.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/subtypes.h>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/ir/subtypes.h>
- `intrinsics.h` / `intrinsics.cpp`
  - `version_129` header: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/intrinsics.h>
  - `version_129` implementation: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/intrinsics.cpp>
  - `main` header: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/intrinsics.h>
  - `main` implementation: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/intrinsics.cpp>

### Official test files consulted

- `signature-refining.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/signature-refining.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/signature-refining.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/signature-refining.wast>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/signature-refining.wast>

## Durable observations from the captured sources

- The reviewed official release surface still anchored cleanly on Binaryen `version_129` for this pass on 2026-04-24, with the tagged release page showing publish date **2026-04-01 14:31**.
- `pass.cpp` registers `signature-refining` with a compact subtype-refinement summary and places it in the closed-world GC/type cluster after `signature-pruning` and before `global-refining`.
- `SignatureRefining.cpp` owns the pass-specific policy: GC gate, whole-module table bailout, per-function fact collection, heap-type-level aggregation, public/import/tag/subtyping blockers, params-only JS/continuation blockers, param LUB computation from actual arguments, result LUB computation from returned values, parameter-body repair, nominal signature rewriting, `call.without.effects` import cloning, and final refinalization.
- `lubs.*` supplies the returned-value LUB helper that makes result refinement more than a declaration rewrite: it considers body types plus explicit and tail-returning values after refinalization.
- `module-utils.*` supplies parallel function analysis and public heap-type discovery, which define the pass's type-family visibility boundary.
- `type-updating.*` supplies `updateParamTypes(...)` and `GlobalTypeRewriter::updateSignatures(...)`, which are the key local-body repair and whole-module nominal rewrite helpers.
- `intrinsics.*` supplies both the `call.without.effects` special-case detection and the JS-called-function parameter-freeze boundary, while `subtypes.h` supplies the subtype-linked-family bailout.
- The dedicated lit file proves direct-call and `call_ref` parameter positives, mixed-LUB outcomes, shared-heap-type updates, body fixup locals, result refinement, public/import/table/subtype negatives, `call.without.effects` result repair, and tag/continuation boundaries.
- Starshine-specific follow-up in this run did not find a local implementation file. The durable local fact is that `signature-refining` is a preserved **boundary-only** registry name, not an active HOT or module pass; it is also absent from the active `optimize` / `shrink` presets and has no dedicated backlog slice today.
- A narrow 2026-04-24 current-`main` spot check on the owner file, registration surface, helper files, and dedicated lit file did not surface teaching-relevant contract drift from the reviewed `version_129` story. The durable claim is intentionally narrow, not a whole-repo equivalence proof.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
