# Binaryen `signature-pruning` primary-source capture

_Capture date:_ 2026-04-24  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/signature-pruning/` dossier

## Scope

This file captures the exact primary online sources consulted for the 2026-04-24 `signature-pruning` follow-up.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/signature-pruning/index.md`
- `docs/wiki/binaryen/passes/signature-pruning/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/signature-pruning/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/signature-pruning/constant-actuals-localization-and-boundaries.md`
- `docs/wiki/binaryen/passes/signature-pruning/wat-shapes.md`
- `docs/wiki/binaryen/passes/signature-pruning/starshine-strategy.md`

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

- `SignaturePruning.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SignaturePruning.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/SignaturePruning.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/SignaturePruning.cpp>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/SignaturePruning.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- `param-utils.h` / `param-utils.cpp`
  - `version_129` header: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/param-utils.h>
  - `version_129` implementation: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/param-utils.cpp>
  - `main` header: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/param-utils.h>
  - `main` implementation: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/param-utils.cpp>
- `module-utils.h` / `module-utils.cpp`
  - `version_129` header: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.h>
  - `version_129` implementation: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.cpp>
  - `main` header: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/module-utils.h>
  - `main` implementation: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/module-utils.cpp>
- `type-updating.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/type-updating.h>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/ir/type-updating.h>
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
- `possible-constant.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/possible-constant.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/possible-constant.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/possible-constant.h>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/ir/possible-constant.h>
- `localize.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/localize.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/localize.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/localize.h>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/ir/localize.h>
- `eh-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/eh-utils.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/eh-utils.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/eh-utils.h>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/ir/eh-utils.h>
- `liveness-traversal.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/cfg/liveness-traversal.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/cfg/liveness-traversal.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/cfg/liveness-traversal.h>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/cfg/liveness-traversal.h>

### Official test files consulted

- `signature-pruning.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/signature-pruning.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/signature-pruning.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/signature-pruning.wast>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/signature-pruning.wast>

## Durable observations from the captured sources

- The reviewed official release surface still anchored cleanly on Binaryen `version_129` for this pass on 2026-04-24, with the tagged release page showing publish date **2026-04-01 14:31**.
- `pass.cpp` registers `signature-pruning` with a compact parameter-removal summary and places it in the closed-world GC/type cluster after `type-refining` and before `signature-refining` / `global-refining`.
- `SignaturePruning.cpp` owns the pass-specific policy: GC gate, `--closed-world` fatal guard, whole-module table bailout, two-iteration cap, heap-type-level fact aggregation, direct-call and `call_ref` user collection, blocker marking, constant-actual promotion, synchronized parameter removal, signature rewriting, and delayed call-operand localization.
- `param-utils.*` supplies most of the mechanics that make the pass visible: entry-liveness parameter usage, constant-actual materialization into callee bodies, actual parameter removal across functions and call sites, and one localization pass for blocked operands.
- `module-utils.*` supplies the parallel function-analysis skeleton and public heap-type discovery that define the pass's closed-world visibility boundary.
- `type-updating.h` supplies `GlobalTypeRewriter::updateSignatures(...)`, the module-wide nominal signature rewrite step that keeps direct function declarations and `call_ref` sites coherent.
- `intrinsics.*` supplies the `call.without.effects` and JS-called-function boundaries, while `subtypes.h`, `possible-constant.h`, `localize.h`, `eh-utils.h`, and `liveness-traversal.h` supply the subtype, constant, localization, EH, and liveness helper surfaces the dossier cites.
- The dedicated lit file proves the important positive and negative families: direct-call and `call_ref` pruning, all-parameter removal, overwritten-parameter entry-liveness, constant/ref/null actual promotion, side-effect localization wins, imported/public/tag/continuation/subtyping/table blockers, `call.without.effects` no-op handling, local-index repair, v128-local repair, and EH-pop localization regressions.
- Starshine-specific follow-up in this run did not find a local implementation file. The durable local fact is that `signature-pruning` is a preserved **boundary-only** registry name, not an active HOT or module pass; it is also absent from the active `optimize` / `shrink` presets and has no dedicated backlog slice today.
- A narrow 2026-04-24 current-`main` spot check on the owner file, registration surface, helper files, and dedicated lit file did not surface teaching-relevant contract drift from the reviewed `version_129` story. The durable claim is intentionally narrow, not a whole-repo equivalence proof.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
