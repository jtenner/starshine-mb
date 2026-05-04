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
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../simplify-locals/index.md
  - ../simplify-locals-notee-nostructure/index.md
  - ../simplify-locals-nonesting/index.md
---

# `simplify-locals-nostructure` Variant Surface

This page focuses on the easiest part of Binaryen’s locals family to misunderstand:

- what “no structure” actually turns off
- what it surprisingly leaves on
- and how that differs from the nearby public variants

The reviewed official Binaryen `version_129` release page rechecked on 2026-04-22 showed publish date **2026-04-01**. A focused 2026-05-04 current-`main` source/test recheck did not surface a teaching-relevant drift for this variant surface. See [`../../../raw/binaryen/2026-05-04-simplify-locals-nostructure-current-main-recheck.md`](../../../raw/binaryen/2026-05-04-simplify-locals-nostructure-current-main-recheck.md).

## The whole family in one table

`SimplifyLocals.cpp` exposes five public variants through one shared template.

| Public pass | Template identity | Tee allowed? | Structure rewrites allowed? | Nesting into existing expression positions allowed? |
| --- | --- | --- | --- | --- |
| `simplify-locals` | `SimplifyLocals<true, true, true>` | yes | yes | yes |
| `simplify-locals-notee` | `SimplifyLocals<false, true, true>` | no | yes | yes |
| `simplify-locals-nostructure` | `SimplifyLocals<true, false, true>` | yes | no | yes |
| `simplify-locals-notee-nostructure` | `SimplifyLocals<false, false, true>` | no | no | yes |
| `simplify-locals-nonesting` | `SimplifyLocals<false, false, false>` | no | no | no |

That table is the real semantic surface.

## First correction: “no structure” does **not** mean “no tee”

The `contrast` test is the easiest proof.

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

So the pass still tees.

The real rule is narrower:

- the pass does not create new block / `if` / loop result structure
- it still may create a tee for the first use of a multi-use local

## Second correction: “no structure” does **not** mean “no nesting”

The template identity is `SimplifyLocals<true, false, true>`.

That last `true` means:

- nesting into existing expression positions is still allowed

So Binaryen may still turn:

```wat
(local.set $y
  (if (result i32) ...))
(drop (local.get $y))
```

into:

```wat
(nop)
(drop
  (if (result i32) ...))
```

That is still a real sink into an existing nested value position.

What “no structure” disables is **new** structure-building rewrites, not all nested use sites.

## Third correction: “no structure” does **not** mean “skip the late cleanup”

After the main sink loop, no-structure still runs two late phases:

1. equivalent-get canonicalization
2. final dead-set cleanup via `UnneededSetRemover`

So this pass still does more than:

- sink one set into one get

It also:

- rewrites `local.get`s toward a better equivalent local
- erases zero-use and same-value local traffic afterward

## What “structure rewrites” means here

The disabled helper family is:

- `optimizeLoopReturn(...)`
- `optimizeBlockReturn(...)`
- `optimizeIfElseReturn(...)`
- `optimizeIfReturn(...)`

Those are the helpers that create new value-carrying control structure out of local traffic.

So in no-structure mode, Binaryen deliberately refuses to create new:

- block result carriers
- `if (result ...)` carriers derived from local sets
- loop result carriers
- one-armed `if` speculative else-side `local.get`s

That is the exact meaning of “no structure” in this pass family.

## Concrete contrast 1: no-structure versus no-tee-no-structure

Use the same multi-use local input again.

### `simplify-locals-nostructure`

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

### `simplify-locals-notee-nostructure`

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

So the no-tee variant really is stricter.
The no-structure variant is not just an alias for it.

## Concrete contrast 2: no-structure versus full `simplify-locals`

The same `contrast` test also shows the structure boundary.

Before:

```wat
(if (i32.const 6)
  (then
    (local.set $a (i32.const 7)))
  (else
    (local.set $a (i32.const 8))))
(drop (local.get $a))
```

### `simplify-locals-nostructure`

It keeps the arm-local sets and the later `drop(local.get $a)`:

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

### full `simplify-locals`

It may convert the same family into an `if (result i32)` plus one outer use:

```wat
(nop)
(drop
  (if (result i32)
    (i32.const 6)
    (then
      (nop)
      (i32.const 7))
    (else
      (nop)
      (i32.const 8))))
```

That is the practical “structure” difference.

## Concrete contrast 3: no-structure still canonicalizes gets, but keeps some copy sets

The late equivalent-local phase has two related but different behaviors:

- canonicalize `local.get`s toward a better equivalent local
- optionally remove redundant equivalent copy sets

In no-structure mode:

- get canonicalization is still enabled
- equivalent-set deletion is disabled

So the right mental model is:

- “make readers more uniform now”
- “leave some structural copy carriers for the later full pass”

That is a subtle but important upstream choice.

## Concrete contrast 4: no-nesting is a different promise entirely

`SimplifyLocals<false, false, false>` is the only variant that promises to preserve flatness.

That means:

- no tee
- no structure rewrites
- no nesting into existing expression positions either

So if someone reads “no structure” as “preserves flatness,” they are really thinking of the nonesting variant instead.

## Why Binaryen wants the no-structure pass early

The no-DWARF scheduler puts `simplify-locals-nostructure` before:

- `vacuum`
- the first `reorder-locals`
- the later GC/local cleanup cluster
- the later full `simplify-locals`

That placement makes sense if you read the variant boundary literally:

- do cheap local sink / tee cleanup now
- do not commit to structure-return rewrites yet
- let later passes simplify and reorder locals more honestly
- finish the structure-sensitive local cleanup only later

So the early and late simplify-locals passes are meant to be different tools, not duplicate work.

## Local Starshine planning consequence

Current Starshine still does **not** implement this variant, but the local planning story is already precise enough to matter:

- `src/passes/optimize.mbt` registers upstream spelling `simplify-locals-nostructure` as active and keeps local spelling `simplify-locals-no-structure` as an alias
- the same file now lets `tuple_optimization_exact_slot_prereqs_ready()` see the no-structure neighbor as active while keeping public presets conservative
- `src/passes/optimize_test.mbt` locks that honesty rule in place with the conservative-preset regression
- [`./starshine-strategy.md`](./starshine-strategy.md) now ties that blocker story to the practical MoonBit landing zone in `src/passes/simplify_locals.mbt`, `src/passes/reorder_locals.mbt`, `src/passes/pass_manager_wbtest.mbt`, and `src/cmd/cmd_wbtest.mbt`

So the variant surface is now linked directly to the local port-planning story instead of floating as an upstream-only note.

## A simple rule of thumb

When you see `simplify-locals-nostructure`, ask these questions in order:

1. Can it still sink a set into a later use?
   - yes
2. Can it still create a tee on later cycles?
   - yes
3. Can it still nest into an existing consumer expression?
   - yes
4. Can it invent a new block / `if` / loop return value shape?
   - no
5. Can it still canonicalize equivalent gets and remove dead sets later?
   - yes

If you keep those five answers straight, the variant surface becomes much easier to reason about.

## Sources

- [`../../../raw/binaryen/2026-04-25-simplify-locals-nostructure-current-main-and-test-map.md`](../../../raw/binaryen/2026-04-25-simplify-locals-nostructure-current-main-and-test-map.md)
- [`../../../raw/binaryen/2026-04-22-simplify-locals-nostructure-primary-sources.md`](../../../raw/binaryen/2026-04-22-simplify-locals-nostructure-primary-sources.md)
- [`../../../raw/research/0368-2026-04-25-simplify-locals-nostructure-current-main-and-test-map.md`](../../../raw/research/0368-2026-04-25-simplify-locals-nostructure-current-main-and-test-map.md)
- [`../../../raw/research/0263-2026-04-22-simplify-locals-nostructure-primary-sources-and-starshine-followup.md`](../../../raw/research/0263-2026-04-22-simplify-locals-nostructure-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0117-2026-04-20-simplify-locals-nostructure-binaryen-research.md`](../../../raw/research/0117-2026-04-20-simplify-locals-nostructure-binaryen-research.md)
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SimplifyLocals.cpp>
- Binaryen `version_129` dedicated tests:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nostructure.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nostructure.txt>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-notee-nostructure.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-notee-nostructure.txt>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nonesting.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nonesting.txt>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals.txt>
