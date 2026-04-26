# Binaryen `strip-toolchain-annotations` port-readiness primary-source capture

_Capture date:_ 2026-04-26  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/strip-toolchain-annotations/` port-readiness update

## Scope

This file rechecks the official upstream sources for `strip-toolchain-annotations` and records the extra Starshine-port questions that were not explicit in the 2026-04-24 dossier.
Use the living pages for explanation:

- `docs/wiki/binaryen/passes/strip-toolchain-annotations/index.md`
- `docs/wiki/binaryen/passes/strip-toolchain-annotations/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/strip-toolchain-annotations/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/strip-toolchain-annotations/wat-shapes.md`
- `docs/wiki/binaryen/passes/strip-toolchain-annotations/starshine-strategy.md`
- `docs/wiki/binaryen/passes/strip-toolchain-annotations/starshine-port-readiness-and-validation.md`

## Official Binaryen sources rechecked

- `src/passes/StripToolchainAnnotations.cpp`
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/StripToolchainAnnotations.cpp>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/StripToolchainAnnotations.cpp>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/StripToolchainAnnotations.cpp>
  - Durable facts: the pass header still frames the pass as removing VM-unneeded toolchain annotations after toolchain optimizations are done; the implementation remains a function-parallel `WalkerPass<PostWalker<...>>`; `requiresNonNullableLocalFixups()` remains `false`; `doWalkFunction(...)` strips `funcAnnotations` and `codeAnnotations`; `remove(CodeAnnotation&)` clears `removableIfUnused`, `jsCalled`, and `idempotent`; empty per-expression entries are erased.
- `src/passes/pass.cpp`
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
  - Durable fact: the public pass registry still registers `strip-toolchain-annotations` with the description `strip all toolchain-specific code annotations` and the `createStripToolchainAnnotationsPass` factory.
- `test/lit/passes/strip-toolchain-annotations.wast`
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/strip-toolchain-annotations.wast>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/strip-toolchain-annotations.wast>
  - Durable facts: the lit test still removes `@binaryen.removable.if.unused` and `@binaryen.idempotent`, preserves `@metadata.code.inline`, and checks both mixed-order cases where the preserved inline metadata appears before or after the removed toolchain annotation.
- `CHANGELOG.md`
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/CHANGELOG.md>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/CHANGELOG.md>
  - Durable facts: the release-note trail still records `@binaryen.idempotent` in `v127`; `@binaryen.removable.if.unused`, `@binaryen.js.called`, and `--strip-toolchain-annotations` in `v126`; and frames the pass as covering those intrinsics plus future similar annotations.

## Starshine surfaces rechecked locally

- `src/passes/optimize.mbt:126-153` - boundary-only and removed name lists; `strip-toolchain-annotations` remains absent.
- `src/passes/optimize.mbt:156-267` - active hot/module/preset registry; no entry exists for this pass.
- `src/passes/optimize.mbt:446-489` - unknown-pass rejection path; explicit requests still fail as `unknown pass flag strip-toolchain-annotations`.
- `src/lib/types.mbt:335-348` and `src/lib/types.mbt:8089-8108` - in-memory `FuncAnnotation`, `FuncAnnotationAssoc`, and `FuncAnnotationSec` records plus constructors.
- `src/wast/parser.mbt:750-800` - WAT annotation parsing and current attachment restriction to functions and function imports.
- `src/wast/lower_to_lib.mbt:196-205` and `src/wast/lower_to_lib.mbt:2894-3020` - lowering of WAT annotations into `FuncAnnotationSec` entries for function imports and definitions.
- `src/wast/module_wast_tests.mbt:78-110`, `src/wast/parser.mbt:5378-5407`, and `src/wast/lower_to_lib.mbt:5281-5304` - local tests preserve `binaryen.js.called`, `binaryen.idempotent`, and `metadata.code.inline`; no local test in this recheck covered `binaryen.removable.if.unused`.
- `src/passes/duplicate_function_elimination.mbt:2663-2694` and `src/passes/duplicate_function_elimination.mbt:3034-3072` - existing pass code remaps annotations and includes them in function equivalence/hashing.
- `src/passes/duplicate_import_elimination.mbt:310-332` and `src/passes/remove_unused_module_elements.mbt:1703-1724` - additional module passes already preserve/remap function-annotation indices when they rewrite import/function spaces.

## Port-readiness conclusions

- No teaching-relevant drift was found between the 2026-04-24 dossier and official Binaryen `main` on 2026-04-26.
- The safest future Starshine first slice is a module pass over `FuncAnnotationSec`, because that is the local annotation surface that exists today.
- A first slice can strip only exact annotation names `binaryen.removable.if.unused`, `binaryen.idempotent`, and `binaryen.js.called`, preserve every other annotation including `metadata.code.inline`, and drop association entries whose annotation array becomes empty.
- The first slice must be documented as a Starshine subset, not Binaryen parity, because Binaryen also strips per-expression `codeAnnotations` and Starshine does not currently expose a matching per-expression annotation map.
- A faithful parity port needs either a per-expression annotation representation or a deliberate statement that Starshine only supports the locally parsed function/function-import annotation surface.
- Registry honesty is the first implementation choice: keep the pass unknown, add it as boundary-only, or add an active module pass. The current wiki should not imply active support.

## Uncertainty and caveats

- The local binary encoder/decoder surface for `FuncAnnotationSec` still needs a focused source audit before promising binary roundtrip parity for this pass.
- `binaryen.removable.if.unused` was not found in local Starshine tests during this focused grep, even though Binaryen's lit file uses it directly. A future Starshine port should add it to parser/lowering/roundtrip tests before or with the strip-pass test.
- `jsCalled` remains source-backed upstream but not directly isolated by the dedicated Binaryen lit file reviewed here.

## Consumability rule

Cite this source capture together with the living pass pages when explaining the 2026-04-26 port-readiness ladder. Do not replace the living pages with this raw manifest.
