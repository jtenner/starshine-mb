---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-minify-imports-family-source-correction.md
  - ../../../raw/research/0343-2026-04-25-minify-imports-source-correction.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
---

# Implementation structure and tests for `minify-imports`

## Upstream owner files

### `src/passes/MinifyImports.cpp`

This is the implementation owner for the public `minify-imports` pass.
It owns:

- the `MinifyImports` pass class;
- the non-mutating `modifiesBinaryenIR()` contract;
- imported-function traversal;
- short-name generation;
- stdout map emission.

Teaching contract: this file does not apply the names back to the module.

### `src/passes/pass.cpp`

This file owns the public registry entry and help text for `minify-imports`.
It is also the easiest source to compare the three public minification names:

- `minify-imports` emits import-name mappings;
- `minify-imports-and-exports` mutates import base names and export names;
- `minify-imports-and-exports-and-modules` mutates those names plus import module names.

### `src/passes/passes.h`

This file exposes `createMinifyImportsPass()` separately from `createMinifyImportsAndExportsPass(bool minifyModules)`.
The separate factory is the source-level reminder that `minify-imports` is not just the plain mode of the mutating pass family.

### `src/wasm/wasm-module-utils.h`

The pass uses `ModuleUtils::iterImportedFunctions(...)` for traversal.
That helper boundary is why the pass is documented as imported-function-only.

### `src/support/name.h`

`Names::MinifiedNameGenerator` provides generated short names.
Future parity tests should not hard-code a guessed alphabet without checking this helper in the targeted revision.

## Upstream test surface

This run found no dedicated official `test/passes/minify-imports.wast` / `.txt` pair in the reviewed `version_129` pass tests.
The source proof is still strong enough to document the pass, but the proof gap matters:

- no direct lit fixture was reviewed for stdout map order;
- no direct lit fixture was reviewed for duplicate imported-function base names;
- no direct lit fixture was reviewed for non-function import negatives.

The nearby `minify-imports-and-exports-and-modules` lit pair belongs to the mutating sibling, not to `minify-imports`.
Do not use that sibling test as proof that `minify-imports` mutates module declarations.

## Suggested future Starshine test map

If Starshine implements `minify-imports`, add local tests around these phases:

1. registry behavior for `minify-imports` is explicit;
2. imported-function fixture emits mapping lines;
3. module bytes or WAT are unchanged by the pass;
4. imported memory/table/global/tag fixture emits no mapping lines;
5. export-only fixture emits no mapping lines;
6. duplicate imported function names document Binaryen-compatible output behavior;
7. CLI test captures stdout and errors separately from normal optimized module output.

## Nearby sibling tests to keep separate

Tests for [`minify-imports-and-exports`](../minify-imports-and-exports/index.md) should assert mutated module declarations.
Tests for `minify-imports` should assert no mutation plus map output.
Combining those expectations under one pass name would hide the most important distinction in the source.
