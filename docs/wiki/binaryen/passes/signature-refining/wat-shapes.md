---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-signature-refining-current-main-recheck.md
  - ../../../raw/research/0451-2026-05-05-signature-refining-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-24-signature-refining-primary-sources.md
  - ../../../raw/research/0307-2026-04-24-signature-refining-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0152-2026-04-21-signature-refining-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./params-results-publicity-and-intrinsics.md
  - ./starshine-strategy.md
---

# `signature-refining` WAT shapes

This page is a beginner-friendly catalog of the main WAT / module-shape families Binaryen `signature-refining` rewrites, preserves, or bails out on.
The source provenance is now captured in [`../../../raw/binaryen/2026-05-05-signature-refining-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-signature-refining-current-main-recheck.md), and the current Starshine status is in [`./starshine-strategy.md`](./starshine-strategy.md).

The pass is shape-driven, but the important shapes are not just inside one function body.
They often include:

- the nominal function type
- every sibling function sharing that type
- every direct `call`
- every `call_ref`
- sometimes `call.without.effects`
- sometimes public-rec-group, tag, or continuation users elsewhere in the module

## Reading rule

When this page says a type is refinable, the real upstream meaning is:

- Binaryen has enough evidence to make the nominal heap type more specific
- every function sharing that heap type can still validate after body repair
- every direct `call` and `call_ref` user of that heap type can still validate
- the heap type is not blocked by public, import, tag, subtype, table, or similar rules

## Positive shape 1: direct-call param refinement to an exact struct ref

### Before

```wat
(type $sig (sub (func (param anyref))))
(type $struct (struct))
(func $target (type $sig) (param $x anyref)
  nop
)
(func $caller
  (call $target
    (struct.new $struct)
  )
)
```

### After

- `$sig` becomes `(sub (func (param (ref (exact $struct)))))`
- `$target`'s printed param becomes `(ref (exact $struct))`
- the caller stays valid because it already passed exactly that shape

### Why it works

The parameter LUB across all calls is the exact non-null `$struct` type.

## Positive shape 2: the same works through `call_ref`

### Before

```wat
(type $sig (sub (func (param anyref))))
(type $struct (struct))
(func $target (type $sig) (param $x anyref)
  nop
)
(func $caller
  (call_ref $sig
    (struct.new $struct)
    (ref.func $target)
  )
)
```

### After

- `$sig` again refines to `(ref (exact $struct))`
- the `call_ref` continues to typecheck with the sharper heap type

### Why it works

`call_ref` operands count toward parameter LUB computation just like direct calls do.

## Positive shape 3: mixed callers can refine only to a common parent or `eqref`

### Before

```wat
(rec
  (type $sig (sub (func (param anyref))))
  (type $struct (sub (struct)))
  (type $struct-sub1 (sub $struct (struct)))
  (type $struct-sub2 (sub $struct (struct)))
)
```

with calls that pass:

- `(struct.new $struct-sub1)`
- `(struct.new $struct-sub2)`

### After

- the param can refine only to `(ref $struct)`, not to either exact child subtype

### Why it works

The pass uses the type lattice's least upper bound over **all** actuals.

A sibling test family also shows a mixed direct-plus-`call_ref` case where:

- one caller passes a nullable struct ref
- another passes `i31ref`
- the final param LUB becomes `eqref`

## Positive shape 4: only one function is called, but all siblings sharing the heap type still update

### Before

```wat
(type $sig (sub (func (param anyref))))
(func $func-1 (type $sig) (param anyref) nop)
(func $func-2 (type $sig) (param anyref) nop)
(func $caller
  (call $func-1
    (struct.new $struct)
  )
)
```

### After

- both `$func-1` and `$func-2` print the sharper param type

### Why it works

The decision unit is the shared nominal heap type, not just the directly called function.

## Positive shape 5: nullable exact refinement when some calls pass null

### Before

```wat
(type $sig (sub (func (param anyref))))
(type $struct (struct))
(func $target (type $sig) (param anyref) nop)
(func $caller
  (call $target (struct.new $struct))
  (call $target (ref.null none))
)
```

### After

- the param becomes `(ref null (exact $struct))`

### Why it works

The LUB of exact `$struct` and `null` is the nullable exact `$struct` type.

## Positive shape 6: result refinement from actual returned values

### Before

```wat
(type $sig (sub (func (result anyref))))
(type $struct (struct))
(func $target (type $sig) (result anyref)
  (struct.new $struct)
)
```

### After

- `$sig` becomes `(sub (func (result (ref (exact $struct)))))`
- `$target` prints the sharper result type

### Why it works

Result refinement comes from what the function body and returns actually produce.

## Positive shape 7: direct `call` and `call_ref` users must update their result types too

### Before

```wat
(func $caller
  (drop
    (if (result anyref)
      (i32.const 1)
      (then (call $target))
      (else (unreachable))
    )
  )
)
```

### After

```wat
(func $caller
  (drop
    (if (result (ref (exact $struct)))
      ...
    )
  )
)
```

The official tests show the same story for `call_ref`.

### Why it works

Once the result type of the signature sharpens, Binaryen updates the cached call result types and later refinalizes enclosing control-flow nodes.

## Positive shape 8: multiple functions with the same result type combine to a nullable exact ref

### Before

Several functions share one signature type and return:

- `(struct.new $struct)`
- `(ref.null any)`
- `(ref.null eq)`

### After

- the result type becomes `(ref null (exact $struct))`
- the `ref.null any` and `ref.null eq` sites are normalized to `ref.null none`

### Why it works

The result LUB combines all returned values across every function with the shared heap type.

## Positive shape 9: `call.without.effects` participates in param refinement

### Before

```wat
(import "binaryen-intrinsics" "call.without.effects"
  (func $no.side.effects (param (ref $A) funcref)))
(func $target (param (ref $A)) nop)
(func $calls
  (call $no.side.effects
    (struct.new $B)
    (ref.func $target)
  )
  (call $target
    (struct.new $B)
  )
)
```

### After

- `$target`'s param can refine to `(ref (exact $B))`
- the intrinsic import itself keeps its old param type

### Why it works

For parameter refinement, Binaryen treats `call.without.effects` as an extra call to the referenced target signature.

## Positive shape 10: `call.without.effects` result refinement needs cloned imports

### Before

```wat
(import "binaryen-intrinsics" "call.without.effects"
  (func $no.side.effects (param funcref) (result (ref null $A))))
(func $other (result (ref null $A))
  (struct.new $B)
)
```

### After

- `$other` may refine to result `(ref (exact $B))`
- Binaryen creates a fresh intrinsic import with result `(ref (exact $B))`
- calls that pass `(ref.func $other)` are retargeted to that new import

### Why it works

The intrinsic import's own signature must remain consistent with the sharper referenced function result.

## Negative shape 1: no calls means no param refinement

### Before

```wat
(type $sig (sub (func (param anyref))))
(func $target (type $sig) (param anyref)
  nop
)
```

### After

- no param refinement happens

### Why it bails out

Parameter refinement needs real call-site evidence.
The body alone is not enough.

## Negative shape 2: only unreachable arguments means no param refinement

### Before

```wat
(call_ref $sig
  (unreachable)
  (ref.func $target)
)
```

and there are no other real calls.

### After

- no param refinement happens
- the pass still must not crash

### Why it bails out

Bottom-only evidence is not enough to compute a meaningful param LUB.

## Negative shape 3: any table disables the entire pass today

### Before

```wat
(table 1 1 anyref)
(type $sig (sub (func (param anyref))))
(func $target (type $sig) (param anyref) nop)
```

### After

- no change

### Why it bails out

The current implementation simply returns when the module contains any table.
It does not partially handle `call_indirect` / element-segment worlds yet.

## Negative shape 4: exported or otherwise public rec-group reachability freezes the type

This family is broader than “exported function means no optimization.”
The tests prove stronger cases:

- exporting a function blocks its signature type
- exporting a global of a struct type can indirectly make a nearby signature type public through rec-group reachability

So the real beginner rule is:

- public **type reachability** freezes more than a plain export bit does

## Negative shape 5: imported functions stay untouched

### Before

```wat
(import "a" "b" (func $import (param (ref null struct))))
(func $test
  (call $import
    (struct.new $struct)
  )
)
```

### After

- `$import` keeps its original imported signature

### Why it bails out

The pass deliberately does not modify imported function signatures yet.

## Negative shape 6: subtype-linked signatures are frozen

### Before

```wat
(type $parent (sub (func (param anyref))))
(type $child (sub $parent (func (param anyref))))
```

### After

- no change

### Why it bails out

The official implementation does not attempt subtype-cluster rewrites or contravariance-aware parent/child coordination here.

## Negative shape 7: tag-used signatures are frozen completely

### Before

```wat
(type $sig (func (param anyref)))
(tag $e (type $sig))
(func $optimizable (type $sig) (param anyref)
  ...
)
```

### After

- no refinement for `$sig`

### Why it bails out

The pass does not update tag users of the signature type.

## Negative shape 8: continuation-used signatures freeze params, not every other type in the module

### Before

```wat
(rec
  (type $sig (func (param anyref)))
  (type $other (func (param anyref)))
  (type $cont (cont $sig))
)
```

### After

- functions using `$sig` keep their params unchanged
- a different signature like `$other` can still refine

### Why it bails out

The pass does not yet update continuation instructions with new param types.

## Corner-case shape 1: sharper params can require broader fixup locals inside the body

### Before

```wat
(func $func (type $sig) (param $f funcref)
  (local $temp (ref null $sig))
  (local.set $f
    (local.get $temp)
  )
)
```

### After

- the param type may refine to a sharper `(ref (exact $sig))`
- Binaryen inserts a fresh broader local
- later body traffic uses that fixup local instead of the refined param slot

### Why it matters

This proves the pass is not just changing signature declarations.
It must also keep the function body valid.

## Corner-case shape 2: bottom `call_ref` output must still print valid IR

The lit file has a case where a bottom `call_ref` cannot be emitted directly after refinement.
Binaryen prints a block that:

- drops the bottom reference
- then traps with `unreachable`

The durable lesson is:

- refinement must not create an unprintable or invalid bottom-call shape

## Corner-case shape 3: array and cast refinalization can sharpen too

A later test refines a param from `anyref` to a non-null exact array ref.
That forces later refinalization so a cast in the body sharpens consistently too.

So the pass is not only about call sites.
It also changes what nearby casts and enclosing expressions finalize to.

## Bottom line

The most important `signature-refining` shapes are not just “parameter gets narrower.”
The real source-backed families are:

- heap-type-wide direct plus `call_ref` param positives
- result-refining positives from actual returned values
- public/import/table/tag/subtyping no-ops
- params-only blockers for JS-called and continuation-used signatures
- `call.without.effects` param evidence and result-import repair
- body-fixup locals and refinalization corner cases

Those are the shapes a future port must preserve if it wants to match upstream Binaryen.

## Sources

- [`../../../raw/binaryen/2026-05-05-signature-refining-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-signature-refining-current-main-recheck.md)
- [`../../../raw/research/0451-2026-05-05-signature-refining-current-main-recheck.md`](../../../raw/research/0451-2026-05-05-signature-refining-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-24-signature-refining-primary-sources.md`](../../../raw/binaryen/2026-04-24-signature-refining-primary-sources.md)
- [`../../../raw/research/0307-2026-04-24-signature-refining-primary-sources-and-starshine-followup.md`](../../../raw/research/0307-2026-04-24-signature-refining-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0152-2026-04-21-signature-refining-binaryen-research.md`](../../../raw/research/0152-2026-04-21-signature-refining-binaryen-research.md)
- [`./starshine-strategy.md`](./starshine-strategy.md)
- Binaryen `version_129`:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/SignatureRefining.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/lubs.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/intrinsics.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/signature-refining.wast>
