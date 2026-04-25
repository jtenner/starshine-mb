---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-minify-imports-family-source-correction.md
  - ../../../raw/research/0343-2026-04-25-minify-imports-source-correction.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../minify-imports-and-exports/binaryen-strategy.md
---

# Binaryen strategy for `minify-imports`

## Source-backed contract

Binaryen implements `minify-imports` in `src/passes/MinifyImports.cpp`.
The pass is separate from `src/passes/MinifyImportsAndExports.cpp`.

The strategy is intentionally small:

1. declare that the pass does not modify Binaryen IR;
2. construct a `Names::MinifiedNameGenerator`;
3. walk imported functions with `ModuleUtils::iterImportedFunctions(...)`;
4. assign each imported function base name a generated short name;
5. print `old:new` mapping lines to stdout.

No module section is rebuilt.
No function body is rewritten.
No export is renamed.

## Why `modifiesBinaryenIR() == false` matters

`minify-imports` is closer to a reporting/packaging helper than a normal optimizer.
A consumer can use the emitted map to rewrite host glue or another artifact, but the pass itself does not change the wasm module in memory.

That makes it very different from [`minify-imports-and-exports`](../minify-imports-and-exports/index.md), whose owner mutates import/export declarations.

## Imported-function-only scope

The owner file walks imported functions, not all imports.
Therefore the source-backed surface is:

- yes: `(import "m" "f" (func ...))` base names;
- no: imported memories;
- no: imported tables;
- no: imported globals;
- no: imported tags;
- no: export names;
- no: import module strings.

This is a common place to overgeneralize from the pass name.
The mutating `minify-imports-and-exports` family covers more external declaration kinds; `minify-imports` does not.

## Name generation

The generated names come from `Names::MinifiedNameGenerator`.
The pass owner does not call `WasmBinaryBuilder::getSymbolMap(...)`.
That earlier attribution in the first import/export minification dossier is stale for Binaryen `version_129`.

A faithful Starshine port should re-read `Names::MinifiedNameGenerator` in the exact Binaryen revision targeted for parity, then test both generated names and emitted ordering.

## Pipeline role

The pass is useful when a toolchain wants an import-name map without letting Binaryen rewrite the module.
Possible consumers include host-glue generators or downstream packagers that want to decide themselves how and whether to apply a rename.

It is not a transparent optimizer for general wasm files because import names are host ABI.
Even emitting a suggested map implies the host and module producer must coordinate.

## Main caveat

This run did not find a dedicated `minify-imports.wast` / expected-output pair in the official `version_129` pass tests.
The pass is still source-confirmed through `MinifyImports.cpp`, `pass.cpp`, and `passes.h`, but future implementation signoff should include local tests for stdout and no module mutation.
