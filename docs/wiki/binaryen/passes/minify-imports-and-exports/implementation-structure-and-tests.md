---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-minify-imports-and-exports-primary-sources.md
  - ../../../raw/research/0342-2026-04-25-minify-imports-and-exports-source-dossier.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
---

# Implementation structure and tests for `minify-imports-and-exports`

## Upstream owner files

### `src/passes/MinifyImportsAndExports.cpp`

This is the implementation owner for both public names:

- `minify-imports-and-exports`;
- `minify-imports-and-exports-and-modules`.

It owns the pass class, the `minifyModules` flag, the import/export map application helpers, and the call to `WasmBinaryBuilder::getSymbolMap(...)`.

Teaching contract:

- the pass is module-wide;
- it rewrites declaration strings, not instruction bodies;
- the sibling is not a separate algorithm;
- generated-name choice lives below the pass in Binaryen's symbol-map machinery.

### `src/passes/pass.cpp`

This file owns the public registration and help text.
It is the source that proves the naming split:

- `minify-imports-and-exports` minifies import and export names, not module names;
- `minify-imports-and-exports-and-modules` also minifies module names.

### `src/passes/passes.h`

This file exposes the factory declaration `createMinifyImportsAndExportsPass(bool minifyModules)`.
The boolean argument is part of the public implementation shape: one factory, two registrations.

### `src/wasm/wasm-binary.h`

The relevant helper is `WasmBinaryBuilder::getSymbolMap(...)`.
It computes the name maps that the pass applies.
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

- The reviewed lit pair is sibling-focused. The plain pass is source-confirmed by the `minifyModules = false` registration, but this run did not find a separate dedicated plain-pass WAT pair.
- The exact generated short-name sequence is delegated to `WasmBinaryBuilder::getSymbolMap(...)`. Do not infer a full naming algorithm from the small pass owner file alone.
- This pass changes external names. A validation-only test is not enough; future local tests need before/after name assertions.

## Suggested future Starshine test map

If Starshine implements this pass family, add local tests around these phases:

1. registry tests for both pass names;
2. plain-pass function import/export rename with module string unchanged;
3. sibling import module-name rename;
4. non-function import/export cases: table, memory, global, and tag;
5. collision cases where an already-short export exists;
6. roundtrip binary encode/decode proving the rewritten names persist;
7. negative or documentation tests explaining host ABI instability.
