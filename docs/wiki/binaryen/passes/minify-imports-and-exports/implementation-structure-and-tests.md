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
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../minify-imports/implementation-structure-and-tests.md
---

# Implementation structure and tests for `minify-imports-and-exports`

## Upstream owner files

### `src/passes/MinifyImportsAndExports.cpp`

This is the implementation owner for all three public names:

- `minify-imports`;
- `minify-imports-and-exports`;
- `minify-imports-and-exports-and-modules`.

It owns the pass class, the `minifyExports` / `minifyModules` mode split, import/export collection, short-name generation, declaration-string rewrites, map updates, and JSON mapping output.

Teaching contract:

- the pass family is module-wide;
- it rewrites declaration strings, not instruction bodies;
- plain `minify-imports` is the narrow shared-owner mode, not a separate non-mutating owner;
- generated-name choice is in the pass owner file and `Names::MinifiedNameGenerator`, not `WasmBinaryBuilder::getSymbolMap(...)` in Binaryen `version_129`.

### `src/passes/pass.cpp`

This file owns the public registration and help text. It is the source that proves the naming split:

- `minify-imports` minifies eligible import names and emits a map;
- `minify-imports-and-exports` minifies eligible import names plus export names, not module names;
- `minify-imports-and-exports-and-modules` also minifies module names.

### `src/passes/passes.h`

This file exposes separate factories for the public names. The factory split is public API shape; the implementation still routes through the same owner with different flags.

### `src/support/name.h`

`Names::MinifiedNameGenerator` is the short-name generator used by the family. Future Starshine parity work should source-read this helper in the target upstream revision before implementing short-name ordering locally.

## Upstream test surface

### `test/passes/minify-imports-and-exports-and-modules.wast`

This WAT fixture includes imports of several external kinds plus exports with long names. It is strongest evidence for the sibling that minifies module names as well as import/export names.

### `test/passes/minify-imports-and-exports-and-modules.txt`

This expected-output file shows the core visible behavior:

- long import module strings are shortened in the sibling mode;
- long import base names are shortened;
- long export names are shortened;
- the imported and exported entity shapes remain recognizable.

## Proof gaps to keep explicit

- The reviewed lit pair is sibling-focused. Plain `minify-imports` and `minify-imports-and-exports` are source-confirmed by constructor flags and registry entries, but this run did not find separate dedicated WAT pairs for those modes.
- The exact generated short-name sequence is controlled by `Names::MinifiedNameGenerator`. Do not infer a full naming algorithm from illustrative WAT snippets.
- This family changes external names. A validation-only test is not enough; future local tests need before/after name assertions, JSON output assertions, and host-ABI documentation.

## Suggested future Starshine test map

If Starshine implements this pass family, add local tests around these phases:

1. registry tests for all three minify pass names;
2. plain `minify-imports` `env` / `wasi_` import-base rewrite;
3. `minify-imports-and-exports` export rename with module strings unchanged;
4. `minify-imports-and-exports-and-modules` all-import-base rewrite plus singleton module-name merge;
5. non-function import/export cases: table, memory, global, and tag;
6. collision cases where an already-short export or name-section name exists;
7. JSON output capture separate from optimized wasm/WAT output;
8. roundtrip binary encode/decode proving the rewritten names persist;
9. negative or documentation tests explaining host ABI instability.
