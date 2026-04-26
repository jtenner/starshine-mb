---
kind: source-digest
status: supported
last_reviewed: 2026-04-26
sources:
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/MinifyImportsAndExports.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/tree/main/test/lit/passes
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MinifyImportsAndExports.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
related:
  - ../../binaryen/passes/minify-imports-and-exports/index.md
  - ../../binaryen/passes/minify-imports-and-exports/starshine-port-readiness-and-validation.md
  - ../research/0403-2026-04-26-minify-imports-and-exports-port-readiness.md
---

# Binaryen `minify-imports-and-exports` port-readiness primary-source check

This digest captures the 2026-04-26 primary-source recheck used to add the Starshine port-readiness bridge for `minify-imports-and-exports`.

## Checked sources

- Official Binaryen current `main` `src/passes/MinifyImportsAndExports.cpp`.
- Official Binaryen current `main` `src/passes/pass.cpp`.
- Official Binaryen current `main` `test/lit/passes/` directory listing.
- Tagged `version_129` copies of `MinifyImportsAndExports.cpp` and `pass.cpp`, used as the stable baseline from earlier dossier work.

## Source-backed findings

- Current `main` still implements the whole public minification family in `MinifyImportsAndExports.cpp`.
- The public pass split remains constructor-flag based:
  - `createMinifyImportsPass()` uses `(false, false)`;
  - `createMinifyImportsAndExportsPass()` uses `(true, false)`;
  - `createMinifyImportsAndExportsAndModulesPass()` uses `(true, true)`.
- `pass.cpp` still registers all three public spellings: `minify-imports`, `minify-imports-and-exports`, and `minify-imports-and-exports-and-modules`.
- The import-base eligibility split remains source-backed:
  - without module minification, only `env` and `wasi_` imports are treated as ordinary minifiable imports;
  - with module minification, all import base names are minified and then import modules are merged to singleton module name `"a"`.
- Export-name rewriting is guarded by `minifyExports` and rewrites only export names, not export target indices or entity kinds.
- The emitted map is JSON-shaped arrays, not the object-of-objects sketch that an older living page used as conceptual shorthand. Current `main` emits an `imports` array of `[module, oldBase, newBase]` rows and an `exports` array of `[oldExport, newExport]` rows.
- Current `main` directory listing for `test/lit/passes/` still shows no pass-named `minify-imports*.wast` lit fixture. Existing coverage remains source-confirmed rather than pass-name-fixture-confirmed.

## No teaching-relevant drift found

No teaching-relevant source drift was found between the previous `version_129` contract and the current-main recheck. The durable update is not a strategy correction; it is a port-readiness bridge plus a small hygiene correction for the documented JSON map shape.

## Uncertainties and caveats

- This check did not execute Binaryen. It is a source-reading and official-directory-listing check.
- A future Starshine implementation should still build local oracle fixtures for all three public spellings because current official lit coverage is not organized around pass-named `minify-imports*` files.
- Binaryen's exact generated-name sequence is owned by `Names::MinifiedNameGenerator`; the wiki should not freeze sample names as an oracle beyond simple one-name examples.
