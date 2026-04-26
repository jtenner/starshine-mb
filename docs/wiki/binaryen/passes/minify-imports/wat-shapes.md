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
  - ./implementation-structure-and-tests.md
  - ./starshine-strategy.md
  - ../minify-imports-and-exports/wat-shapes.md
---

# WAT shapes for `minify-imports`

## Shape 1: `env` function import is renamed

Input:

```wat
(module
  (import "env" "very_long_callback_name" (func $callback))
  (func (export "call_callback")
    (call $callback)))
```

After Binaryen `--minify-imports`, the import base name is shortened while the module string and function index relationship remain stable:

```wat
(module
  (import "env" "a" (func $callback))
  (func (export "call_callback")
    (call $callback)))
```

`"a"` is illustrative. Binaryen's name generator owns the real sequence.

The pass also emits a JSON mapping conceptually recording `env`, the old base name, and the new base name.

## Shape 2: `wasi_` import is renamed

Input:

```wat
(module
  (import "wasi_snapshot_preview1" "very_long_fd_write" (func $fd_write)))
```

Plain `minify-imports` may shorten `very_long_fd_write` because the module begins with `wasi_`.

## Shape 3: custom-module import is a plain-mode negative

Input:

```wat
(module
  (import "host" "very_long_callback_name" (func $callback)))
```

Plain `minify-imports` should leave this declaration unchanged. The custom module does not pass the `env` / `wasi_` gate.

The `minify-imports-and-exports-and-modules` sibling has different behavior and may rewrite this family after it opts into module-name minification.

## Shape 4: non-function imports are in scope when eligible

Input:

```wat
(module
  (import "env" "long_memory" (memory 1))
  (import "env" "long_table" (table 1 funcref))
  (import "env" "long_global" (global i32)))
```

The corrected source-backed rule is that these are eligible import-base names. Do not preserve the stale function-only teaching from the older 2026-04-25 dossier.

Conceptual output:

```wat
(module
  (import "env" "a" (memory 1))
  (import "env" "b" (table 1 funcref))
  (import "env" "c" (global i32)))
```

The exact generated names and order must come from Binaryen.

## Shape 5: exports are untouched by the plain pass

Input:

```wat
(module
  (func $f)
  (export "very_long_export_name" (func $f)))
```

Plain `minify-imports` does not rename exports. Export-name mutation belongs to `minify-imports-and-exports` and `minify-imports-and-exports-and-modules`.

## Shape 6: module-name merge belongs to the sibling

Input:

```wat
(module
  (import "env" "long_func" (func $f))
  (import "host" "long_table" (table 1 funcref)))
```

Plain `minify-imports` can rename only the `env` import base. It must not rewrite both modules to a shared short module.

The `-and-modules` sibling can conceptually produce:

```wat
(module
  (import "a" "b" (func $f))
  (import "a" "c" (table 1 funcref)))
```

Keep that shape out of plain-pass tests.

## Validation checklist

For every positive shape, verify:

- the module validates before and after;
- qualifying import base names changed;
- import kinds and indices did not change;
- plain mode keeps non-`env` / non-`wasi_` custom modules unchanged;
- exports do not change under plain mode;
- stdout JSON matches the targeted Binaryen revision;
- binary roundtrip rebuilds import maps consistently.
