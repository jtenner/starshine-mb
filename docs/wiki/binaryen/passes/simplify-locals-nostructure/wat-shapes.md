---
kind: concept
status: supported
last_reviewed: 2026-05-04
sources:
  - ../../../raw/binaryen/2026-05-04-simplify-locals-nostructure-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-25-simplify-locals-nostructure-current-main-and-test-map.md
  - ../../../raw/binaryen/2026-04-22-simplify-locals-nostructure-primary-sources.md
  - ../../../raw/research/0433-2026-05-04-simplify-locals-nostructure-current-main-recheck.md
  - ../../../raw/research/0368-2026-04-25-simplify-locals-nostructure-current-main-and-test-map.md
  - ../../../raw/research/0263-2026-04-22-simplify-locals-nostructure-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0117-2026-04-20-simplify-locals-nostructure-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./variant-surface.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../simplify-locals/index.md
---

# `simplify-locals-nostructure` WAT Shapes

This page is the beginner-friendly shape catalog for Binaryen’s `simplify-locals-nostructure` pass.

The reviewed official Binaryen `version_129` release page rechecked on 2026-04-22 showed publish date **2026-04-01**. A focused 2026-05-04 current-`main` source/test recheck did not surface a teaching-relevant drift for these shape families. See [`../../../raw/binaryen/2026-05-04-simplify-locals-nostructure-current-main-recheck.md`](../../../raw/binaryen/2026-05-04-simplify-locals-nostructure-current-main-recheck.md).

## Read this page with one mental model

Binaryen is trying to make local traffic more direct **without** inventing new block / `if` / loop return values yet.

It is not asking:

- “how do I finish all local cleanup right now?”

It is asking:

- “which local sets can already move into real use sites, which ones need a tee later, and which leftover local writes are now dead?”

That is why many examples below are about:

- direct sink into an existing use
- tee creation on later cycles
- overwrite cleanup
- preserved structure
- explicit bailout families

## Quick glossary

- **sink**: replace a later `local.get` with the value from an earlier `local.set`
- **tee sink**: replace the first read with a `local.tee` so later reads still see the local
- **origin set**: the old `local.set` site that becomes `nop`
- **structure rewrite**: turning arm-local / block-local sets into a new control-flow result value
- **equivalent get**: a `local.get` that can be redirected to another local known to carry the same value

## Shape 1: a multi-use local can still tee in no-structure mode

Before:

```wat
(local.set $x
  (i32.const 1))
(if
  (local.get $x)
  (then (nop)))
(if
  (local.get $x)
  (then (nop)))
```

After `simplify-locals-nostructure`:

```wat
(nop)
(if
  (local.tee $x
    (i32.const 1))
  (then (nop)))
(if
  (local.get $x)
  (then (nop)))
```

Why it rewrites:

- the first cycle does not tee yet
- a later cycle sees the same local still has multiple uses
- teeing is enabled in this variant
- so the first use becomes a `local.tee`

This is the easiest visible proof that “no-structure” does not mean “no tee.”

## Shape 2: a single-use local can sink into an existing value consumer

Before:

```wat
(local.set $y
  (if (result i32)
    (i32.const 2)
    (then (i32.const 3))
    (else (i32.const 4))))
(drop
  (local.get $y))
```

After:

```wat
(nop)
(drop
  (if (result i32)
    (i32.const 2)
    (then (i32.const 3))
    (else (i32.const 4))))
```

Why it rewrites:

- the local has one real use
- the consumer already exists
- the pass can sink into that existing nested value position
- no new structure had to be invented

This is why the pass still allows nesting into existing expression positions.

## Shape 3: block-valued locals can also sink into an existing consumer

Before:

```wat
(local.set $z
  (block (result i32)
    (i32.const 5)))
(drop
  (local.get $z))
```

After:

```wat
(nop)
(drop
  (block (result i32)
    (i32.const 5)))
```

Why it rewrites:

- again, this is a sink into an already-existing consumer
- it does not create a new block return value shape
- it only removes the unnecessary local carrier

## Shape 4: overwritten pending sets become dead

Conceptual before:

```wat
(local.set $x
  (call $compute_a))
(local.set $x
  (call $compute_b))
(drop
  (local.get $x))
```

Conceptual after:

```wat
(drop
  (call $compute_a))
(nop)
(drop
  (call $compute_b))
```

What matters here:

- the first write to `$x` is overwritten before any real read
- Binaryen preserves the first value’s side effects as `drop(...)`
- then it continues with the newer write as the meaningful one

This is one reason the pass is more than a set/get peephole.

## Shape 5: `drop(tee(...))` is folded back to `set`

Conceptual intermediate shape:

```wat
(drop
  (local.tee $x
    (i32.const 1)))
```

After cleanup:

```wat
(local.set $x
  (i32.const 1))
```

Why it matters:

- sinking a multi-use set into the first use can naturally create a dropped tee
- Binaryen immediately removes that noise
- this keeps the no-structure output from accumulating pointless tee wrappers

## Shape 6: local-only effects are not the same as global effects

The dedicated tests contrast two trap-sensitive shapes.

### Global-effect barrier

Before:

```wat
(local.set $var$0
  (i32.trunc_f64_u
    (f64.const -nan:0xfffffffffffc3)))
(f32.store align=1
  (i32.const 22)
  (f32.const 154))
(drop
  (local.get $var$0))
```

After stays the same in the important part.

Why Binaryen keeps it:

- the producer may trap
- the intervening store has global side effects
- reordering could change whether that store happens before the trap

### Local-effect case

Before:

```wat
(local.set $var$0
  (i32.trunc_f64_u
    (f64.const -nan:0xfffffffffffc3)))
(local.set $other
  (i32.const 100))
(drop
  (local.get $var$0))
```

After, conceptually:

```wat
(nop)
(local.set $other
  (i32.const 100))
(drop
  (i32.trunc_f64_u
    (f64.const -nan:0xfffffffffffc3)))
```

Why Binaryen can move it:

- the intervening effect is only local traffic that does not create the same global semantic hazard
- the directional effect rules therefore allow the sink

This is a good beginner reminder that the barrier model is more precise than “any side effect blocks everything.”

## Shape 7: equivalent gets can still canonicalize late

Before:

```wat
(local.set $var$2
  (local.get $var$0))
(i32.store
  (local.get $var$2)
  (i32.const 1))
(f32.load
  (local.get $var$2))
```

After `simplify-locals-nostructure`:

```wat
(nop)
(i32.store
  (local.get $var$0)
  (i32.const 1))
(f32.load
  (local.get $var$0))
```

Why it rewrites:

- the late equivalent-local phase proves `$var$2` is just a copy of `$var$0`
- it canonicalizes the gets back to `$var$0`
- then the final dead-set cleanup can remove the now-unused copy set

This is the clearest “late cleanup still happens here” shape.

## Shape 8: dead unreachable tee traffic can collapse to plain `unreachable`

Before:

```wat
(drop
  (local.tee $x
    (unreachable)))
```

After:

```wat
(unreachable)
```

Why it rewrites:

- the local write is dead
- the tee contributes no needed local state
- the only thing that matters is the underlying unreachable effect

## Shape 9: no new `if` return values are built here

Before:

```wat
(if
  (i32.const 6)
  (then
    (local.set $a (i32.const 7)))
  (else
    (local.set $a (i32.const 8))))
(drop
  (local.get $a))
```

After `simplify-locals-nostructure` stays structurally similar:

```wat
(if
  (i32.const 6)
  (then
    (local.set $a
      (i32.const 7)))
  (else
    (local.set $a
      (i32.const 8))))
(drop
  (local.get $a))
```

Why Binaryen keeps it:

- turning those arm-local sets into an outer `if (result i32)` is a structure rewrite
- this variant deliberately leaves that family for the later full pass

## Shape 10: no new block return values are built here either

Before:

```wat
(block $val
  (if
    (i32.const 10)
    (then
      (block
        (local.set $b (i32.const 11))
        (br $val))))
  (local.set $b (i32.const 12)))
(drop
  (local.get $b))
```

After `simplify-locals-nostructure` stays structurally similar:

```wat
(block $val
  (if
    (i32.const 10)
    (then
      (local.set $b
        (i32.const 11))
      (br $val)))
  (local.set $b
    (i32.const 12)))
(drop
  (local.get $b))
```

Why Binaryen keeps it:

- this would need a new value-carrying block result rewrite
- that rewrite is also behind `allowStructure`

## Shape 11: throwing values do not sink into `try` / `try_table`

Conceptual before:

```wat
(local.set $x
  (call $may_throw))
(try
  ...
  (drop (local.get $x)))
```

Why Binaryen keeps it:

- moving the throwing value into the `try` could change where it is caught
- the pass explicitly forgets such sinkables at `try` / `try_table` boundaries

That is an important bailout family even if the minimal dedicated no-structure test does not isolate it alone.

## Shape 12: same-value local sets are still removed late

Conceptual before:

```wat
(local.set $x
  (local.get $x))
```

Conceptual after:

```wat
(nop)
```

Or, for a dead tee:

```wat
(local.tee $x
  (local.get $x))
```

may collapse to the underlying value when that tee result is dead.

This is handled by `UnneededSetRemover`, not the main sink loop.

## Local Starshine planning consequence

Current Starshine does **not** implement these rewrites yet, but the local planning story is now explicit:

- the local alias spelling is active in `src/passes/optimize.mbt`
- the tuple exact-slot gate sees this pass as active while optimize/shrink preset tests still require ordered-neighborhood proof before scheduling
- the practical local landing zone now lives in [`./starshine-strategy.md`](./starshine-strategy.md), which points future work at `src/passes/simplify_locals.mbt`, `src/passes/reorder_locals.mbt`, `src/passes/pass_manager_wbtest.mbt`, and `src/cmd/cmd_wbtest.mbt`

So these shapes are now tied directly to the future MoonBit port path instead of only to upstream Binaryen.

## A simple rule of thumb

When you look at a possible `simplify-locals-nostructure` candidate, ask these questions in order:

1. Is this just a local carrier around an already-existing consumer?
2. Is the local single-use, or will a later tee be needed?
3. Do the intervening effects allow the move under `orderedBefore` / `orderedAfter`?
4. Are we crossing a `try` / `try_table` with a throwing value?
5. Would the rewrite need a new block / `if` / loop result value shape?

If the answer to the last question is “yes,” expect Binaryen to leave that family for the later full `simplify-locals` pass.

## Source strength note

- The positive and negative shapes above come directly from the dedicated `simplify-locals-nostructure` tests, the nearby variant tests, and the current `version_129` implementation comments.
- The `try` / `try_table` bailout summary is derived from the pass source rather than from a tiny dedicated no-structure-only lit file.

## Sources

- [`../../../raw/binaryen/2026-04-25-simplify-locals-nostructure-current-main-and-test-map.md`](../../../raw/binaryen/2026-04-25-simplify-locals-nostructure-current-main-and-test-map.md)
- [`../../../raw/binaryen/2026-04-22-simplify-locals-nostructure-primary-sources.md`](../../../raw/binaryen/2026-04-22-simplify-locals-nostructure-primary-sources.md)
- [`../../../raw/research/0368-2026-04-25-simplify-locals-nostructure-current-main-and-test-map.md`](../../../raw/research/0368-2026-04-25-simplify-locals-nostructure-current-main-and-test-map.md)
- [`../../../raw/research/0263-2026-04-22-simplify-locals-nostructure-primary-sources-and-starshine-followup.md`](../../../raw/research/0263-2026-04-22-simplify-locals-nostructure-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0117-2026-04-20-simplify-locals-nostructure-binaryen-research.md`](../../../raw/research/0117-2026-04-20-simplify-locals-nostructure-binaryen-research.md)
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SimplifyLocals.cpp>
- Binaryen `version_129` helper sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/equivalent_sets.h>
- Binaryen `version_129` dedicated tests:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nostructure.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nostructure.txt>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-notee-nostructure.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-notee-nostructure.txt>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals.txt>
