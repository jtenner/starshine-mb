# Binaryen `type-unfinalizing` primary-source capture

_Capture date:_ 2026-04-24  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/type-un-finalizing/` dossier

## Scope

This file captures the primary online sources consulted for the 2026-04-24 `type-un-finalizing` / upstream `type-unfinalizing` follow-up.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/type-un-finalizing/index.md`
- `docs/wiki/binaryen/passes/type-un-finalizing/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/type-un-finalizing/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/type-un-finalizing/private-boundaries-sibling-split-and-no-leaf-rule.md`
- `docs/wiki/binaryen/passes/type-un-finalizing/wat-shapes.md`
- `docs/wiki/binaryen/passes/type-un-finalizing/starshine-strategy.md`

## Provenance

### Official release pages consulted

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Page observed on 2026-04-24.
  - GitHub showed the publish date as **2026-04-01 14:31**.
  - The page identified `version_129` as the latest release when reviewed.
- Binaryen GitHub releases index
  - URL: <https://github.com/WebAssembly/binaryen/releases>
  - Page observed on 2026-04-24.
  - Used to keep the dossier anchored to the official release surface reviewed in this run.

### Official source files consulted

- `TypeFinalizing.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/TypeFinalizing.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/TypeFinalizing.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/TypeFinalizing.cpp>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/TypeFinalizing.cpp>
  - Reviewed as the shared owner of both public `type-finalizing` and public `type-unfinalizing`.
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
  - Reviewed as the public pass-registration surface and the default-scheduler surface.
- `module-utils.h` / `module-utils.cpp`
  - `version_129` header: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.h>
  - `version_129` implementation: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.cpp>
  - Reviewed as the owner of `ModuleUtils::getPrivateHeapTypes(...)`, the visibility boundary for the sibling.
- `type-updating.h` / `type-updating.cpp`
  - `version_129` header: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h>
  - `version_129` implementation: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.cpp>
  - Reviewed as the owner of the shared `GlobalTypeRewriter` machinery used to rebuild heap types and their references coherently.
- `subtypes.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/subtypes.h>
  - Reviewed as the owner of the finalizing-only leaf proof that `type-unfinalizing` deliberately does not need.

### Official test files consulted

- `type-finalizing.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/type-finalizing.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/type-finalizing.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/type-finalizing.wast>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/type-finalizing.wast>
  - Reviewed as the dedicated public proof surface for both `--type-finalizing` and `--type-unfinalizing`.

## Durable observations from the captured sources

- The reviewed official release surface still anchored cleanly on Binaryen `version_129` for this pass on 2026-04-24, with the tagged release page showing publish date **2026-04-01 14:31**.
- `pass.cpp` registers public upstream `type-unfinalizing`. The local Starshine spelling remains `type-un-finalizing`, so the extra hyphen is a local alias difference rather than Binaryen spelling.
- `TypeFinalizing.cpp` owns the whole family: one `TypeFinalizing(bool finalize)` implementation, one GC gate, one private-type candidate set, one `GlobalTypeRewriter` subclass, and one `setOpen(!finalize)` mutation.
- In unfinalizing mode, Binaryen does **not** construct or need the finalizing sibling's `SubTypes` leaf proof. Privacy alone determines the modifiable set.
- `type-unfinalizing` reopens private heap types, including private non-leaf types. It does not request closed-world mode, delete types, merge types, prune subtype edges, reorder types, or walk expression bodies.
- The dedicated `type-finalizing.wast` file proves the public-vs-private boundary, the sibling split, globals/locals staying coherent after rewriting, and function heap-type participation.
- Starshine-specific follow-up in this run did not find a local implementation file. The durable local fact is that `type-un-finalizing` is a preserved **boundary-only** registry name, not an active HOT or module pass.
- A narrow 2026-04-24 current-`main` spot check on the owner file and dedicated lit file did not surface teaching-relevant contract drift from the reviewed `version_129` story. The durable claim is intentionally narrow, not a whole-repo equivalence proof.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
