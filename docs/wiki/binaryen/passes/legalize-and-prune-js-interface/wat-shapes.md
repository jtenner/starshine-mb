---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-legalize-and-prune-js-interface-primary-sources.md
  - ../../../raw/research/0292-2026-04-24-legalize-and-prune-js-interface-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0224-2026-04-21-legalize-and-prune-js-interface-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/legalize-and-prune-js-interface.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LegalizeJSInterface.cpp
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./prune-boundary-matrix.md
  - ./starshine-strategy.md
  - ../legalize-js-interface/wat-shapes.md
---

# WAT shapes for `legalize-and-prune-js-interface`

Use this page with the 2026-04-24 raw primary-source capture in [`../../../raw/binaryen/2026-04-24-legalize-and-prune-js-interface-primary-sources.md`](../../../raw/binaryen/2026-04-24-legalize-and-prune-js-interface-primary-sources.md). The examples below are teaching shapes distilled from Binaryen's dedicated prune fixture and the inherited plain JS-interface wrapper fixture family.

## Purpose

This page catalogs the main before/after shapes a beginner should expect from the prune sibling.

## 1. Plain `i64` wrappers still appear

Before:

```wat
(import "env" "imported-64" (func $imported-64 (param i32 f64) (result i64)))
(func (drop (call $imported-64 (i32.const 0) (f64.const 1.2))))
```

After:

```wat
(import "env" "imported-64" (func $legalimport$imported-64 (param i32 f64) (result i32)))
(func $legalfunc$imported-64 (param i32 f64) (result i64) ...)
(func (drop (call $legalfunc$imported-64 ...)))
```

Meaning:

- the sibling still inherits the plain pass's `i64` wrapper story
- prune mode does not skip the ordinary legalization phase

## 2. Illegal imported function with defaultable result becomes a zero stub

Before:

```wat
(import "env" "imported-v128" (func $imported-v128 (result v128)))
```

After:

```wat
(func $imported-v128 (result v128)
  (v128.const i32x4 0 0 0 0)
)
```

Meaning:

- the import is gone
- the function name can stay
- the body is now a trivial defined function returning the default value

## 3. Illegal imported multivalue result becomes a tuple of defaults

Before:

```wat
(import "env" "imported-mv" (func $imported-mv (result i32 f64)))
```

After:

```wat
(func $imported-mv (result i32 f64)
  (tuple.make 2
    (i32.const 0)
    (f64.const 0)
  )
)
```

Meaning:

- multivalue results are illegal at the JS boundary here
- defaultable multivalue pieces are rebuilt as default literals

## 4. Illegal imported no-result function becomes `nop`

Before:

```wat
(import "env" "imported-v128-param-noresult" (func $imported-v128-param-noresult (param v128)))
```

After:

```wat
(func $imported-v128-param-noresult (param v128)
  (nop)
)
```

Meaning:

- no result means Binaryen can emit the smallest possible body

## 5. Illegal imported nondefaultable result becomes `unreachable`

Before:

```wat
(import "env" "imported-v128-nondefaultable" (func $imported-v128-nondefaultable (result v128 (ref any))))
```

After:

```wat
(func $imported-v128-nondefaultable (result v128 (ref any))
  (unreachable)
)
```

Meaning:

- Binaryen cannot synthesize a default non-null reference result safely
- it traps instead of inventing a value

## 6. Illegal exported function simply loses its export

Before:

```wat
(func $export-v128 (export "export-v128") (param v128)
  (unreachable)
)
```

After:

```wat
(func $export-v128 (param v128)
  (unreachable)
)
```

Meaning:

- Binaryen keeps the function
- Binaryen removes only the JS-visible export

## 7. Imported-and-exported illegal function is both stubbed and unexported

Before:

```wat
(import "env" "imported-v128" (func $imported-v128 (result v128)))
(export "imported-v128" (func $imported-v128))
```

After:

```wat
(func $imported-v128 (result v128)
  (v128.const i32x4 0 0 0 0)
)
```

Meaning:

- the import was stripped and replaced with a body
- the export was removed too
- import pruning and export pruning are separate steps that can both apply

## 8. Illegal global export disappears, global stays

Before:

```wat
(global $v128 v128 (v128.const i32x4 0 0 0 0))
(export "illegal" (global $v128))
```

After:

```wat
(global $v128 v128 (v128.const i32x4 0 0 0 0))
```

Meaning:

- the global itself remains
- only its JS-visible export is pruned

## Beginner rule of thumb

If the plain pass page teaches “wrap `i64` boundaries,” this page teaches the missing second rule:

- if wrapping still cannot make the boundary JS-legal, Binaryen either **stubs the import** or **hides the export**.

Current Starshine has no implementation of these shapes yet; see [`./starshine-strategy.md`](./starshine-strategy.md) for the local code surfaces a future module pass would need to update.
