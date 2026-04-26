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
  - ./implementation-structure-and-tests.md
  - ./starshine-strategy.md
  - ../minify-imports/index.md
  - ../duplicate-import-elimination/index.md
---

# WAT shapes for `minify-imports-and-exports`

## Shape 1: `env` import base plus export name

Before:

```wat
(module
  (import "env" "very_long_callback_name" (func $callback))
  (func (export "call_callback")
    (call $callback)))
```

After `minify-imports-and-exports`, the import base and export name may be shortened while the import module name stays stable:

```wat
(module
  (import "env" "a" (func $callback))
  (func (export "b")
    (call $callback)))
```

Caveat: the exact short names are illustrative. Binaryen's name generator owns the real names and JSON output.

## Shape 2: export-only module

Before:

```wat
(module
  (func $f)
  (export "very_long_export_name" (func $f)))
```

After:

```wat
(module
  (func $f)
  (export "a" (func $f)))
```

The export target is still `$f`. Only the host lookup string changes.

## Shape 3: custom-module import is unchanged unless `-and-modules` is used

Before:

```wat
(module
  (import "very_long_module_name" "very_long_import_name" (func $f)))
```

After `minify-imports-and-exports`, the custom-module import is not an eligible import-base rewrite because the module is neither `env` nor `wasi_`:

```wat
(module
  (import "very_long_module_name" "very_long_import_name" (func $f)))
```

After `minify-imports-and-exports-and-modules`, both strings may change and all imports are placed under one short module:

```wat
(module
  (import "a" "b" (func $f)))
```

This is the most important sibling distinction.

## Shape 4: non-function import kinds from `env`

The pass is not function-only. Eligible import declarations can be renamed regardless of external kind.

Before:

```wat
(module
  (import "env" "long_memory" (memory 1))
  (import "env" "long_table" (table 1 funcref))
  (import "env" "long_global" (global i32)))
```

After `minify-imports-and-exports`:

```wat
(module
  (import "env" "a" (memory 1))
  (import "env" "b" (table 1 funcref))
  (import "env" "c" (global i32)))
```

The external kind and type stay the same.

## Shape 5: export target kinds

Before:

```wat
(module
  (memory $m 1)
  (global $g i32 (i32.const 0))
  (table $t 1 funcref)
  (export "long_memory_export" (memory $m))
  (export "long_global_export" (global $g))
  (export "long_table_export" (table $t)))
```

After:

```wat
(module
  (memory $m 1)
  (global $g i32 (i32.const 0))
  (table $t 1 funcref)
  (export "a" (memory $m))
  (export "b" (global $g))
  (export "c" (table $t)))
```

The target objects do not move. The host-facing names change.

## Shape 6: what the pass does not do

This pass is not [`duplicate-import-elimination`](../duplicate-import-elimination/index.md):

```wat
(import "env" "same" (func $a))
(import "env" "same" (func $b))
```

A minifier is not responsible for proving `$a` and `$b` are duplicates or deleting one of them. It only renames strings according to the map Binaryen computes.

This pass is also not [`reorder-functions`](../reorder-functions/index.md):

```wat
(func $cold)
(func $hot)
(export "hot" (func $hot))
```

Minifying the export string does not reorder the function declarations.

Finally, `minify-imports-and-exports` is broader than [`minify-imports`](../minify-imports/index.md) only on exports. Both share the same plain import-base gate; the `-and-modules` sibling is the one that broadens import-base eligibility and rewrites module strings.

## Validation checklist

For every positive shape, verify:

- the module validates;
- import and export counts are unchanged;
- import/export external kinds are unchanged;
- export target indices are unchanged;
- body instructions are unchanged except for text-printer cosmetic renaming;
- `minify-imports-and-exports` preserves import module strings;
- custom-module import bases stay unchanged unless using `-and-modules`;
- the sibling rewrites import module strings and emits the broader map.
