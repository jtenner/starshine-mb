---
kind: research
status: supported
last_reviewed: 2026-04-26
sources:
  - ../binaryen/2026-04-26-minify-imports-and-exports-port-readiness-primary-sources.md
  - ../../binaryen/passes/minify-imports-and-exports/index.md
  - ../../binaryen/passes/minify-imports-and-exports/binaryen-strategy.md
  - ../../binaryen/passes/minify-imports-and-exports/starshine-strategy.md
  - ../../../../src/lib/types.mbt
  - ../../../../src/binary/decode.mbt
  - ../../../../src/binary/encode.mbt
  - ../../../../src/wast/lower_to_lib.mbt
---

# `minify-imports-and-exports` port readiness

## Question

The existing `minify-imports-and-exports` dossier explained Binaryen's shared minification family and Starshine's current unknown-pass status, but future implementers still had to infer a safe local first slice, exact validation ladder, and JSON-map caveat from scattered pages. This note records the 2026-04-26 bridge work.

## Findings

- Binaryen current `main` still matches the `version_129` family contract: one owner file, three constructor modes, and one `pass.cpp` registration point for each public spelling.
- The pass is ABI-visible module metadata work, not HOT IR work. Starshine's relevant local storage is `Import(Name, Name, ExternType)`, `Export(Name, ExternIdx)`, `Module.import_sec`, and `Module.export_sec`.
- The safest future Starshine slice is registry honesty plus an explicit no-rewrite analyzer before any name mutation. That slice can prove no code-body rewrite is needed and can pin the unknown-vs-boundary-vs-active decision.
- The first mutating slice should implement `minify-imports-and-exports` only for function imports/exports with no module renaming and with Binaryen-oracle checks around generated names and JSON map rows.
- The sibling `minify-imports-and-exports-and-modules` should be a separate slice because it changes import module strings and broadens import-base eligibility.
- The separate `minify-imports` sibling should not be treated as a trivial alias. It has the same owner file but a different public contract: no export map, no module rename, and an `env` / `wasi_` eligibility gate.
- The living wiki's conceptual JSON example was stale enough to be misleading: current Binaryen emits arrays of row tuples, not nested objects. The example was corrected as a health fix.

## Updated durable pages

- Added `docs/wiki/binaryen/passes/minify-imports-and-exports/starshine-port-readiness-and-validation.md`.
- Refreshed the overview page to link the new bridge and remove duplicate Binaryen owner-file source links.
- Refreshed the Binaryen strategy JSON-output section to match the current source shape.
- Refreshed the Starshine strategy page to point implementers at the bridge instead of leaving the local implementation order implicit.

## Validation recommendation

A future port should validate in this order:

1. registry behavior tests for all three public spellings;
2. function import/export rename oracle against Binaryen `--minify-imports-and-exports`;
3. table, memory, global, and tag import/export rename coverage;
4. map-output shape tests for import and export rows;
5. `-and-modules` sibling tests for singleton import module rewrite;
6. separate `minify-imports` tests for the `env` / `wasi_` gate and no-export behavior;
7. binary roundtrip plus host-ABI documentation.

## Caveats

- This was a source-reading check, not an execution signoff.
- Current official lit coverage is not organized around pass-named `minify-imports*` fixtures, so future Starshine tests should be especially explicit about every public spelling.
- Generated names in examples are teaching aids, not stable byte-for-byte oracle values.
