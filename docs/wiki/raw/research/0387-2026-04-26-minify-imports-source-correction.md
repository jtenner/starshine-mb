# 0387 - `minify-imports` source correction

_Date:_ 2026-04-26  
_Status:_ absorbed into living wiki pages  
_Related living pages:_

- `docs/wiki/binaryen/passes/minify-imports/index.md`
- `docs/wiki/binaryen/passes/minify-imports/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/minify-imports/env-wasi-json-map-and-module-merge.md`
- `docs/wiki/binaryen/passes/minify-imports/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/minify-imports/wat-shapes.md`
- `docs/wiki/binaryen/passes/minify-imports/starshine-strategy.md`
- `docs/wiki/binaryen/passes/minify-imports-and-exports/index.md`

## Question

The existing Starshine wiki taught `minify-imports` as a non-mutating imported-function map-emission helper. Rechecking official Binaryen sources was necessary because the pass folder still had only `dossier` coverage and the described owner file did not match the official source tree.

## Primary-source result

Official Binaryen `version_129` and current `main` implement `minify-imports`, `minify-imports-and-exports`, and `minify-imports-and-exports-and-modules` in the shared owner `src/passes/MinifyImportsAndExports.cpp`. `createMinifyImportsPass()` constructs the shared pass with `minifyExports = false` and `minifyModules = false`.

The corrected contract is:

- plain `minify-imports` mutates qualifying import base names;
- plain mode only minifies imports whose module is `env` or begins with `wasi_`;
- the pass walks all imports, not only functions;
- the pass emits JSON-shaped `imports` mapping entries, not one `old:new` line per imported function;
- `minify-imports-and-exports` adds export-name mutation;
- `minify-imports-and-exports-and-modules` minifies all import base names and rewrites import module names to one shared short module;
- the family is ABI-visible and must be treated as host-glue-breaking unless tooling updates the boundary consistently.

## Starshine result

Starshine remains unimplemented for all three public minification names:

- no boundary-only, removed, or active entry exists in `src/passes/optimize.mbt`;
- requests still fail through `unknown pass flag ...` in `src/passes/optimize.mbt:462-465`;
- no module dispatcher case exists near `src/passes/pass_manager.mbt:8661-8664`;
- no `src/passes/minify_imports*.mbt` owner file exists;
- no active backlog slice exists.

The future port is a module-pass/reporting hybrid: it must mutate import/export declarations, update maps, and decide how Starshine should surface Binaryen-compatible JSON output without corrupting optimized wasm stdout.

## Superseded claims

This note supersedes `docs/wiki/raw/research/0343-2026-04-25-minify-imports-source-correction.md` for the plain-pass mechanics. The older note remains useful provenance for why the family needed a dedicated dossier and for the valid correction away from `WasmBinaryBuilder::getSymbolMap(...)` as the family map source.

## Validation ideas for a future implementation

1. plain `minify-imports` fixture with `env` function/table/memory/global/tag imports proves all kinds can rename;
2. custom non-`env` import stays unchanged in plain mode;
3. `wasi_` import renames in plain mode;
4. `minify-imports-and-exports` additionally renames exports;
5. `minify-imports-and-exports-and-modules` renames all import bases and merges module names to the short singleton;
6. stdout JSON is captured separately from optimized wasm output;
7. module maps and binary roundtrip remain consistent after declaration-string mutation.
