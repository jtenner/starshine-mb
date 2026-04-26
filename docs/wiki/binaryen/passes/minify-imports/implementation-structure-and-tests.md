---
kind: concept
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-minify-imports-current-main-source-correction.md
  - ../../../raw/research/0387-2026-04-26-minify-imports-source-correction.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./env-wasi-json-map-and-module-merge.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
---

# Implementation structure and tests for `minify-imports`

## Upstream owner files

### `src/passes/MinifyImportsAndExports.cpp`

This is the implementation owner for all three public minification names:

- `minify-imports`;
- `minify-imports-and-exports`;
- `minify-imports-and-exports-and-modules`.

The source-corrected plain-pass contract lives here, not in a separate `MinifyImports.cpp` file.

For `minify-imports`, the owner is responsible for:

- scanning module imports;
- selecting imports whose module string is `env` or starts with `wasi_`;
- generating short base names;
- mutating import base names;
- updating module maps after declaration-string rewrites;
- emitting JSON mapping output.

For the siblings, the same owner additionally handles export-name rewrites and, in `-and-modules` mode, import module-name merging.

### `src/passes/pass.cpp`

This file owns the public registry entries and help text for the three names. It is the quickest source-level way to confirm that plain `minify-imports` is not an alias for the export-minifying pass, but is still part of the same implementation family.

### `src/passes/passes.h`

This file exposes separate factories for the three public pass names. The factories route into the same owner with different flags.

### `src/support/name.h`

`Names::MinifiedNameGenerator` provides generated short names. Future parity tests should source-read this helper in the target Binaryen revision rather than hard-coding illustrative `a`, `b`, `c` examples.

## Upstream test surface

The reviewed official `version_129` pass tests include a dedicated fixture for `minify-imports-and-exports-and-modules`, not a dedicated plain-`minify-imports` fixture.

That proof split matters:

- source proves the plain pass's `env` / `wasi_` import-base mutation;
- sibling tests prove the broader import/export/module declaration-shape family;
- they do not replace an oracle check for exact plain-mode JSON order and formatting.

Future Starshine work should add local plain-mode tests even if upstream still lacks a dedicated lit fixture.

## Suggested future Starshine test map

If Starshine implements `minify-imports`, add tests around these phases:

1. registry behavior for `minify-imports` is explicit;
2. `env` function import gets a shorter base name;
3. `env` memory/table/global/tag imports are treated as eligible when supported by fixtures;
4. `wasi_` module import gets a shorter base name;
5. custom `host` module import is unchanged in plain mode;
6. export-only fixture is unchanged in plain mode;
7. stdout JSON is captured independently from optimized wasm/WAT output;
8. import maps and binary roundtrip are consistent after mutation;
9. sibling tests prove export-name mutation and module-name merge separately.

## Nearby sibling tests to keep separate

Tests for [`minify-imports-and-exports`](../minify-imports-and-exports/index.md) should assert export-name mutation. Tests for `minify-imports-and-exports-and-modules` should assert all-module import-base eligibility plus singleton module-name rewrite.

Tests for plain `minify-imports` should not assert either behavior.

## Corrected stale references

The following older claims are superseded for Binaryen `version_129` and current `main`:

- separate `src/passes/MinifyImports.cpp` owner;
- `modifiesBinaryenIR() == false` for the plain pass;
- imported-function-only traversal;
- one `old:new` text line per imported function;
- no module mutation under plain `minify-imports`.

Preserve the older notes only as provenance for the import/export minification research thread.
