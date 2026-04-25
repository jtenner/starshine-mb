---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-minify-imports-and-exports-primary-sources.md
  - ../../../raw/research/0342-2026-04-25-minify-imports-and-exports-source-dossier.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
---

# Binaryen strategy for `minify-imports-and-exports`

## Source-backed contract

Binaryen implements `minify-imports-and-exports` and `minify-imports-and-exports-and-modules` in the same owner file: `src/passes/MinifyImportsAndExports.cpp`.
The public pass split is a single boolean:

- `minifyModules = false` for `minify-imports-and-exports`;
- `minifyModules = true` for `minify-imports-and-exports-and-modules`.

The strategy is:

1. ask `WasmBinaryBuilder::getSymbolMap(...)` to compute short-name maps for imports, exports, import/export names, and modules;
2. walk module imports and apply the import-name map to each import base name;
3. when `minifyModules` is true, also apply the module-name map to each import module string;
4. walk module exports and apply the export-name map to each export name;
5. leave the imported/exported entity kinds and index targets intact.

## Why Binaryen delegates name choice

The pass file is intentionally small because name allocation is not a local peephole decision.
A valid minifier must coordinate names across all imports and exports so it does not create collisions or invalid names.
Binaryen centralizes that logic in the symbol-map builder rather than deriving names inside each import/export visitor.

This matters for Starshine parity: implementing a quick `a`, `b`, `c` counter over one section may pass trivial examples but still drift from Binaryen on mixed import/export modules, reserved names, collisions, or sibling module-name behavior.

## Plain pass versus `-and-modules`

The plain pass rewrites only:

- import base names;
- export names.

It does **not** rewrite import module names.
For example, if an import starts as:

```wat
(import "env" "long_function_name" (func))
```

the plain pass may shorten `"long_function_name"` but should keep `"env"`.

The sibling also rewrites the first string:

```wat
(import "long_module_name" "long_function_name" (func))
```

may become a pair of short generated names.

The upstream help text makes this distinction explicit, so docs and tests should not collapse the two pass names into one vague “minify all external names” story.

## What stays stable

The pass should preserve:

- function bodies and expressions;
- type, function, table, memory, global, tag, element, data, and code section structure;
- export target indices;
- import external kinds and their types;
- internal function names and locals, except for any unrelated name-section output effects outside this pass's contract.

A host-visible string changes, but the module still imports and exports the same kinds of things.

## Pipeline role

This is a size and packaging pass.
It is useful when a producer controls the host glue or when external symbol names are intentionally unstable.
It is unsafe as a transparent optimizer for modules whose imports or exports are part of a stable public ABI.

Unlike [`strip-target-features`](../strip-target-features/index.md), this pass mutates in-memory module declarations rather than only toggling output metadata.
Unlike [`duplicate-import-elimination`](../duplicate-import-elimination/index.md), it does not merge or remove imports.

## Main caveat

The official test surface reviewed for this run directly proves the `-and-modules` sibling.
The plain pass remains source-confirmed through the constructor flag, `pass.cpp` registration, and shared implementation.
A future implementation signoff should add direct local tests for both names instead of relying on the sibling proof alone.
