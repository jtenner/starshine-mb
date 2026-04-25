# Binaryen `minify-imports-and-exports` primary-source capture

_Capture date:_ 2026-04-25  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/minify-imports-and-exports/` dossier

## Scope

This file captures the primary online sources consulted for the 2026-04-25 `minify-imports-and-exports` dossier.
Use the living pages for explanation:

- `docs/wiki/binaryen/passes/minify-imports-and-exports/index.md`
- `docs/wiki/binaryen/passes/minify-imports-and-exports/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/minify-imports-and-exports/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/minify-imports-and-exports/wat-shapes.md`
- `docs/wiki/binaryen/passes/minify-imports-and-exports/starshine-strategy.md`

## Provenance

### Official release and source pages consulted

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Page observed on 2026-04-25.
  - This is the tagged source baseline used by the surrounding pass wiki.
- `MinifyImportsAndExports.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MinifyImportsAndExports.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/MinifyImportsAndExports.cpp>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/MinifyImportsAndExports.cpp>
  - Key reviewed locations:
    - the `MinifyImportsAndExports` `Pass` class and its `minifyModules` option;
    - the `minifyImport(...)` helper that rewrites import base names and, in the sibling mode, import module names;
    - the `minifyExport(...)` helper that rewrites export names;
    - the `run(...)` method that asks `WasmBinaryBuilder::getSymbolMap(...)` for import, export, import/export, and module maps and then applies them with `mapNames(...)`.
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - Key reviewed locations:
    - public registration for `minify-imports-and-exports`;
    - public registration for sibling `minify-imports-and-exports-and-modules`;
    - help text stating that the first pass minifies import/export names only, while the sibling also minifies module names.
- `passes.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/passes.h>
  - Key reviewed location: `createMinifyImportsAndExportsPass(bool minifyModules)` declaration.
- `wasm-binary.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm/wasm-binary.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/wasm/wasm-binary.h>
  - Key reviewed location: `WasmBinaryBuilder::getSymbolMap(...)`, the source of the import/export/module name maps used by the pass.

### Official Binaryen tests consulted

- `minify-imports-and-exports-and-modules.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/minify-imports-and-exports-and-modules.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/passes/minify-imports-and-exports-and-modules.wast>
  - Key reviewed surface: imported functions, globals, memory, and table with long module/base names plus exports with long names.
- `minify-imports-and-exports-and-modules.txt`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/minify-imports-and-exports-and-modules.txt>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/passes/minify-imports-and-exports-and-modules.txt>
  - Key reviewed surface: before/after output showing shortened module names, import base names, and export names while keeping the imported/ exported entity kinds intact.

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

- `minify-imports-and-exports` is a real public Binaryen pass in `version_129`.
- It is a module-level name rewrite, not an instruction optimizer.
- The primary pass rewrites import base names and export names.
- The sibling `minify-imports-and-exports-and-modules` uses the same owner file and additionally rewrites import module names.
- The pass gets its renaming plan from `WasmBinaryBuilder::getSymbolMap(...)`; the pass itself mostly applies those maps to `module->imports` and `module->exports`.
- The transform should preserve the imported/exported entity kinds and internal references. It changes the external strings that hosts and downstream tools use to link or discover imports/exports.
- The official lit surface directly proves the sibling with module-name minification; the plain pass's no-module-name variant is source-confirmed through the constructor flag and `pass.cpp` registration.
- Starshine currently has no registry entry, owner file, dispatcher case, or backlog slice for this pass family.

## Uncertainty and caveats

- The precise `WasmBinaryBuilder::getSymbolMap(...)` short-name ordering should be source-confirmed again before implementation signoff; this capture records the pass-level contract and source locations, not a complete reimplementation of Binaryen's name allocator.
- The dedicated lit file reviewed here is for `minify-imports-and-exports-and-modules`. The plain `minify-imports-and-exports` behavior is source-backed by the `minifyModules = false` constructor path and registry help text rather than by a separate reviewed WAT file.
- This pass is externally visible. A wasm host that imports by exact `(module, name)` pairs or consumes export names can break if the producer and consumer do not agree on the renaming map.
- Starshine can represent and encode the relevant names today, but that is only prerequisite infrastructure. There is no transform that computes or applies a Binaryen-compatible name map.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
