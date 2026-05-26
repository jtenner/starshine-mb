---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-04-24-propagate-globals-globally-primary-sources.md
  - ../../../raw/binaryen/2026-05-05-propagate-globals-globally-current-main-recheck.md
  - ../../../raw/research/0320-2026-04-24-propagate-globals-globally-source-correction-and-starshine-followup.md
  - ../../../raw/research/0459-2026-05-05-propagate-globals-globally-current-main-recheck.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./shared-engine-and-startup-boundaries.md
  - ./starshine-strategy.md
  - ../simplify-globals/index.md
---

# `propagate-globals-globally` WAT Shapes

This page is the beginner-friendly shape catalog for Binaryen's `propagate-globals-globally` pass.

## Read this page with one mental model

Binaryen is not asking:

- “can I replace this global everywhere?”

It is asking a smaller question:

- “is this top-level initializer or active offset still a constant expression after known immutable globals are substituted?”

## Important note about examples

The `after` snippets are conceptual and intentionally compact. Real Binaryen output may preserve declarations that later passes remove or may print equivalent constant-expression forms differently. The important point is the rewrite boundary. The 2026-05-05 current-main recheck did not change these shape families.

## Quick glossary

- **known global value**: literal values recorded from an immutable defined global initializer that Binaryen still sees as a constant expression
- **startup-level expression**: a global initializer or active segment offset evaluated outside ordinary function execution
- **active offset**: the offset expression in an active data or element segment
- **code use**: a `global.get` inside an ordinary function body; this pass preserves it

## Shape 1: direct global-to-global propagation

Before:

```wat
(global $a i32 (i32.const 10))
(global $b i32 (global.get $a))
```

After, conceptually:

```wat
(global $a i32 (i32.const 10))
(global $b i32 (i32.const 10))
```

Why it rewrites:

- `$a` has a known constant initializer
- `$b` is a startup-level expression
- replacing `global.get $a` keeps `$b` a constant expression

## Shape 2: chained arithmetic over a known global

Before:

```wat
(global $base i32 (i32.const 8))
(global $off i32 (i32.add (global.get $base) (i32.const 4)))
```

After, conceptually:

```wat
(global $base i32 (i32.const 8))
(global $off i32 (i32.add (i32.const 8) (i32.const 4)))
```

A later fold may turn that into `i32.const 12`, but this pass's source-backed operation is substitution of the known global value.

## Shape 3: multi-value / compound constant-expression propagation

The dedicated Binaryen lit file includes a GC/string constant-expression family using `string.const` inside a struct construction.

Before, conceptually:

```wat
(global $str stringref (string.const "abc"))
(global $pair (ref $Pair)
  (struct.new $Pair (global.get $str) (i32.const 1)))
```

After, conceptually:

```wat
(global $pair (ref $Pair)
  (struct.new $Pair (string.const "abc") (i32.const 1)))
```

Why it matters:

- the pass is not limited to scalar `i32` globals
- the underlying source uses Binaryen's constant-expression predicate and literal storage
- do not replace this with a closed wiki-maintained expression whitelist

## Shape 4: active data offset propagation

Before:

```wat
(memory 1)
(global $off i32 (i32.const 8))
(data (global.get $off) "abc")
```

After, conceptually:

```wat
(memory 1)
(global $off i32 (i32.const 8))
(data (i32.const 8) "abc")
```

This is one of the most important shapes in the folder because it proves the pass is about startup-level expressions, not only global declarations.

## Shape 5: active element offset propagation

Before:

```wat
(table $t 4 funcref)
(func $f)
(global $off i32 (i32.const 1))
(elem (table $t) (global.get $off) func $f)
```

After, conceptually:

```wat
(table $t 4 funcref)
(func $f)
(global $off i32 (i32.const 1))
(elem (table $t) (i32.const 1) func $f)
```

Why it rewrites:

- active elem offsets are a first-class rewrite target in `propagateConstantsToGlobals()`

## Shape 6: ordinary function-body use is preserved

Before:

```wat
(global $a i32 (i32.const 10))

(func $use (result i32)
  (global.get $a)
)
```

After `--propagate-globals-globally`, conceptually:

```wat
(global $a i32 (i32.const 10))

(func $use (result i32)
  (global.get $a)
)
```

Why it stays:

- this public pass does not call the broader function-body propagation routine
- `simplify-globals` is the sibling that may rewrite this shape

## Shape 7: mutable global bailout

Before:

```wat
(global $a (mut i32) (i32.const 10))
(global $b i32 (global.get $a))
```

After, conceptually:

```wat
;; preserved or rejected by validation depending on the exact constant-expression context
```

Why it is not a positive:

- runtime-mutated values are not startup constants
- Starshine and Binaryen validation also treat mutable `global.get` in constant-expression contexts as a special rule boundary

## Shape 8: non-constant expression bailout

Before, conceptually:

```wat
(global $g i32
  ;; a startup expression shape that does not pass Binaryen's constant-expression predicate
  (...non-constant expression...))
```

After:

```wat
;; preserved
```

Why it stays:

- the source-backed acceptance rule is `Properties::isConstantExpression(...)`
- unsupported expression families must not be rewritten just because they contain a known `global.get`

## Shape 9: passive/declarative segments are not offset targets

Before:

```wat
(data "abc")
(elem declare func $f)
```

After:

```wat
;; no offset to rewrite
```

Why it stays:

- passive/declarative segment payloads do not have active offset expressions
- this pass is not segment DCE or payload normalization

## Shape 10: imported or earlier immutable global caveat

Wasm constant-expression rules can allow `global.get` of immutable imported or prior-defined globals. Binaryen's reviewed pass records values from defined globals whose initializers produce literals; it does not magically know arbitrary imported global values.

Before:

```wat
(import "env" "x" (global $x i32))
(global $y i32 (global.get $x))
```

After, conceptually:

```wat
;; no substitution unless Binaryen has recorded literal values for the referenced global
```

## Binaryen versus Starshine caveat

Current Starshine does not implement this pass. The local registry rejects explicit requests before any module rewrite runs; see [`./starshine-strategy.md`](./starshine-strategy.md). These WAT examples are therefore future-port targets, not descriptions of current Starshine behavior.

## Validation checklist for these shapes

A future Starshine port should include tests for:

- direct global chain positive
- arithmetic or compound constant-expression positive
- active data offset positive
- active elem offset positive
- function-body preservation negative
- mutable-global / unknown-value negative
- passive/declarative segment no-op
- imported-global no-known-literal caveat
