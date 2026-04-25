---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-minify-imports-family-source-correction.md
  - ../../../raw/binaryen/2026-04-25-minify-imports-and-exports-primary-sources.md
  - ../../../raw/research/0343-2026-04-25-minify-imports-source-correction.md
  - ../../../raw/research/0342-2026-04-25-minify-imports-and-exports-source-dossier.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../minify-imports/binaryen-strategy.md
---

# Binaryen strategy for `minify-imports-and-exports`

## Source-backed contract

Binaryen implements `minify-imports-and-exports` and `minify-imports-and-exports-and-modules` in the same owner file: `src/passes/MinifyImportsAndExports.cpp`.
The public pass split is a single boolean:

- `minifyModules = false` for `minify-imports-and-exports`;
- `minifyModules = true` for `minify-imports-and-exports-and-modules`.

The strategy is:

1. collect import base names from `module->imports`;
2. collect export names from `module->exports`;
3. when `minifyModules` is true, collect import module names as well;
4. collect already-used names from relevant name-section surfaces so generated names do not collide with them;
5. run `Names::MinifiedNameGenerator` through the pass's `mapNames(...)` helper to assign short names that avoid the used-name set;
6. walk module imports and apply the import-base map;
7. when `minifyModules` is true, also apply the module-name map;
8. walk module exports and apply the export-name map;
9. leave imported/exported entity kinds and index targets intact.

The earlier first-pass dossier said this family delegates map construction to `WasmBinaryBuilder::getSymbolMap(...)`.
The 2026-04-25 source-correction recheck supersedes that claim for Binaryen `version_129`: the reviewed owner file uses `Names::MinifiedNameGenerator` directly.

## Why Binaryen collects used names first

The pass is not just a naive counter over imports and exports.
It avoids generating names that would collide with names already present in relevant module metadata, including name-section-derived function/local/label surfaces.

This matters for Starshine parity: a trivial `a`, `b`, `c` generator over only imports and exports may pass simple WAT examples but drift on modules with existing short names or name sections.

## Plain pass versus `-and-modules`

The plain mutating pass rewrites only:

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

## Split from `minify-imports`

[`minify-imports`](../minify-imports/index.md) is a separate public pass owned by `MinifyImports.cpp`.
It reports `modifiesBinaryenIR() == false`, walks only imported functions, and emits a map.
It should not be taught as the plain mode of this mutating pass family.

## What stays stable

The mutating pass family should preserve:

- function bodies and expressions;
- type, function, table, memory, global, tag, element, data, and code section structure;
- export target indices;
- import external kinds and their types;
- internal function names and locals, except for unrelated printer/name-section effects outside this pass's contract.

A host-visible string changes, but the module still imports and exports the same kinds of things.

## Pipeline role

This is a size and packaging pass.
It is useful when a producer controls the host glue or when external symbol names are intentionally unstable.
It is unsafe as a transparent optimizer for modules whose imports or exports are part of a stable public ABI.

Unlike [`strip-target-features`](../strip-target-features/index.md), this pass mutates in-memory module declarations rather than only toggling output metadata.
Unlike [`duplicate-import-elimination`](../duplicate-import-elimination/index.md), it does not merge or remove imports.

## Main caveat

The official test surface reviewed for this run directly proves the `-and-modules` sibling.
The plain mutating pass remains source-confirmed through the constructor flag, `pass.cpp` registration, and shared implementation.
A future implementation signoff should add direct local tests for both mutating names and keep the separate non-mutating `minify-imports` pass in its own lane.
