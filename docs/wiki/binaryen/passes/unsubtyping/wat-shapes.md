---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-unsubtyping-primary-sources.md
  - ../../../raw/research/0289-2026-04-24-unsubtyping-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0154-2026-04-21-unsubtyping-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./descriptor-squares-casts-and-js-boundaries.md
  - ./starshine-strategy.md
---

# `unsubtyping` WAT shapes

This page is the beginner-friendly shape catalog for Binaryen `unsubtyping`.
Use it with the reviewed source manifest in [`../../../raw/binaryen/2026-04-24-unsubtyping-primary-sources.md`](../../../raw/binaryen/2026-04-24-unsubtyping-primary-sources.md) and the current Starshine status page in [`./starshine-strategy.md`](./starshine-strategy.md).

## Read this page with one mental model

Binaryen is usually trying to do one of four things here:

1. keep a subtype edge because validation needs it
2. keep a subtype edge because a cast could still observe it
3. keep a descriptor edge because descriptor rules or JS can still observe it
4. remove a relation and then repair allocations or surrounding types so the module stays valid

So the pass is not just “deleting arrows in the type section.”
It is **relation pruning plus repair**.

## Important note about the examples

Most of the official lit files for this pass run:

- `--unsubtyping --remove-unused-types`

So when a type definition disappears in the conceptual “after” shapes below, that often means:

- `unsubtyping` first made the relation unnecessary, and then
- `remove-unused-types` erased the now-unused type definition

Read the examples as semantic before/after families, not as proof that `unsubtyping` alone deletes every vanished type definition directly.

## Shape 1: an unused parent relation can collapse away

Before, conceptually:

```wat
(module
  (type $super (sub (struct)))
  (type $sub1 (sub $super (struct (field i32))))
  (type $sub2 (sub $super (struct (field f32))))
  (global $g1 (ref $sub1) (struct.new_default $sub1))
  (global $g2 (ref $sub2) (struct.new_default $sub2)))
```

After, conceptually:

```wat
(module
  (type $sub1 (sub (struct (field i32))))
  (type $sub2 (sub (struct (field f32))))
  ...)
```

Why:

- nothing requires either child to remain a subtype of `$super`
- so the minimized forest can re-root both children
- later `remove-unused-types` can erase the dead parent type

## Shape 2: public types freeze declaration edges

Before, conceptually:

```wat
(module
  (type $super (sub (func)))
  (type $sub (sub $super (func)))
  (func $super (export "super") (type $super) unreachable)
  (func $sub   (export "sub")   (type $sub)   unreachable))
```

After, conceptually:

```wat
(module
  (type $super (sub (func)))
  (type $sub (sub $super (func)))
  ...)
```

Why:

- exported/public types are frozen
- `unsubtyping` only rewrites private relation edges meaningfully

## Shape 3: ordinary validation flow keeps a subtype edge alive

Before, conceptually:

```wat
(module
  (type $super (sub (struct)))
  (type $sub (sub $super (struct)))
  (func (result (ref $super))
    (struct.new $sub)))
```

After, conceptually:

```wat
(module
  (type $super (sub (struct)))
  (type $sub (sub $super (struct)))
  ...)
```

Why:

- the function body result must still validate as the declared function result
- so `$sub <: $super` remains required

The same family appears for:

- global initializers
- table initializers
- active element segments
- local/global/table sets
- `select`
- returns and multivalue returns
- tag payloads
- try/catch result flow
- stack-switching payload flow

## Shape 4: kept declaration edges imply deeper structural edges

Before, conceptually:

```wat
(module
  (type $X (sub (struct)))
  (type $Y (sub $X (struct)))
  (type $A (sub (struct (field (ref null $X)))))
  (type $B (sub $A (struct (field (ref null $Y)))))
  (global $g (ref $A) (struct.new_default $B)))
```

After, conceptually:

```wat
(module
  ;; still needs $B <: $A
  ;; therefore still needs $Y <: $X too
  ...)
```

Why:

- keeping `$B <: $A` forces field-type compatibility too
- `unsubtyping` is not allowed to keep the outer edge and forget the inner structural consequence

The same story appears for arrays and function types in the baseline test file.

## Shape 5: an isolated downcast can optimize aggressively

Before, conceptually:

```wat
(module
  (type $top (sub (struct)))
  (type $mid (sub $top (struct)))
  (func
    (drop
      (ref.cast (ref $mid)
        (struct.new $top)))))
```

After, conceptually:

```wat
(module
  ;; the cast can only fail here, so the target relation need not stay
  (func
    (drop
      (ref.cast (ref none)
        (struct.new_default $top)))))
```

Why:

- no concrete subtype that would have satisfied the cast is shown to flow into the source
- so the cast does not force `$mid <: $top` to remain

This is one of the biggest beginner corrections in the whole pass.

## Shape 6: once a concrete flowing subtype appears, the cast keeps more edges

Before, conceptually:

```wat
(module
  (type $top (sub (struct)))
  (type $mid (sub $top (struct)))
  (type $bot (sub $mid (struct)))
  (func (param $top (ref $top))
    (local $l (ref null $top))
    (local.set $l (struct.new $bot))
    (drop
      (ref.cast (ref $mid)
        (local.get $top)))))
```

After, conceptually:

```wat
(module
  ;; now a $bot can inhabit the $top-typed location,
  ;; so $mid <: $top must remain for the cast to keep succeeding on that flow
  ...)
```

Why:

- a concrete flowing value can now make cast success observable
- so the cast is no longer ignorable

## Shape 7: exact casts keep less than ordinary casts

Before, conceptually:

```wat
(module
  (type $top (sub (struct)))
  (type $mid (sub $top (struct)))
  (type $bot (sub $top (struct)))
  (global $g anyref (struct.new $bot))
  (func (param $any anyref)
    (drop
      (ref.cast (ref null (exact $top))
        (local.get $any)))))
```

After, conceptually:

```wat
(module
  ;; exact cast only needs exact $top to remain a subtype of the source,
  ;; not all destination-subtype families
  ...)
```

Why:

- exact casts do not care about subtypes of the destination type
- so they keep a smaller relation surface than ordinary casts

The same rule applies to exact `br_on_cast` and `br_on_cast_fail` families.

## Shape 8: guaranteed-success upcasts keep the direct relation they need

Before, conceptually:

```wat
(module
  (type $top (sub (func)))
  (type $bot (sub $top (func)))
  (table $t 1 1 (ref null $bot))
  (func $f (type $bot)
    (call_indirect $t (type $top) (i32.const 0))))
```

After, conceptually:

```wat
(module
  ;; call_indirect target cast must remain a guaranteed success,
  ;; so $bot <: $top stays
  ...)
```

Why:

- removing that relation would change a guaranteed-success cast into a failure

## Shape 9: `ref.eq` should not keep user-type relations alive by itself

Before, conceptually:

```wat
(module
  (type $top (sub (struct)))
  (type $mid (sub $top (struct)))
  (type $bot (sub $mid (struct)))
  (func (param $x (ref null $mid)) (param $y (ref null $mid))
    (drop (ref.eq (local.get $x) (local.get $y)))))
```

After, conceptually:

```wat
(module
  ;; eqref validation still matters,
  ;; but this alone should not keep unrelated user-type subtype chains alive
  ...)
```

Why:

- `ref.eq` is a non-flow constraint here
- it validates against a basic type but does not create the kind of flow that ordinary casts or stores do

## Shape 10: descriptor relation can disappear if nothing observes it

Before, conceptually:

```wat
(module
  (rec
    (type $A (sub (descriptor $A.desc) (struct)))
    (type $A.desc (sub (describes $A) (struct)))
    (type $B (sub $A (descriptor $B.desc) (struct)))
    (type $B.desc (sub $A.desc (describes $B) (struct))))
  (global $A (ref null $A) (struct.new_desc $A (struct.new $A.desc)))
  (global $B (ref null $B) (struct.new_desc $B (struct.new $B.desc))))
```

After, conceptually:

```wat
(module
  (rec
    (type $A (sub (struct)))
    (type $A.desc (sub (struct)))
    (type $B (sub (struct)))
    (type $B.desc (sub (struct))))
  (global $A (ref null $A) (struct.new_default $A))
  (global $B (ref null $B) (struct.new_default $B)))
```

Why:

- no operation still requires the subtype or descriptor-square relations
- so both kinds of relation can disappear
- later `remove-unused-types` can shrink the type section further

## Shape 11: `ref.get_desc` keeps descriptor relation alive

Before, conceptually:

```wat
(module
  (rec
    (type $A (sub (descriptor $A.desc) (struct)))
    (type $A.desc (sub (describes $A) (struct))))
  (func (param $a (ref $A))
    (drop (ref.get_desc $A (local.get $a)))))
```

After, conceptually:

```wat
(module
  ;; $A must still have $A.desc as its descriptor
  ...)
```

Why:

- `ref.get_desc` observes the described/descriptor relation directly

The same general family appears for descriptor-aware cast forms.

## Shape 12: descriptor relation can disappear inside functions if the trap is repaired

Before, conceptually:

```wat
(module
  (rec
    (type $A (sub (descriptor $A.desc) (struct)))
    (type $A.desc (sub (describes $A) (struct))))
  (func (param $d (ref null (exact $A.desc)))
    (drop
      (struct.new_desc $A
        (local.get $d)))))
```

After, conceptually:

```wat
(module
  (rec
    (type $A (sub (struct)))
    (type $A.desc (sub (struct))))
  (func (param $d (ref null (exact $A.desc)))
    (local $tmp (ref (exact $A.desc)))
    (drop
      (block (result (ref (exact $A)))
        (local.set $tmp
          (ref.as_non_null (local.get $d)))
        (struct.new_default $A)))))
```

Why:

- the descriptor relation is no longer needed semantically
- but a null descriptor trap must still happen in the function when traps matter
- so Binaryen preserves the trap and drops the descriptor edge separately

## Shape 13: module-level nullable descriptor trap may need a synthetic global

Before, conceptually:

```wat
(module
  (rec
    (type $A (sub (descriptor $A.desc) (struct)))
    (type $A.desc (sub (describes $A) (struct))))
  (global $A.desc (ref null (exact $A.desc)) (struct.new $A.desc))
  (global $A (ref null $A)
    (struct.new_desc $A
      (global.get $A.desc))))
```

After, conceptually:

```wat
(module
  ;; if the descriptor edge disappears but the init can still trap,
  ;; Binaryen may keep or synthesize helper globals to preserve instantiation traps
  ...)
```

Why:

- module-level code cannot use locals for repair
- instantiation-time traps are still observable

This is one of the most non-obvious parts of the pass.

## Shape 14: `trapsNeverHappen` removes some descriptor-fixup pressure

Before, conceptually:

```wat
(module
  ;; same nullable-descriptor families as above
  ...)
```

After under `-tnh`, conceptually:

```wat
(module
  ;; fewer or no ref.as_non_null / helper-global preservation steps
  ...)
```

Why:

- if traps are assumed never to happen, preserving a nullable-descriptor trap no longer constrains the rewrite the same way

That is exactly what `unsubtyping-desc-tnh.wast` exists to teach.

## Shape 15: JS boundary can keep subtype edges alive through `any`

Before, conceptually:

```wat
(module
  (type $super (sub (struct)))
  (type $sub (sub $super (struct)))
  (@binaryen.js.called
   (func (param (ref null $super))
     (local $any anyref)
     (local $subv (ref null $sub))
     (local.set $any (local.get $subv)))))
```

After, conceptually:

```wat
(module
  ;; JS boundary behaves like flow from any into $super,
  ;; combined with $sub flowing to any inside the body,
  ;; so $sub <: $super` must remain
  ...)
```

Why:

- values coming in from JS are modeled like casts from `any`
- values going out to JS are modeled like flowing into `any`
- together they can make the subtype relation observable

## Shape 16: JS prototype-capable descriptors stay alive when exposed

Before, conceptually:

```wat
(module
  (rec
    (type $Struct (descriptor $Desc) (struct))
    (type $Desc (describes $Struct) (struct (field externref))))
  (@binaryen.js.called
   (func (result (ref $Struct))
     unreachable)))
```

After, conceptually:

```wat
(module
  ;; descriptor relation must stay because JS may observe the configured prototype
  ...)
```

Why:

- the type flows out to JS
- the descriptor can carry a prototype in immutable field `0`
- so the descriptor relation remains observable even if wasm itself never calls `ref.get_desc`

## Shape 17: non-prototype descriptors can still disappear at the JS boundary

Before, conceptually:

```wat
(module
  (rec
    (type $Struct (descriptor $Desc) (struct))
    (type $Desc (describes $Struct) (struct (field stringref))))
  (@binaryen.js.called
   (func (result (ref $Struct))
     unreachable)))
```

After, conceptually:

```wat
(module
  ;; descriptor can still disappear because it cannot configure a JS prototype
  ...)
```

Why:

- JS exposure only keeps descriptors that satisfy the prototype-field rule
- arbitrary descriptor payloads do not automatically survive

## Shape 18: `extern.convert_any` can keep a descriptor alive

Before, conceptually:

```wat
(module
  (rec
    (type $Struct (descriptor $Desc) (struct))
    (type $Desc (describes $Struct) (struct (field externref))))
  (func
    (local $s (ref null $Struct))
    (drop (extern.convert_any (local.get $s)))))
```

After, conceptually:

```wat
(module
  ;; even without export/import flow, externalizing the value exposes it to JS
  ;; so the descriptor may need to stay
  ...)
```

Why:

- `extern.convert_any` is treated as JS exposure in the pass

## Shape 19: continuation and stack-switching forms are part of the contract

Before, conceptually:

```wat
(module
  (type $super (sub (func (param (ref $S)))))
  (type $sub (sub $super (func (param (ref $T)))))
  (type $cont (cont $super))
  (func $f (type $sub)
    (drop (cont.new $cont (ref.func $f)))))
```

After, conceptually:

```wat
(module
  ;; continuation signatures still require compatible subtype relations
  ...)
```

Why:

- `cont.new`, `cont.bind`, `suspend`, and `resume` all participate in the shared validation-constraint surface
- `unsubtyping` is incomplete if it only handles classic struct/call shapes

## Bottom line

The main shape lesson of `unsubtyping` is:

- **a relation can disappear only if Binaryen can still preserve validation, casts, descriptors, JS prototype behavior, and nullable-descriptor traps.**

That is what future port work must match.

## Sources

- [`../../../raw/research/0154-2026-04-21-unsubtyping-binaryen-research.md`](../../../raw/research/0154-2026-04-21-unsubtyping-binaryen-research.md)
- Binaryen `version_129`:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/Unsubtyping.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/subtype-exprs.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/js-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/localize.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/effects.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/unsubtyping.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/unsubtyping-casts.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/unsubtyping-desc.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/unsubtyping-desc-tnh.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/unsubtyping-jsinterop.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/unsubtyping-stack-switching.wast>
