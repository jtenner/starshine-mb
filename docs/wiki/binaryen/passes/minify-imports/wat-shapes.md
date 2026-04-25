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
  - ./implementation-structure-and-tests.md
  - ./starshine-strategy.md
  - ../minify-imports-and-exports/wat-shapes.md
---

# WAT shapes for `minify-imports`

## Shape 1: imported function mapping

Input module:

```wat
(module
  (import "env" "very_long_callback_name" (func $callback))
  (func (export "call_callback")
    (call $callback)))
```

After Binaryen `--minify-imports`, the module should remain structurally the same.
The visible effect is map output, conceptually:

```text
very_long_callback_name:a
```

The exact short name is illustrative.
Binaryen's `Names::MinifiedNameGenerator` owns the real sequence.

## Shape 2: multiple imported functions

Input module:

```wat
(module
  (import "env" "long_first_callback" (func $first))
  (import "env" "long_second_callback" (func $second))
  (func (export "run")
    (call $first)
    (call $second)))
```

Expected effect:

- one mapping entry per imported function base name;
- no function-body rewrite;
- no export-name rewrite.

Conceptual output:

```text
long_first_callback:a
long_second_callback:b
```

Future parity tests should confirm Binaryen's actual order for the targeted revision.

## Shape 3: imported module names are not mapped

Input module:

```wat
(module
  (import "very_long_module_name" "very_long_function_name" (func $f)))
```

`minify-imports` maps only the imported function base name:

```text
very_long_function_name:a
```

It does not emit a separate mapping for `very_long_module_name`.
Import module-name mutation belongs to `minify-imports-and-exports-and-modules`.

## Shape 4: non-function imports are negative controls

Input module:

```wat
(module
  (import "env" "long_memory" (memory 1))
  (import "env" "long_table" (table 1 funcref))
  (import "env" "long_global" (global i32)))
```

`minify-imports` should emit no mapping for these declarations because the owner walks imported functions.

The mutating [`minify-imports-and-exports`](../minify-imports-and-exports/index.md) family has a broader import-declaration surface; do not import that behavior back into `minify-imports`.

## Shape 5: exports are negative controls

Input module:

```wat
(module
  (func $f)
  (export "very_long_export_name" (func $f)))
```

`minify-imports` should not emit an export-name mapping and should not rename the export.

Export-name mutation belongs to `minify-imports-and-exports`.

## Shape 6: not duplicate import elimination

Input module:

```wat
(module
  (import "env" "same_name" (func $a))
  (import "env" "same_name" (func $b)))
```

The important teaching rule is that `minify-imports` does not merge declarations and does not rewrite call targets.
If duplicate names matter, the future parity test should compare Binaryen's emitted mapping behavior exactly instead of guessing a deduplication rule from the pass name.

## Validation checklist

For every positive shape, verify:

- the module validates before and after;
- the in-memory module or emitted WAT is unchanged by `minify-imports`;
- stdout contains only imported-function base-name mappings;
- non-function imports and exports do not appear in the mapping;
- the generated names and output order match the target Binaryen revision.
