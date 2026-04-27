---
kind: concept
status: supported
last_reviewed: 2026-04-27
sources:
  - ../../../raw/binaryen/2026-04-27-minify-imports-port-readiness-primary-sources.md
  - ../../../raw/research/0424-2026-04-27-minify-imports-port-readiness.md
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
  - ./env-wasi-json-map-and-module-merge.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../minify-imports-and-exports/starshine-port-readiness-and-validation.md
  - ../duplicate-import-elimination/index.md
---

# Starshine port readiness and validation for `minify-imports`

## Current answer

Starshine is **not ready to claim implementation** for plain `minify-imports` today. The pass is still upstream-only and unknown to the local pass registry.

This page records the safe future implementation order for the corrected source-backed contract: Binaryen's plain pass rewrites qualifying import **base names** and emits a JSON map. It does not rewrite export names, does not merge import module names, and is not a non-mutating report.

## Why a future port is module-scoped

Binaryen changes import declarations. Starshine stores those names in module records, not in HOT regions:

- `src/lib/types.mbt:218` - `Import(Name, Name, ExternType)` stores `(module, base, type)`.
- `src/lib/types.mbt:430` - `ImportSec(Array[Import])` is the section the plain pass would rewrite.
- `src/binary/decode.mbt:1899-1906` - binary import decoding reads module name, base name, and external type.
- `src/binary/encode.mbt:1151-1165` - binary import encoding writes module name, base name, and external type.
- `src/wast/lower_to_lib.mbt:2924-3004` - WAT imports lower into local import records across function, table, memory, global, and tag forms.

No HOT-only pass can be faithful because the ABI-facing strings are not function-body instructions.

## Registry-honesty first slice

Before changing names, choose and test the registry behavior:

1. keep `minify-imports` unknown;
2. add a boundary-only registry entry that rejects active execution with a clear message; or
3. add an active module pass with a reporting channel for the JSON map.

The current code uses option 1:

- `src/passes/optimize.mbt:1-36` defines registry categories but has no minification entry.
- `src/passes/optimize.mbt:479-491` rejects absent names as `unknown pass flag ...` and boundary-only names with a different explicit message.
- `src/passes/pass_manager.mbt:8661-8685` has no module-dispatcher arm for import minification.

A future port should add regression tests for the chosen behavior before adding transformation code so CLI behavior and docs cannot drift apart.

## First safe mutating slice

Implement only the plain pass contract first:

```wat
(module
  (import "env" "very_long_callback" (func $callback))
  (import "wasi_snapshot_preview1" "very_long_fd_write" (func $fd_write))
  (import "host" "very_long_custom" (func $host))
  (func (export "very_long_export")
    (call $callback)))
```

Expected teaching shape after a Binaryen-compatible rewrite:

```wat
(module
  (import "env" "a" (func $callback))
  (import "wasi_snapshot_preview1" "b" (func $fd_write))
  (import "host" "very_long_custom" (func $host))
  (func (export "very_long_export")
    (call $callback)))
```

Caveats:

- `a` and `b` are illustrative. Compare against Binaryen for exact name generation and used-name avoidance.
- `host.very_long_custom` must stay unchanged in plain mode.
- `very_long_export` must stay unchanged in plain mode.
- Function bodies, index references, import kinds, and external types should not change.
- JSON map output is part of parity and should be captured separately from optimized wasm/WAT output.

## Follow-up slices

After the first slice is green, expand in this order:

1. **All import kinds** - prove eligible memory, table, global, and tag imports are renamed without changing their `ExternType` payloads.
2. **Collision and ordering cases** - test already-short names, repeated old base names in different modules, generated-name collisions, and deterministic import traversal.
3. **JSON map parity** - match Binaryen's row-array output for imports, including old module, old base, and new base values.
4. **Binary roundtrip** - decode, rewrite, encode, and decode again to prove `ImportSec` maps are rebuilt consistently.
5. **Sibling separation** - add explicit negatives showing export-name mutation belongs to [`minify-imports-and-exports`](../minify-imports-and-exports/index.md), and import module-name merging belongs to `minify-imports-and-exports-and-modules`.

## Binaryen oracle lanes

When a local implementation exists, compare against Binaryen in these lanes:

- `wasm-opt --minify-imports -S` on reduced fixtures with captured map output;
- the same fixture through `wasm-opt --minify-imports-and-exports -S` to prove the sibling adds export mutation;
- the same fixture through `wasm-opt --minify-imports-and-exports-and-modules -S` to prove custom-module imports become eligible only in the module-minifying sibling.

Normalize only non-semantic text-format noise. Do not normalize import/export/module strings, because those strings are the pass output.

## Non-goals and blockers

- Do not add this pass to `optimize` or `shrink` presets silently; it intentionally changes host-facing ABI names.
- Do not share behavior with [`duplicate-import-elimination`](../duplicate-import-elimination/index.md); that pass merges equivalent import declarations, while this pass renames import strings.
- Do not implement export-name mutation under the plain `minify-imports` name.
- Do not implement module-name merging under the plain `minify-imports` name.
- Do not claim parity until `Names::MinifiedNameGenerator` behavior and JSON formatting match the chosen Binaryen revision.
