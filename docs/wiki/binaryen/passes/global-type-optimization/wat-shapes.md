---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-global-type-optimization-primary-sources.md
  - ../../../raw/research/0306-2026-04-24-global-type-optimization-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0153-2026-04-21-global-type-optimization-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./field-removal-subtyping-js-interop-and-traps.md
  - ./starshine-strategy.md
---

# `global-type-optimization` WAT shapes

This page is the beginner-friendly shape catalog for Binaryen `global-type-optimization`.

## Read this page with one mental model

Binaryen is usually trying to do one of four things here:

1. make a private field immutable because no runtime write reaches it
2. remove an unread field because no compatible read needs it
3. reorder parent fields so a removable field can safely fall off the end
4. preserve side effects, traps, and JS-visible descriptor fields while doing all of that

So the pass is not just a type rewrite.
It is a **layout rewrite plus instruction repair**.

## Important note about the examples

These examples are conceptual.
Real Binaryen output may:

- renumber type indices
- add or remove field names
- insert `block` wrappers and temps after child localization
- replace removed writes with `drop` plus null-trap scaffolding
- emit fresh `gto-removed-*` globals for removed module-initializer traps

So read the shapes as semantic before/after families, not exact pretty-print templates.

## Shape 1: a field with only constructor traffic still disappears

Before, conceptually:

```wat
(module
  (type $S (struct (field (mut funcref))))
  (func
    (drop
      (struct.new $S
        (ref.null func)))))
```

After, conceptually:

```wat
(module
  (type $S (struct))
  (func
    (drop
      (struct.new_default $S))))
```

Why:

- constructor traffic does not keep the field alive in the actual decision phase
- the field is unread
- the constructor operand is therefore removable too

This is one of the biggest beginner corrections in the whole pass.

## Shape 2: no runtime `struct.set` means the field can become immutable

Before, conceptually:

```wat
(module
  (type $S (struct (field (mut funcref))))
  (func (param $s (ref $S))
    (drop
      (struct.get $S 0
        (local.get $s)))))
```

After, conceptually:

```wat
(module
  (type $S (struct (field funcref)))
  (func (param $s (ref $S))
    (drop
      (struct.get $S 0
        (local.get $s)))))
```

Why:

- the field is read
- so it cannot disappear
- but there are no runtime writes to that field
- so Binaryen can make it immutable

## Shape 3: write-only field removal still preserves the write's side effects

Before, conceptually:

```wat
(module
  (type $S (struct (field (mut i32))))
  (func (param $s (ref $S))
    (struct.set $S 0
      (local.get $s)
      (call $side-effect))))
```

After, conceptually:

```wat
(module
  (type $S (struct))
  (func (param $s (ref $S))
    (drop
      (ref.as_non_null
        (block (result (ref $S))
          (drop (call $side-effect))
          (local.get $s))))))
```

Why:

- the field is unread, so it can disappear
- the `struct.set` itself is dead
- but the value's side effects and the ref's null trap must still happen in the right order

So the write vanishes semantically, but its observable sub-effects do not.

## Shape 4: side-effectful removed constructor operands become temps

Before, conceptually:

```wat
(module
  (type $S (struct (field i32) (field f64) (field anyref)))
  (func
    (drop
      (struct.new $S
        (call $keep)
        (call $remove-one)
        (call $remove-two)))))
```

After, conceptually:

```wat
(module
  (type $S (struct (field i32)))
  (func
    (local $tmp0 f64)
    (local $tmp1 anyref)
    (drop
      (block (result (ref $S))
        (local.set $tmp0 (call $remove-one))
        (local.set $tmp1 (call $remove-two))
        (struct.new $S
          (call $keep))))))
```

Why:

- removed operands can still have side effects
- Binaryen localizes them before dropping or reordering the constructor operand list
- later passes may clean up the now-obviously-dead temps

## Shape 5: immutable versus mutable globals change localization needs

Before, conceptually:

```wat
(module
  (global $imm i32 (i32.const 1))
  (global $mut (mut i32) (i32.const 2))
  (type $S (struct (field i32) (field f64)))
  ...)
```

Two useful subfamilies:

- if a removed constructor operand is `global.get $imm`, Binaryen may keep it in place because immutable global reads do not interact with later effects here
- if the removed operand is `global.get $mut`, Binaryen localizes it because later calls could in theory observe or change that mutable global

This is one of the best examples of the pass being effect-aware without doing full CFG analysis.

## Shape 6: unread parent field used only in a child triggers reorder-then-remove

Before, conceptually:

```wat
(module
  (type $Parent (sub (struct (field i32) (field i64))))
  (type $Child (sub $Parent (struct (field i32) (field i64) (field anyref))))
  (func (param $p (ref $Parent)) (param $c (ref $Child))
    (drop (struct.get $Parent 1 (local.get $p)))
    (drop (struct.get $Child 0 (local.get $c)))
    (drop (struct.get $Child 2 (local.get $c)))))
```

After, conceptually:

```wat
(module
  (type $Parent (sub (struct (field i64))))
  (type $Child (sub $Parent (struct (field i64) (field i32) (field anyref))))
  ...)
```

Why:

- the parent's field `0` is only needed in the child
- Binaryen reorders the parent so the kept field becomes the prefix
- the dead parent field falls off the end
- the child keeps or re-appends the still-needed field after the parent's new prefix

This is the signature shape of `gto` as a subtype-layout pass.

## Shape 7: parent writes block parent removal

Before, conceptually:

```wat
(module
  (type $Parent (sub (struct (field (mut i32)) (field (mut f32)))))
  (type $Child (sub $Parent (struct (field (mut i32)) (field (mut f32)) (field anyref))))
  (func (param $p (ref $Parent)) (param $c (ref $Child))
    (struct.set $Parent 1 (local.get $p) (f32.const 0))
    (drop (struct.get $Parent 0 (local.get $p)))
    (drop (struct.get $Child 2 (local.get $c)))))
```

After, conceptually:

```wat
(module
  (type $Parent (sub (struct (field i32) (field (mut f32)))))
  (type $Child (sub $Parent (struct (field i32) (field (mut f32)) (field anyref))))
  ...)
```

Why:

- the write to the parent's second field means that field cannot disappear there
- but unrelated unread or no-write fields may still optimize

This is a good negative counterpart to the previous reorder/remove positive.

## Shape 8: public parent freezes inherited shared fields

Before, conceptually:

```wat
(module
  (type $Parent (sub (struct (field (mut i32)))))
  (type $Child (sub $Parent (struct (field (mut i32)))))
  (global $g (ref $Parent) (struct.new_default $Parent))
  (export "g" (global $g))
  (func (drop (struct.new_default $Child))))
```

After, conceptually:

```wat
(module
  (type $Parent (sub (struct (field (mut i32)))))
  (type $Child (sub $Parent (struct (field (mut i32)))))
  ...)
```

Why:

- the exported global makes the parent public
- public types are frozen
- the child's inherited shared field must remain compatible with that public parent layout

So the child does not earn an inherited-field optimization just because it is private.

## Shape 9: child-only field can still optimize under a public parent

Before, conceptually:

```wat
(module
  (type $Super (sub (struct)))
  (type $Sub (sub $Super (struct (field (mut stringref)))))
  (global $g (ref $Super) (struct.new_default $Super))
  (export "g" (global $g))
  (func
    (drop
      (struct.get $Sub 0
        (struct.new $Sub (string.const "foo"))))) )
```

After, conceptually:

```wat
(module
  (type $Super (sub (struct)))
  (type $Sub (sub $Super (struct (field stringref))))
  ...)
```

Why:

- the public parent has no such field
- only the child owns this suffix slot
- so the child-only field can still become immutable

This is the positive counterpart to the previous public-parent bailout.

## Shape 10: RMW and cmpxchg keep a field alive and mutable

Before, conceptually:

```wat
(module
  (type $A (shared (struct (field (mut i32)))))
  (func (param $a (ref $A))
    (drop
      (struct.atomic.rmw.add $A 0
        (local.get $a)
        (i32.const 0)))))
```

After, conceptually:

```wat
(module
  (type $A (shared (struct (field (mut i32)))))
  (func (param $a (ref $A))
    (drop
      (struct.atomic.rmw.add $A 0
        (local.get $a)
        (i32.const 0)))))
```

Why:

- atomic RMW counts as both read and write
- a field used that way cannot disappear
- and it cannot become immutable either

The same rule applies to atomic cmpxchg.

## Shape 11: earlier sibling removal still reindexes surviving atomic ops

Before, conceptually:

```wat
(module
  (type $S (shared (struct (field (mut i64)) (field (mut i32)))))
  (func (param $s (ref $S))
    (drop (struct.atomic.rmw.and $S 1 (local.get $s) (i32.const 1)))))
```

After, conceptually:

```wat
(module
  (type $S (shared (struct (field (mut i32)))))
  (func (param $s (ref $S))
    (drop (struct.atomic.rmw.and $S 0 (local.get $s) (i32.const 1)))))
```

Why:

- the dead first field disappears
- surviving atomic users must be reindexed, not left pointing at the old slot

## Shape 12: JS-exposed descriptor prototype field stays alive

Before, conceptually:

```wat
(module
  (rec
    (type $Struct (descriptor $Desc) (struct))
    (type $Desc (describes $Struct) (struct (field externref))))
  (func $externalize
    (local $s (ref null $Struct))
    (drop (extern.convert_any (local.get $s)))))
```

After, conceptually:

```wat
(module
  (rec
    (type $Struct (descriptor $Desc) (struct))
    (type $Desc (describes $Struct) (struct (field externref))))
  ...)
```

Why:

- `extern.convert_any` can expose the descriptor to JS
- JS may observe descriptor field `0` as a prototype
- so Binaryen treats that field as live even if ordinary wasm code never reads it

## Shape 13: non-prototype descriptor field still disappears

Before, conceptually:

```wat
(module
  (rec
    (type $Struct (descriptor $Desc) (struct))
    (type $Desc (describes $Struct) (struct (field stringref))))
  (func $externalize
    (local $s (ref null $Struct))
    (drop (extern.convert_any (local.get $s)))))
```

After, conceptually:

```wat
(module
  (rec
    (type $Struct (descriptor $Desc) (struct))
    (type $Desc (describes $Struct) (struct)))
  ...)
```

Why:

- strings are not treated as JS prototype carriers here
- so the descriptor field can still disappear

The same general negative family holds for `anyref` and `nullexternref` descriptor fields.

## Shape 14: removed module-initializer trap becomes a synthetic global

Before, conceptually:

```wat
(module
  (rec
    (type $Struct (descriptor $Desc) (struct (field i32)))
    (type $Desc (describes $Struct) (struct)))
  (type $Pair (struct (field (ref $Struct)) (field (ref $Struct))))
  (global $g (ref $Pair)
    (struct.new $Pair
      (struct.new_desc $Struct (i32.const 0) (struct.new $Desc))
      (struct.new_desc $Struct (i32.const 1) (ref.null none)))))
```

After, conceptually:

```wat
(module
  ...
  (global $g (ref $Pair) (struct.new_default $Pair))
  (global $gto-removed-0 (ref (exact $Struct))
    (struct.new_desc $Struct
      (i32.const 1)
      (ref.null none))))
```

Why:

- the removed initializer child might still trap during instantiation
- module-level code cannot use locals to preserve that behavior
- so Binaryen emits a fresh global to keep the trap alive

## Shape 15: `-O` closed world gains later wins that open world does not

Before, conceptually:

```wat
(module
  (type $S (sub (struct (field (mut funcref)) (field (mut i32)))))
  (global $g (ref $S)
    (struct.new $S
      (ref.func $helper)
      (i32.const 100)))
  (func $helper
    (struct.set $S 1
      (global.get $g)
      (i32.const 200)))
  (func $main (result i32)
    (struct.get $S 1 (global.get $g))))
```

Closed-world `-O`, conceptually:

```wat
(module
  ;; after gto + later global cleanup + later cfp
  (func $main (result i32)
    (i32.const 100)))
```

Open-world `-O`, conceptually:

```wat
(module
  ;; no gto in the default path here
  (func $main (result i32)
    (struct.get $S 1 (global.get $g))))
```

Why:

- in closed world, `gto` removes the dead `funcref` field
- that can delete the only `ref.func` edge keeping `$helper` alive
- later passes then clean up more aggressively

This is the best shape for remembering that scheduler placement is part of the meaning.

## Bottom line

The main shape lesson of `gto` is:

- **a field can disappear or become immutable only if Binaryen can still preserve subtype layout, public boundaries, JS-exposed descriptor behavior, and trap order.**

That is what future port work must match.

## Sources

- [`../../../raw/binaryen/2026-04-24-global-type-optimization-primary-sources.md`](../../../raw/binaryen/2026-04-24-global-type-optimization-primary-sources.md)
- [`../../../raw/research/0306-2026-04-24-global-type-optimization-primary-sources-and-starshine-followup.md`](../../../raw/research/0306-2026-04-24-global-type-optimization-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0153-2026-04-21-global-type-optimization-binaryen-research.md`](../../../raw/research/0153-2026-04-21-global-type-optimization-binaryen-research.md)
- Binaryen `version_129`:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/GlobalTypeOptimization.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/struct-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/js-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/gto-removals.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/gto-removals-rmw.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/gto-mutability.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/gto-desc.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/gto-jsinterop.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/gto-shared-jsinterop.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/gto-strings-jsinterop.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/gto_and_cfp_in_O.wast>
