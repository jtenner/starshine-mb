---
kind: entity
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-minify-imports-and-exports-primary-sources.md
  - ../../../raw/research/0342-2026-04-25-minify-imports-and-exports-source-dossier.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/binary/decode.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../duplicate-import-elimination/index.md
  - ../reorder-functions/index.md
  - ../strip-target-features/index.md
---

# `minify-imports-and-exports`

## Role

`minify-imports-and-exports` is a public Binaryen module pass that shortens externally visible import base names and export names.
Binaryen also exposes the sibling `minify-imports-and-exports-and-modules`, which uses the same implementation but additionally shortens import module names.

Starshine currently treats both names as **upstream-only unknown pass names**:

- neither pass is active, boundary-only, or removed in `src/passes/optimize.mbt`;
- neither pass appears in `src/passes/pass_manager.mbt`;
- explicit local requests fail as `unknown pass flag ...` before dispatch;
- no owner file or active backlog slice exists today.

This folder exists because the pass is easy to underestimate.
It does not rewrite instructions, but it changes the ABI-facing strings a host uses to link imports and discover exports.

## Beginner summary

A useful beginner mental model is:

- wasm imports are addressed by a pair of strings: `(module, name)`;
- wasm exports are addressed by a string: `name`;
- Binaryen can rename those strings to shorter generated names;
- the plain pass leaves import module names alone;
- the `-and-modules` sibling also shortens import module names;
- the imported/exported entity kinds and internal indices stay the same.

Example shape:

```wat
(import "env" "very_long_callback_name" (func $callback))
(export "very_long_export_name" (func $callback))
```

After the plain pass, the host-facing names may become short generated names for the import base and export while the module string remains `"env"`:

```wat
(import "env" "a" (func $callback))
(export "b" (func $callback))
```

After the sibling, the module string may also be shortened:

```wat
(import "a" "b" (func $callback))
(export "c" (func $callback))
```

The exact generated names are owned by Binaryen's symbol-map builder and must be rechecked before implementation signoff.

## Inputs and outputs

### Input

The input is a module with import and/or export declarations.
The pass is meaningful for any external kind: functions, tables, memories, globals, and tags can all have imports or exports.

### Output

The output is the same module structure with shorter external names:

- import base names may change;
- export names may change;
- import module names change only in `minify-imports-and-exports-and-modules`;
- import/export kinds and target indices should remain the same;
- code bodies and internal references should remain unchanged.

## Correctness constraints

- **External ABI breakage is real:** hosts and downstream tools must use the renamed strings after the pass.
- **Do not retarget entities:** changing an export name must not change which function/table/memory/global/tag it exports.
- **Do not rewrite bodies:** this pass is declaration-string minification, not call rewriting, import deduplication, inlining, or section reordering.
- **Keep the sibling split explicit:** the plain pass does not minify import module names; the `-and-modules` sibling does.
- **Avoid name collisions:** generated names must remain unique enough for imports/exports to remain valid and unambiguous.
- **Use valid wasm names:** a future port must preserve Binaryen-compatible name generation rather than inventing names that fail text/binary roundtrips.

## Notable edge cases

- If a host expects `env.log`, renaming the import to `env.a` breaks linking unless the host is updated too.
- If a host finds an export named `main`, minifying it changes the host lookup contract.
- The official lit file reviewed for this dossier directly exercises the sibling that also minifies module names; the plain pass is source-confirmed through the `minifyModules = false` path.
- Minification can make binary output smaller while making stack traces, host glue, or debugging less readable.
- This pass is different from [`duplicate-import-elimination`](../duplicate-import-elimination/index.md): duplicate import elimination merges equivalent imported functions, while minification only changes external strings.

## Validation strategy

For Binaryen parity research:

1. build a module with long imported function/global/memory/table names and long export names;
2. run Binaryen `--minify-imports-and-exports`;
3. confirm import base names and export names are shortened while module names remain stable;
4. run Binaryen `--minify-imports-and-exports-and-modules`;
5. confirm import module names are shortened too;
6. confirm all import/export target kinds and indices remain unchanged;
7. confirm the module still validates and round-trips.

For a future Starshine port, add tests in this order:

1. explicit registry status for both pass names is chosen deliberately;
2. a function-import plus function-export fixture proves the core rename surface;
3. table, memory, global, and tag import/export fixtures prove the non-function surface;
4. the sibling proves module-name renaming separately;
5. duplicate or already-short names prove collision handling;
6. a host-ABI note or option warning documents that external names are intentionally unstable after the pass.

## Page map

- [`binaryen-strategy.md`](binaryen-strategy.md) - Binaryen's map-building and application strategy.
- [`implementation-structure-and-tests.md`](implementation-structure-and-tests.md) - owner files and proof surface.
- [`wat-shapes.md`](wat-shapes.md) - concrete before/after module shapes.
- [`starshine-strategy.md`](starshine-strategy.md) - current Starshine status and future landing zones.

## Sources

- [`../../../raw/binaryen/2026-04-25-minify-imports-and-exports-primary-sources.md`](../../../raw/binaryen/2026-04-25-minify-imports-and-exports-primary-sources.md)
- [`../../../raw/research/0342-2026-04-25-minify-imports-and-exports-source-dossier.md`](../../../raw/research/0342-2026-04-25-minify-imports-and-exports-source-dossier.md)
- Binaryen `MinifyImportsAndExports.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MinifyImportsAndExports.cpp>
- Binaryen pass registry: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
