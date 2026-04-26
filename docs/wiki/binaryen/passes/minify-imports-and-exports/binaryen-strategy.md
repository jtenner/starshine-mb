---
kind: concept
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-minify-imports-current-main-source-correction.md
  - ../../../raw/binaryen/2026-04-25-minify-imports-family-source-correction.md
  - ../../../raw/binaryen/2026-04-25-minify-imports-and-exports-primary-sources.md
  - ../../../raw/research/0387-2026-04-26-minify-imports-source-correction.md
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

Binaryen implements `minify-imports`, `minify-imports-and-exports`, and `minify-imports-and-exports-and-modules` in the same owner file: `src/passes/MinifyImportsAndExports.cpp`.

The public pass split is controlled by two flags:

- `minifyExports = false`, `minifyModules = false` for plain `minify-imports`;
- `minifyExports = true`, `minifyModules = false` for `minify-imports-and-exports`;
- `minifyExports = true`, `minifyModules = true` for `minify-imports-and-exports-and-modules`.

For the export-minifying pass, the strategy is:

1. collect eligible import base names;
2. collect export names;
3. generate short names with Binaryen's name generator;
4. rewrite import base names;
5. rewrite export names;
6. update module maps;
7. emit JSON mapping output describing old import/export names and new names.

The earlier first-pass dossier said this family delegates map construction to `WasmBinaryBuilder::getSymbolMap(...)`. The 2026-04-25 source-correction recheck superseded that claim for Binaryen `version_129`: the reviewed owner file uses `Names::MinifiedNameGenerator` directly.

The 2026-04-26 correction further supersedes the claim that plain `minify-imports` is separate/non-mutating/function-only. It is the narrow no-export/no-module mode of this same shared owner.

## Import-base rule differs by sibling

For `minify-imports-and-exports`, import-base minification follows the same plain-mode gate as `minify-imports`: imports are eligible when their module string is `env` or begins with `wasi_`.

For `minify-imports-and-exports-and-modules`, Binaryen minifies import bases regardless of original module and then rewrites import module names to one short singleton module.

That makes the `-and-modules` sibling more than a small extra rename. It can change custom-module imports that the plain and export-only modes leave untouched.

## Export-name rewriting

The `minifyExports` flag adds export-name rewriting. Export target indices and external kinds remain stable; only the public export string changes.

This is ABI-visible. A host that looks up `"main"` or `"very_long_export_name"` must be updated to use the new name or the generated map.

## JSON output

The shared owner prints JSON-shaped output with both import and export maps when exports are enabled. Conceptually:

```json
{
  "imports": {
    "a": ["env", "old_import"]
  },
  "exports": {
    "b": "old_export"
  }
}
```

The example is not a byte-for-byte oracle. Preserve Binaryen's exact ordering, escaping, and generated-name sequence when testing parity.

## What stays stable

The mutating pass family should preserve:

- function bodies and expressions;
- type, function, table, memory, global, tag, element, data, and code section structure;
- export target indices;
- import external kinds and their types;
- internal function names and locals, except for unrelated printer/name-section effects outside this pass's contract.

A host-visible string changes, but the module still imports and exports the same kinds of things.

## Pipeline role

This is a size and packaging pass. It is useful when a producer controls the host glue or when external symbol names are intentionally unstable. It is unsafe as a transparent optimizer for modules whose imports or exports are part of a stable public ABI.

Unlike [`strip-target-features`](../strip-target-features/index.md), this pass mutates in-memory module declarations rather than only toggling output metadata. Unlike [`duplicate-import-elimination`](../duplicate-import-elimination/index.md), it does not merge or remove imports.

## Main caveat

The official test surface reviewed for this run directly proves the `-and-modules` sibling. Plain `minify-imports` and `minify-imports-and-exports` remain source-confirmed through constructor flags, `pass.cpp` registration, and shared implementation. A future implementation signoff should add direct local oracle tests for all three public names.
