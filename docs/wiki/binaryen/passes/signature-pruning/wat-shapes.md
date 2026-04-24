---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-signature-pruning-primary-sources.md
  - ../../../raw/research/0304-2026-04-24-signature-pruning-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0151-2026-04-21-signature-pruning-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./constant-actuals-localization-and-boundaries.md
  - ./starshine-strategy.md
---

# `signature-pruning` WAT shapes

This page is a beginner-friendly catalog of the main WAT / module-shape families Binaryen `signature-pruning` rewrites, preserves, or bails out on.
It is now anchored to the 2026-04-24 primary-source manifest in [`../../../raw/binaryen/2026-04-24-signature-pruning-primary-sources.md`](../../../raw/binaryen/2026-04-24-signature-pruning-primary-sources.md) and the Starshine status bridge in [`./starshine-strategy.md`](./starshine-strategy.md).

The pass is shape-driven, but the important shapes are not just inside one function body.
They often include:

- the nominal function type
- every sibling function sharing that type
- every direct `call`
- every `call_ref`
- public-rec-group or tag / continuation users elsewhere in the module

## Reading rule

When this page says a parameter is removable, the real upstream meaning is:

- that parameter is dead across **every function with that heap type**
- and every direct-call plus `call_ref` user of that heap type can drop the operand safely
- and the heap type is not blocked by public or unsupported-surface rules

## Positive shape 1: one heap type, dead middle params, direct and `call_ref` users agree

### Before

```wat
(type $sig (func (param i32 i64 f32 f64)))
(func $foo (type $sig) (param $a i32) (param $b i64) (param $c f32) (param $d f64)
  ;; only use $b and $c
)
(func $caller
  (call $foo
    (i32.const 0)
    (i64.const 1)
    (f32.const 2)
    (f64.const 3)
  )
  (call_ref $sig
    (i32.const 4)
    (i64.const 5)
    (f32.const 6)
    (f64.const 7)
    (ref.func $foo)
  )
)
```

### After

- `$sig` becomes `(func (param i64 f32))`
- `$foo` keeps only the two used params
- both the direct `call` and the `call_ref` drop the removed operands

### Why it works

- the dead params are unused in every function with `$sig`
- both direct and `call_ref` users of `$sig` can drop the matching operands
- the type is private and table-free

## Positive shape 2: all parameters disappear

### Before

```wat
(type $sig (func (param i32 i64 f32 f64)))
(func $foo (type $sig) (param $a i32) (param $b i64) (param $c f32) (param $d f64)
  nop
)
```

### After

```wat
(type $sig (func))
(func $foo (type $sig)
  (local i32 i64 f32 f64)
  nop
)
```

### Important detail

Binaryen does not simply drop the params and forget about the body.
It turns the removed params into ordinary locals so internal uses would still work if they existed.

## Positive shape 3: overwritten param still counts as dead

### Before

```wat
(func $foo (type $sig) (param $x i32)
  (local.set $x
    (i32.const 10)
  )
  (call $bar
    (local.get $x)
  )
)
```

### After

- `$x` can still be removed from the signature
- the body-local version remains

### Why it works

`signature-pruning` uses entry liveness, not raw mention counting.
The incoming parameter value is dead before the first overwrite.

## Positive shape 4: constant actual turns a live-looking param into a dead one

### Before

```wat
(type $sig (func (param i32)))
(func $foo (type $sig) (param $x i32)
  (i32.store
    (i32.const 0)
    (local.get $x)
  )
)
(func $caller
  (call $foo (i32.const 42))
  (call $foo (i32.const 42))
)
```

### After

```wat
(type $sig (func))
(func $foo (type $sig)
  (local $x i32)
  (local.set $x (i32.const 42))
  (i32.store
    (i32.const 0)
    (local.get $x)
  )
)
(func $caller
  (call $foo)
  (call $foo)
)
```

### Why it works

Binaryen first sees that every actual is the same constant, writes that constant into the body, then discovers the incoming parameter is dead, then prunes it.

## Positive shape 5: `ref.func` and `ref.null` actuals count too

The official lit file has the same positive family for:

- `ref.func $foo`
- `ref.null none`

So the pass is not integer-only.
It can treat reference constants as constant actuals too.

## Positive shape 6: side-effectful or interacting actuals can still optimize after localization

### Before

```wat
(call $foo
  (block (result i32)
    (call $caller)
    (i32.const 0)
  )
  (i64.const 1)
  (f32.const 2)
  (f64.const 3)
)
```

### After the full pass story

- first pruning attempt fails for the unused side-effectful operand
- `ChildLocalizer` hoists the effectful operand into a local / outer block
- the second pass cycle sees a simpler call and can then drop the now-localized dead operand

### Why this matters

This is one of the main shapes proving that `signature-pruning` is a two-cycle pipeline, not a one-pass delete-args walk.

## Positive shape 7: different heap types with the same final textual signature stay distinct

### Before

```wat
(rec
  (type $sig1 (func (param i32)))
  (type $sig2 (func (param f64)))
)
```

### After

```wat
(rec
  (type $sig2 (func))
  (type $sig1 (func))
)
```

### Important detail

Binaryen preserves the two nominal heap types even though they both shrink to `(func)`.
This pass is not signature deduplication.

## Negative shape 1: one imported sibling freezes the whole heap type

### Before

```wat
(type $sig (func (param i32)))
(import "out" "func" (func $import (type $sig) (param i32)))
(func $foo (type $sig) (param $x i32)
  nop
)
```

### After

- no change

### Why it bails out

The pass works per heap type.
If an import shares the type, Binaryen freezes the whole type family.

## Negative shape 2: one live local sibling freezes the whole heap type

### Before

```wat
(type $sig (func (param i32)))
(func $foo (type $sig) (param $x i32) nop)
(func $bar (type $sig) (param $x i32)
  (drop (local.get $x))
)
```

### After

- no change

### Why it bails out

The param is dead in `$foo` but live in `$bar`, and the decision is made for the shared nominal type.

## Negative shape 3: a different heap type does **not** block you

If `$foo` and `$bar` look similar textually but use different heap types, one can still prune while the other stays untouched.
This is the positive counterpart to the previous two negatives.

## Negative shape 4: any table disables the entire pass today

### Before

```wat
(table 1 1 anyref)
(type $sig (func (param i32)))
(func $foo (type $sig) (param $x i32) nop)
```

### After

- no change

### Why it bails out

The current implementation simply returns early when the module contains any table.
It does not partially handle `call_indirect` / element-segment worlds yet.

## Negative shape 5: exported or otherwise public rec-group reachability freezes the type

This family is broader than “exported function means no optimization.”
The lit file proves two stronger cases:

- exporting one function can make another function type in the same rec group public too
- a public struct field that mentions the function type can stop Binaryen from swapping in a pruned private replacement

So the true beginner rule is:

- public **rec-group reachability** freezes more than a plain export bit does

## Negative shape 6: `call.without.effects` target signatures are frozen

### Before

```wat
(import "binaryen-intrinsics" "call.without.effects"
  (func $cwe (param i32 funcref) (result i32)))
(func $func (param i32) (result i32)
  (i32.const 1)
)
(func $caller (result i32)
  (call $cwe
    (i32.const 41)
    (ref.func $func)
  )
)
```

### After

- `$func` keeps its parameter

### Why it bails out

Binaryen treats `call.without.effects` as a special unsupported signature-use surface for this pass.

## Negative shape 7: tag-used signatures are frozen

### Before

```wat
(type $sig (func (param anyref)))
(tag $e (type $sig))
(func $unused-param (type $sig) (param anyref)
  nop
)
```

### After

- no change

### Why it bails out

The pass does not update tag users of the signature type.

## Negative shape 8: continuation-used signatures are frozen

### Before

```wat
(rec
  (type $sig (func (param anyref)))
  (type $cont (cont $sig))
)
```

### After

- functions with `$sig` keep their params

### Why it bails out

The pass does not update continuation instructions like `cont.bind` / `resume` here.

## Negative shape 9: function subtyping blocks pruning

### Before

```wat
(type $func.A (sub (func (param ... ) (result ...))))
(type $func.B (sub $func.A (func (param ... ) (result ...))))
```

### After

- no change

### Why it bails out

The official implementation avoids changing param/result counts on types that participate in signature-subtyping relations.

## Corner-case shape 1: unreachable uses must not break type collection or printing

The lit file has a regression where a heap type appears only inside an unreachable cast.
The pass still needs to keep the type bookkeeping valid while pruning an unrelated parameter.

The durable lesson is:

- even seemingly dead unreachable type mentions can still matter for correct type rewriting and printing

## Corner-case shape 2: param-to-local rewriting must preserve tricky local indexes

The later lit regressions use shapes like:

- `v128` params
- nested `local.tee`
- `struct.get`
- `call_ref`

These prove that turning a removed param into a local is not a trivial reindexing step.

## Corner-case shape 3: localization can require EH pop repair

The catch/pop regressions show that once `ChildLocalizer` adds blocks around calls in catch bodies, Binaryen must repair nested `pop` placement.
So EH repair is part of the shape story, not just post-pass cleanup.

## Bottom line

The most important `signature-pruning` shapes are not just “unused arg disappears.”
The real source-backed families are:

- heap-type-wide direct plus `call_ref` positives
- constant-actual promotion positives
- localization-enabled positives
- import/public/tag/continuation/subtyping no-ops
- distinct-type-preserving rewrites
- local-index and EH repair corner cases

Those are the shapes a future port must preserve if it wants to match upstream Binaryen.

## Sources

- [`../../../raw/binaryen/2026-04-24-signature-pruning-primary-sources.md`](../../../raw/binaryen/2026-04-24-signature-pruning-primary-sources.md)
- [`../../../raw/research/0304-2026-04-24-signature-pruning-primary-sources-and-starshine-followup.md`](../../../raw/research/0304-2026-04-24-signature-pruning-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0151-2026-04-21-signature-pruning-binaryen-research.md`](../../../raw/research/0151-2026-04-21-signature-pruning-binaryen-research.md)
- [`./starshine-strategy.md`](./starshine-strategy.md)
- Binaryen `version_129`:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/SignaturePruning.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/param-utils.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/possible-constant.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/localize.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/eh-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/subtypes.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/signature-pruning.wast>
