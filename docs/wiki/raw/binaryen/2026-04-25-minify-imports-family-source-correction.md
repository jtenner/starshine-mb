# Binaryen `minify-imports` family source correction

_Capture date:_ 2026-04-25  
_Status:_ immutable source-correction manifest for `minify-imports` and the existing `minify-imports-and-exports` dossier

## Scope

This file captures a focused primary-source recheck after the first `minify-imports-and-exports` dossier over-attributed name-map generation to `WasmBinaryBuilder::getSymbolMap(...)` and did not give the separate public `minify-imports` pass its own home.

Use the living pages for explanation:

- `docs/wiki/binaryen/passes/minify-imports/index.md`
- `docs/wiki/binaryen/passes/minify-imports/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/minify-imports/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/minify-imports/wat-shapes.md`
- `docs/wiki/binaryen/passes/minify-imports/starshine-strategy.md`
- `docs/wiki/binaryen/passes/minify-imports-and-exports/index.md`

## Provenance

### Official release and source pages consulted

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Page observed on 2026-04-25.
  - This is the tagged source baseline used by the surrounding pass wiki.
- `MinifyImports.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MinifyImports.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/MinifyImports.cpp>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/MinifyImports.cpp>
  - Key reviewed locations:
    - the `MinifyImports` `Pass` class;
    - `modifiesBinaryenIR() == false`;
    - the imported-function walk through `ModuleUtils::iterImportedFunctions(...)`;
    - `Names::MinifiedNameGenerator` used to allocate one short name per imported function base name;
    - stdout emission of `old:new` mapping lines.
- `MinifyImportsAndExports.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MinifyImportsAndExports.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/MinifyImportsAndExports.cpp>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/MinifyImportsAndExports.cpp>
  - Key reviewed locations:
    - the `MinifyImportsAndExports` `Pass` class and its `minifyModules` option;
    - collection of import base names, export names, optional import module names, and used name-section names;
    - `Names::MinifiedNameGenerator`-based `mapNames(...)` helper;
    - `minifyImport(...)` and `minifyExport(...)` mutating module declaration strings;
    - source-backed absence of a `WasmBinaryBuilder::getSymbolMap(...)` dependency in this pass file.
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - Key reviewed locations:
    - public registration for `minify-imports`, described as import-name-only map emission;
    - public registration for `minify-imports-and-exports`;
    - public registration for sibling `minify-imports-and-exports-and-modules`.
- `passes.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/passes.h>
  - Key reviewed locations:
    - `createMinifyImportsPass()` declaration;
    - `createMinifyImportsAndExportsPass(bool minifyModules)` declaration.
- `module-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm/wasm-module-utils.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/wasm/wasm-module-utils.h>
  - Key reviewed location: `ModuleUtils::iterImportedFunctions(...)`, the imported-function traversal used by `MinifyImports.cpp`.
- `names.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/support/name.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/support/name.h>
  - Key reviewed location: `Names::MinifiedNameGenerator`, the short-name generator used by both minify owner files.

### Official Binaryen tests checked

- `test/passes/minify-imports-and-exports-and-modules.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/minify-imports-and-exports-and-modules.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/passes/minify-imports-and-exports-and-modules.wast>
  - Key reviewed surface: imported functions, globals, memory, and table with long module/base names plus exports with long names.
- `test/passes/minify-imports-and-exports-and-modules.txt`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/minify-imports-and-exports-and-modules.txt>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/passes/minify-imports-and-exports-and-modules.txt>
  - Key reviewed surface: shortened module names, import base names, and export names while imported/exported entity kinds stay intact.

This recheck did not find a dedicated `test/passes/minify-imports.wast` / `.txt` pair in the official `version_129` pass test surface. Treat the plain `minify-imports` pass as source-confirmed by `MinifyImports.cpp`, `pass.cpp`, and `passes.h`, not by a dedicated lit file.

### Local Starshine sources inspected

- `src/passes/optimize.mbt`
  - Registry status and request expansion.
- `src/passes/pass_manager.mbt`
  - Active module-pass dispatcher.
- `src/lib/types.mbt`
  - `Import`, `Export`, `ImportSec`, `ExportSec`, and `Module` representation.
- `src/binary/decode.mbt`
  - Import/export section decoding.
- `src/binary/encode.mbt`
  - Import/export section encoding.
- `src/wast/lower_to_lib.mbt`
  - Text import/export lowering into `@lib.Import` and `@lib.Export` records.

## Durable observations from the captured sources

- `minify-imports` is a separate public Binaryen pass in `version_129`, not the plain mode of `minify-imports-and-exports`.
- `minify-imports` is map-emitting and reports `modifiesBinaryenIR() == false`; it does not rewrite the module's import section.
- `minify-imports` only walks imported functions through `ModuleUtils::iterImportedFunctions(...)`; it does not cover imported globals, memories, tables, tags, export names, or import module names.
- The mapping output is one line per imported function base name, shaped as `old:new` on stdout.
- `minify-imports-and-exports` and `minify-imports-and-exports-and-modules` are mutating module passes owned by `MinifyImportsAndExports.cpp`.
- `minify-imports-and-exports` rewrites import base names and export names; the `-and-modules` sibling also rewrites import module names.
- The mutating pass family uses `Names::MinifiedNameGenerator` and used-name avoidance in the pass owner file. The earlier living pages and raw manifest that said the family delegates maps to `WasmBinaryBuilder::getSymbolMap(...)` were stale/incorrect for `version_129` and are superseded for that claim by this capture.
- Starshine currently has no registry entry, owner file, dispatcher case, or backlog slice for `minify-imports`, `minify-imports-and-exports`, or `minify-imports-and-exports-and-modules`.

## Uncertainty and caveats

- The exact stdout ordering for `minify-imports` follows Binaryen's imported-function traversal order and should be checked directly in implementation tests if Starshine ever emulates the pass.
- The exact generated short-name sequence comes from `Names::MinifiedNameGenerator`; future parity work should re-read that helper in the target upstream revision.
- The absence of a dedicated `minify-imports` lit file means this dossier relies on source and registry proof for the plain pass.
- `minify-imports` is not an optimizer in the ordinary module-rewrite sense; it is closer to a packaging/reporting pass that helps external tooling build a renamed import surface.

## Supersession note

This capture supersedes `docs/wiki/raw/binaryen/2026-04-25-minify-imports-and-exports-primary-sources.md` and `docs/wiki/raw/research/0342-2026-04-25-minify-imports-and-exports-source-dossier.md` only for the claim that `WasmBinaryBuilder::getSymbolMap(...)` computes the pass family's rename maps. The old files remain useful as historical provenance for why the first dossier was added and for the broad import/export ABI warning.
