---
kind: concept
status: supported
last_reviewed: 2026-06-18
sources:
  - ../../../raw/research/0139-2026-04-20-global-refining-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./exports-public-types-and-retagging.md
  - ./parity.md
  - ../../no-dwarf-default-optimize-path.md
---

# `global-refining` WAT shapes

This page is the beginner-friendly shape catalog for Binaryen's `global-refining` pass.

## Read this page with one mental model

Binaryen `global-refining` is trying to prove:

- this global's initializer and all observed assigned values fit a narrower reference type,
- changing the declaration is legal at the module boundary,
- and every `global.get` user can be updated to the new type afterward.

If that proof fails, the pass keeps the old declaration.

## Quick glossary

- **declared type**: the current type written on the global declaration
- **observed writes**: the value types seen in every `global.set` to that global
- **LUB**: least upper bound; the most specific type that still covers every observed value
- **public type**: a type that Binaryen considers valid to expose at a module boundary
- **retagging**: updating cached `global.get` result types after the declaration changes

## Positive family 1: init-only null function-ref global

Before:

```wat
(type $foo_t (func))
(global $g (mut funcref) (ref.null $foo_t))
```

After, conceptually:

```wat
(global $g (mut nullfuncref) (ref.null nofunc))
```

Why this happens:

- the initializer is the only observed value
- it is more specific than broad `funcref`
- the global is private and safe to rewrite

## Positive family 2: init-only `ref.func` exact function type

Before:

```wat
(type $foo_t (func))
(func $foo (type $foo_t))
(global $g (mut funcref) (ref.func $foo))
```

After, conceptually:

```wat
(global $g (mut (ref (exact $foo_t))) (ref.func $foo))
```

Why this matters:

- Binaryen is willing to infer an exact internal function-ref type for a private global
- this is a declaration refinement, not a constant-folding rewrite

## Positive family 3: exact function ref plus later null write

Before:

```wat
(type $foo_t (func))
(func $foo (type $foo_t)
  (global.set $g (ref.null $foo_t)))
(global $g (mut funcref) (ref.func $foo))
```

After, conceptually:

```wat
(global $g (mut (ref null (exact $foo_t))) (ref.func $foo))
```

Why this happens:

- one observed value is the exact function ref
- another observed value is null
- the LUB becomes nullable exact, not broad `funcref`

## Positive family 4: all observed values are non-null exact function refs

Before:

```wat
(type $foo_t (func))
(func $foo)
(global $g (mut funcref) (ref.func $foo))
(func $set
  (global.set $g (ref.func $foo)))
```

After, conceptually:

```wat
(global $g (mut (ref (exact $foo_t))) (ref.func $foo))
```

Why this matters:

- the pass can remove nullability when null never appears in the initializer or writes

## Positive family 5: heterogeneous GC writes refine `anyref` to `eqref`

Before:

```wat
(type $struct (struct))
(type $array (array i8))
(global $g (mut anyref) (ref.null any))
(func $set
  (global.set $g (ref.i31 (i32.const 0)))
  (global.set $g (struct.new_default $struct))
  (global.set $g (ref.null eq))
  (global.set $g (ref.null i31))
  (global.set $g (ref.null $array)))
```

After, conceptually:

```wat
(global $g (mut eqref) (ref.null none))
```

This is the most important shape for understanding the algorithm.
It shows that Binaryen is computing a meaningful least upper bound over all observed values, not just picking one example write.

## Positive family 6: expression-typed i31, conversion, and GC constructor initializers

Before:

```wat
(type $s (struct))
(global $i (mut anyref) (ref.i31 (i32.sub (i32.const 0) (i32.const 7))))
(global $extern externref (extern.convert_any (ref.i31 (i32.const 7))))
(global $sref (mut anyref) (struct.new_default $s))
```

After, conceptually:

```wat
(global $i (mut (ref i31)) (ref.i31 (i32.sub (i32.const 0) (i32.const 7))))
(global $extern (ref extern) (extern.convert_any (ref.i31 (i32.const 7))))
(global $sref (mut (ref (exact $s))) (struct.new_default $s))
```

Why this matters:

- initializer facts are not limited to `ref.null` and `ref.func`
- the pass should use expression result typing so nested numeric producers, `ref.i31`, and conversions carry Binaryen-equivalent non-null reference facts
- GC constructors can prove exact non-null private heap types
- exported immutable globals still need the public-type guard before exposing those exact/private types; under the Starshine/Binaryen `--all-features` custom-descriptor lane, that guard accepts exact/private types

## Positive family 7: dependent global initializer needs retagging

Before:

```wat
(type $super (sub (func)))
(type $sub (sub $super (func)))
(func $func (type $sub))
(global $a (ref $super) (ref.func $func))
(global $b (ref $super) (global.get $a))
```

After, conceptually:

```wat
(global $a (ref (exact $sub)) (ref.func $func))
(global $b (ref $super) (global.get $a))
```

What this teaches:

- `global-refining` can change one global declaration without changing another
- but `global.get $a` in `$b`'s initializer must still become type-correct relative to the new declaration
- this is why Binaryen runs the retagging pass on module code too

## Positive family 8: open-world immutable exported public refinement

Before:

```wat
(global $imm-exp (ref null func) (ref.null nofunc))
(export "imm-exp" (global $imm-exp))
```

After, conceptually in open world:

```wat
(global $imm-exp nullfuncref (ref.null nofunc))
(export "imm-exp" (global $imm-exp))
```

Why this is allowed:

- the global is immutable
- the refined type is still public
- Binaryen permits that exact case in open world

## Negative family 1: imported global

Before:

```wat
(import "env" "g" (global $g (mut funcref)))
```

Why this blocks optimization:

- the pass does not own imported boundary declarations

## Negative family 2: non-reference global

Before:

```wat
(global $g (mut i32) (i32.const 0))
```

Why this stays unchanged:

- `global-refining` is about reference-type tightening
- integer globals are out of scope

## Negative family 3: exported mutable global in open world

Before:

```wat
(global $mut-exp (mut (ref null func)) (ref.null nofunc))
(export "mut-exp" (global $mut-exp))
```

Why this blocks optimization:

- another module could write through the old broader type
- Binaryen conservatively preserves the declared boundary type

## Negative family 4: any exported global in closed world

Before:

```wat
(global $imm-exp (ref null func) (ref.null nofunc))
(export "imm-exp" (global $imm-exp))
```

Why this still blocks optimization in official `version_130` closed world:

- the implementation currently skips all exported globals in closed world
- this is a source-backed current limitation, not a theoretical requirement of the idea

## Feature-disabled negative family 5: immutable exported exact/private target without custom descriptors

Conceptually:

```wat
(type $foo_t (func))
(func $foo (type $foo_t))
(global $g (ref null func) (ref.func $foo))
(export "g" (global $g))
```

Why Binaryen does not refine this exported global all the way to `ref null (exact $foo_t)` in open world when custom descriptors are disabled:

- exact heap-ref types are not valid public types on the non-custom-descriptor path
- the boundary rule, not the LUB, is what stops the rewrite

Under the current Starshine direct-pass feature model and the Binaryen `--all-features` oracle lane, custom descriptors are enabled and Binaryen's public-type validator accepts exact refs. Starshine now follows that all-features behavior locally for exported immutable globals.

## Positive family 6: exact array constructor initializer

Before:

```wat
(type $array (array i32))
(global $g eqref
  (array.new_default $array (i32.const 1)))
```

After:

```wat
(type $array (array i32))
(global $g (ref (exact $array))
  (array.new_default $array (i32.const 1)))
```

Why this matters:

- Binaryen records array constructor result expressions as exact non-null references
- Starshine's initializer typing relies on validator instruction typing, so `array.new`, `array.new_default`, `array.new_fixed`, `array.new_data`, and `array.new_elem` must expose exact result refs for `global-refining` parity

## Negative family 6: no improvement because the LUB equals the old type

Before:

```wat
(global $g (mut anyref) (ref.null any))
(func $set
  (global.set $g (array.new_default $array (i32.const 1))))
```

Why this may stay unchanged:

- if the observed values still require `anyref`, there is nothing to tighten

## Negative family 7: flow-insensitive widening by a rare write

Before:

```wat
(global $g (mut eqref) (ref.null eq))
(func $set (param i32)
  (local.get 0
   if
    (then
      (global.set $g (struct.new_default $s)))
    (else
      (global.set $g (ref.i31 (i32.const 0))))))
```

Why this is important:

- control-flow probability does not matter
- both writes count equally toward the LUB
- the pass does not try to prove that one branch is dead or cold

## Negative family 8: not a `global.get`-to-constant optimizer

Before:

```wat
(global $g (ref null func) (ref.func $foo))
(func (result funcref)
  (global.get $g))
```

What `global-refining` does **not** do:

- it does not replace the `global.get` with `ref.func $foo`
- it only narrows the declared result type of that `global.get`

## Negative family 9: not a dead-write remover

Before:

```wat
(global $g (mut eqref) (ref.null eq))
(func
  (global.set $g (ref.i31 (i32.const 0)))
  (global.set $g (ref.i31 (i32.const 1))))
```

What the pass does **not** do:

- it does not delete the earlier overwritten `global.set`
- both writes still count toward the candidate type

## What this pass does **not** mean

These are useful non-goals to keep explicit:

- generic global value propagation
- constant replacement of global reads
- dead global store elimination
- control-flow-sensitive write filtering
- field-value inference like `gsi`
- export-boundary weakening just because the module is in closed world

## Scheduler interaction to remember

`global-refining` is intentionally early and module-scoped.
In the repo's canonical open-world no-DWARF path it sits between `once-reduction` and the second `remove-unused-module-elements`, then feeds `gsi`.

Its job is not to simplify all global behavior.
Its job is to make global declarations more precise early enough that later global and GC passes see better types.
