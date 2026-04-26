# Binaryen `minify-imports` current-main source correction

_Capture date:_ 2026-04-26  
_Status:_ immutable source-correction manifest for the plain `minify-imports` pass and the import/export minification family

## Scope

This capture corrects the 2026-04-25 living wiki and raw manifest for `minify-imports`. The earlier dossier described a separate non-mutating `MinifyImports.cpp` owner that walks imported functions and prints `old:new` lines. Official Binaryen `version_129` and current `main` do **not** have that owner or contract. The plain public pass is one constructor mode of `src/passes/MinifyImportsAndExports.cpp`.

Use the living pages for explanation:

- `docs/wiki/binaryen/passes/minify-imports/index.md`
- `docs/wiki/binaryen/passes/minify-imports/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/minify-imports/env-wasi-json-map-and-module-merge.md`
- `docs/wiki/binaryen/passes/minify-imports/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/minify-imports/wat-shapes.md`
- `docs/wiki/binaryen/passes/minify-imports/starshine-strategy.md`
- `docs/wiki/binaryen/passes/minify-imports-and-exports/index.md`

## Official sources consulted

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Page observed on 2026-04-26.
- `src/passes/MinifyImportsAndExports.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MinifyImportsAndExports.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/MinifyImportsAndExports.cpp>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/MinifyImportsAndExports.cpp>
  - raw current `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/MinifyImportsAndExports.cpp>
  - Reviewed locations:
    - file header says the family minifies import/export names, rewrites them to short versions, and prints a mapping for JS/wasm boundary tooling;
    - `MinifyImportsAndExports(bool minifyExports, bool minifyModules)` controls all three public pass names;
    - `ModuleUtils::iterImports(...)` visits all importable kinds, not only functions;
    - the plain mode minifies an import base name only when `curr->module == ENV` or `curr->module.startsWith("wasi_")`;
    - `minifyModules` mode minifies all import base names, then rewrites every import module to singleton module name `"a"`;
    - `minifyExports` mode additionally minifies every export name;
    - `module->updateMaps()` runs after base/export-name mutation;
    - stdout is JSON-shaped with `imports` entries `[oldModule, oldBase, newBase]` and `exports` entries `[oldExport, newExport]`.
- `src/passes/pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - Reviewed location: the registry describes `minify-imports` as minifying import names and emitting a map, `minify-imports-and-exports` as minifying imports plus exports, and `minify-imports-and-exports-and-modules` as also minifying modules.
- `src/passes/passes.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/passes.h>
  - Reviewed locations: the three factories are separate public names but are all implemented by the shared owner file.
- Official pass tests checked from the release tree:
  - `test/passes/minify-imports-and-exports-and-modules.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/minify-imports-and-exports-and-modules.wast>
  - `test/passes/minify-imports-and-exports-and-modules.txt`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/minify-imports-and-exports-and-modules.txt>
  - No dedicated `test/passes/minify-imports.wast` / `.txt` pair was found in the reviewed pass-test surface.

## Durable observations

- There is no separate `src/passes/MinifyImports.cpp` in official `version_129` or current `main`; the earlier Starshine wiki attribution to that file is stale.
- `createMinifyImportsPass()` returns `new MinifyImportsAndExports(false, false)`.
- The plain `minify-imports` pass **does mutate the module** by shortening qualifying import base names.
- The plain pass scans all imports through `ModuleUtils::iterImports(...)`; it is not function-only.
- In plain mode, Binaryen deliberately restricts import-base minification to imports from module `env` or modules whose names begin with `wasi_`.
- The mapping output is JSON-shaped, not one `old:new` line per function.
- `minify-imports-and-exports` uses the same import-base logic as the plain pass and additionally rewrites export names.
- `minify-imports-and-exports-and-modules` minifies all import base names regardless of original module name and then rewrites every import module name to singleton module `"a"`.
- The shared owner uses `(oldModule, oldBase)` keys for imports so identical base names from different old modules can get distinct generated names before optional module-name merging.
- Starshine still has no local registry entry, owner file, dispatcher case, or backlog slice for any of the three minification names.

## Uncertainty and caveats

- Because there is no dedicated official plain-`minify-imports` lit fixture in the reviewed tree, future parity tests should directly check plain-mode module mutation, JSON output order, `env`/`wasi_` gating, and non-`env` custom-module negatives against the targeted Binaryen executable.
- The line-rendered raw GitHub view is compressed by the web fetcher, but the same current-main and `version_129` source text agree on the teaching-level contract.
- The host ABI warning is stronger than in the stale dossier: the plain pass is not just a suggestion/report; it changes import strings for qualifying imports and requires corresponding host glue updates.

## Supersession note

This capture supersedes `docs/wiki/raw/binaryen/2026-04-25-minify-imports-family-source-correction.md` and `docs/wiki/raw/research/0343-2026-04-25-minify-imports-source-correction.md` for these claims: separate `MinifyImports.cpp` owner, non-mutating plain pass, imported-function-only traversal, `old:new` line output, and no module-section rewrite. It preserves the valid claims that the family uses `Names::MinifiedNameGenerator`, is ABI-facing, and is locally unimplemented in Starshine.
