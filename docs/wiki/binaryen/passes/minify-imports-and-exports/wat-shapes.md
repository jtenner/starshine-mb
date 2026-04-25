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
  - ./implementation-structure-and-tests.md
  - ./starshine-strategy.md
  - ../duplicate-import-elimination/index.md
---

# WAT shapes for `minify-imports-and-exports`

## Shape 1: function import base name

Before:

```wat
(module
  (import "env" "very_long_callback_name" (func $callback))
  (func (export "call_callback")
    (call $callback)))
```

After the plain pass, the import base name may be shortened while the module name stays stable:

```wat
(module
  (import "env" "a" (func $callback))
  (func (export "b")
    (call $callback)))
```

Caveat: the exact short names are illustrative.
Binaryen's symbol-map builder owns the real names.

## Shape 2: export name

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

The export target is still `$f`.
Only the host lookup string changes.

## Shape 3: sibling module-name minification

Before:

```wat
(module
  (import "very_long_module_name" "very_long_import_name" (func $f)))
```

After `minify-imports-and-exports-and-modules`, both strings may change:

```wat
(module
  (import "a" "b" (func $f)))
```

After the plain pass, only the second string should change:

```wat
(module
  (import "very_long_module_name" "a" (func $f)))
```

This is the most important sibling distinction.

## Shape 4: non-function import kinds

The pass is not function-only.
It applies to import declarations regardless of external kind.

Before:

```wat
(module
  (import "env" "long_memory" (memory 1))
  (import "env" "long_table" (table 1 funcref))
  (import "env" "long_global" (global i32)))
```

After the plain pass:

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

The target objects do not move.
The host-facing names change.

## Shape 6: what the pass does not do

This pass is not [`duplicate-import-elimination`](../duplicate-import-elimination/index.md):

```wat
(import "env" "same" (func $a))
(import "env" "same" (func $b))
```

A minifier is not responsible for proving `$a` and `$b` are duplicates or deleting one of them.
It only renames strings according to the map Binaryen computes.

This pass is also not [`reorder-functions`](../reorder-functions/index.md):

```wat
(func $cold)
(func $hot)
(export "hot" (func $hot))
```

Minifying the export string does not reorder the function declarations.

## Validation checklist

For every positive shape, verify:

- the module validates;
- import and export counts are unchanged;
- import/export external kinds are unchanged;
- export target indices are unchanged;
- body instructions are unchanged except for text-printer cosmetic renaming;
- the plain pass preserves import module strings;
- the sibling rewrites import module strings.
