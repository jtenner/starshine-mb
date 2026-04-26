---
kind: concept
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-minify-imports-and-exports-port-readiness-primary-sources.md
  - ../../../raw/research/0403-2026-04-26-minify-imports-and-exports-port-readiness.md
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/binary/decode.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../minify-imports/index.md
  - ../duplicate-import-elimination/index.md
---

# Starshine port readiness and validation for `minify-imports-and-exports`

## Current answer

Starshine is **not ready to claim implementation** for `minify-imports-and-exports` today.
The pass family is still upstream-only and unknown to the local pass registry. This page records the safe future implementation order so readers can connect the transformed module shapes, Binaryen strategy, and exact Starshine landing zones without rereading the full dossier.

## Why a future port is module-scoped

Binaryen rewrites declaration strings:

- import base names;
- export names;
- import module names only for the `minify-imports-and-exports-and-modules` sibling.

Starshine stores those strings in module sections, not HOT regions:

- `src/lib/types.mbt:218` - `Import(Name, Name, ExternType)` stores `(module, base, type)`.
- `src/lib/types.mbt:227` - `Export(Name, ExternIdx)` stores `(name, target)`.
- `src/lib/types.mbt:350-424` - `Module` owns `import_sec` and `export_sec`.
- `src/lib/types.mbt:8380-8392` - constructors rebuild import and export records.
- `src/binary/decode.mbt:1899-1906` and `src/binary/decode.mbt:2109-2112` - binary import-section decoding.
- `src/binary/encode.mbt:1151-1165` and `src/binary/encode.mbt:1351-1361` - binary import/export-section encoding.
- `src/wast/lower_to_lib.mbt:2924-3004` and `src/wast/lower_to_lib.mbt:3316` - WAT import/export lowering.

No HOT-only peephole can be correct because function bodies are not where the ABI-facing names live.

## Registry-honesty first slice

Before mutating names, choose and test the registry story:

1. keep all three public spellings unknown, or
2. add boundary-only spellings that reject active execution with a clear message, or
3. add active module passes.

The current code says option 1:

- `src/passes/optimize.mbt` has no active, boundary-only, or removed entry for `minify-imports`, `minify-imports-and-exports`, or `minify-imports-and-exports-and-modules`.
- `src/passes/pass_manager.mbt` has no dispatcher arm for the family.
- explicit requests therefore fail before any module rewrite.

A port should add tests for all three spellings before adding transformation code so docs and CLI behavior cannot drift.

## First safe mutating slice

Implement only `minify-imports-and-exports` first, with a deliberately narrow fixture set:

```wat
(module
  (import "env" "long_callback" (func $callback))
  (func $local)
  (export "long_callback_export" (func $callback))
  (export "long_local_export" (func $local)))
```

Expected shape after a Binaryen-compatible local rewrite:

```wat
(module
  (import "env" "a" (func $callback))
  (func $local)
  (export "b" (func $callback))
  (export "c" (func $local)))
```

Teaching caveats:

- `a`, `b`, and `c` are illustrative. The implementation must compare against Binaryen for the exact generated-name sequence.
- The export targets must still point at the same entities.
- Function bodies, type declarations, and internal indices should not be rewritten.
- The map output must match Binaryen's current JSON row shape, not an ad-hoc map format.

## Follow-up slices

After the first slice is green, expand in this order:

1. **All external kinds** - add table, memory, global, and tag imports/exports while preserving `ExternType` and `ExternIdx` values.
2. **Collision and used-name avoidance** - test already-short names, repeated old names in different modules, and names that collide with generated candidates.
3. **Map output** - match current Binaryen row arrays:
   - imports as `[oldModule, oldBase, newBase]` rows;
   - exports as `[oldExport, newExport]` rows.
4. **`-and-modules` sibling** - rewrite import module names separately and prove custom-module imports become eligible only in this sibling.
5. **`minify-imports` sibling** - keep this separate from the export pass and prove the `env` / `wasi_` gate plus no-export behavior.
6. **Roundtrip and ABI docs** - binary encode/decode, WAT roundtrip, and an explicit warning that host-facing names intentionally change.

## Binaryen oracle commands

When a local implementation exists, compare against Binaryen in three lanes:

- `wasm-opt --minify-imports-and-exports -S` for export-name and import-base mutation without module-name mutation;
- `wasm-opt --minify-imports-and-exports-and-modules -S` for singleton module-name mutation;
- `wasm-opt --minify-imports -S` plus captured map output for the narrower sibling.

Normalize only non-semantic text-format noise. Do not normalize away import/export strings, because those are the entire pass output.

## Non-goals and blockers

- Do not add this to `optimize` or `shrink` presets silently. It changes public ABI names.
- Do not share implementation with [`duplicate-import-elimination`](../duplicate-import-elimination/index.md); duplicate import elimination changes the import graph, while this pass changes strings.
- Do not claim parity until `Names::MinifiedNameGenerator` behavior and used-name avoidance match the chosen Binaryen revision.
- Do not collapse `minify-imports`, `minify-imports-and-exports`, and `minify-imports-and-exports-and-modules` into one local flag; Binaryen exposes three public contracts.
