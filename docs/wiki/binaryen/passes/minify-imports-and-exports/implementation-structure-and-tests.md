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
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../minify-imports/implementation-structure-and-tests.md
---

# Implementation structure and tests for `minify-imports-and-exports`

## Upstream owner files

### `src/passes/MinifyImportsAndExports.cpp`

This is the implementation owner for both mutating public names:

- `minify-imports-and-exports`;
- `minify-imports-and-exports-and-modules`.

It owns the pass class, the `minifyModules` flag, import/export collection, used-name collection from name-section surfaces, `Names::MinifiedNameGenerator`-based `mapNames(...)`, and the helpers that apply maps to imports and exports.

Teaching contract:

- the pass is module-wide;
- it rewrites declaration strings, not instruction bodies;
- the sibling is not a separate algorithm;
- generated-name choice is in the pass owner file and `Names::MinifiedNameGenerator`, not `WasmBinaryBuilder::getSymbolMap(...)` in Binaryen `version_129`.

### `src/passes/MinifyImports.cpp`

This neighboring owner file belongs to the separate [`minify-imports`](../minify-imports/index.md) pass.
It emits an imported-function map and does not mutate IR.
Keep it separate when reading source or writing tests.

### `src/passes/pass.cpp`

This file owns the public registration and help text.
It is the source that proves the naming split:

- `minify-imports` emits import-name mappings only;
- `minify-imports-and-exports` minifies import and export names, not module names;
- `minify-imports-and-exports-and-modules` also minifies module names.

### `src/passes/passes.h`

This file exposes two separate factory shapes:

- `createMinifyImportsPass()`;
- `createMinifyImportsAndExportsPass(bool minifyModules)`.

The boolean argument is part of the mutating family shape: one factory, two registrations.

### `src/support/name.h`

`Names::MinifiedNameGenerator` is the short-name generator used by both minify owner files.
Future Starshine parity work should source-read this helper in the target upstream revision before implementing short-name ordering locally.

## Upstream test surface

### `test/passes/minify-imports-and-exports-and-modules.wast`

This WAT fixture includes imports of several external kinds plus exports with long names.
It is strongest evidence for the sibling that minifies module names as well as import/export names.

### `test/passes/minify-imports-and-exports-and-modules.txt`

This expected-output file shows the core visible behavior:

- long import module strings are shortened in the sibling mode;
- long import base names are shortened;
- long export names are shortened;
- the imported and exported entity shapes remain recognizable.

## Proof gaps to keep explicit

- The reviewed lit pair is sibling-focused. The plain mutating pass is source-confirmed by the `minifyModules = false` registration, but this run did not find a separate dedicated plain-pass WAT pair.
- The separate `minify-imports` pass also lacks a reviewed dedicated lit pair and should not be inferred from the mutating sibling output.
- The exact generated short-name sequence is controlled by `Names::MinifiedNameGenerator` plus used-name avoidance. Do not infer a full naming algorithm from illustrative WAT snippets.
- This mutating pass changes external names. A validation-only test is not enough; future local tests need before/after name assertions and host-ABI documentation.

## Suggested future Starshine test map

If Starshine implements this pass family, add local tests around these phases:

1. registry tests for all three minify pass names;
2. plain mutating function import/export rename with module string unchanged;
3. sibling import module-name rename;
4. non-function import/export cases: table, memory, global, and tag;
5. collision cases where an already-short export or name-section name exists;
6. roundtrip binary encode/decode proving the rewritten names persist;
7. separate `minify-imports` stdout/no-mutation tests;
8. negative or documentation tests explaining host ABI instability.
