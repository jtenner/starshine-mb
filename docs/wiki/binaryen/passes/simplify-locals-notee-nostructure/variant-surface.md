---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-04-25-simplify-locals-notee-nostructure-primary-sources.md
  - ../../../raw/research/0333-2026-04-25-simplify-locals-notee-nostructure-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0129-2026-04-20-simplify-locals-notee-nostructure-binaryen-research.md
  - ../../../raw/binaryen/2026-05-05-simplify-locals-notee-nostructure-current-main-recheck.md
  - ../../../raw/research/0489-2026-05-05-simplify-locals-notee-nostructure-current-main-recheck.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../simplify-locals-nostructure/index.md
  - ../flatten/index.md
  - ../local-cse/index.md
---

# `simplify-locals-notee-nostructure` Variant Surface

Use this page with the source manifest in [`../../../raw/binaryen/2026-04-25-simplify-locals-notee-nostructure-primary-sources.md`](../../../raw/binaryen/2026-04-25-simplify-locals-notee-nostructure-primary-sources.md) and the owner/test map in [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md).
A 2026-05-05 current-main recheck left the variant identity unchanged: this is still the `SimplifyLocals<false, false, true>` sibling, not the non-nesting sibling.

This page focuses on the easiest part of Binaryen’s locals family to misunderstand:

- what “no tee” and “no structure” actually turn off
- what surprisingly stays enabled
- why this is not the same as `simplify-locals-nonesting`
- and why Binaryen uses this exact variant after `flatten`

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

## First correction: “no tee” does **not** mean “do almost nothing”

The dedicated `contrast` test proves one obvious visible boundary:

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

After `simplify-locals-notee-nostructure`:

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

So the pass does **not** tee the first use.

But that does **not** mean it is inert.

The same implementation still allows:

- direct single-use sink rewrites
- dead-overwrite cleanup
- equivalent-`get` canonicalization
- dead-set cleanup

The real rule is narrower:

- no new tee is created to preserve a value for later uses

## Second correction: “no tee + no structure” does **not** mean “no nesting”

The template identity is `SimplifyLocals<false, false, true>`.

That last `true` matters.

It means Binaryen may still sink a single-use local into an already-existing consumer expression.

For example, conceptually:

```wat
(local.set $tmp
  (i32.add
    (local.get $a)
    (i32.const 1)))
(drop
  (local.get $tmp))
```

can still become:

```wat
(nop)
(drop
  (i32.add
    (local.get $a)
    (i32.const 1)))
```

No new structure was invented.

But there is still more nesting than before.

That is why this pass is **not** the same as `simplify-locals-nonesting`.

## Third correction: “runs after flatten” does **not** mean “preserves Flat IR”

This is the most counterintuitive fact in the whole dossier.

Because the pass runs immediately after `flatten`, it is easy to assume it must preserve full Flat IR.

But the template flags say otherwise:

- `allowNesting = true`

So a faithful reading is:

- Binaryen flattens first
- then simplifies locals a little
- but it does **not** insist on keeping the function perfectly flat afterward

If a future Starshine port wants a post-pass “still fully flat” contract, that would be a deliberate divergence, not a hidden upstream rule.

## Concrete contrast 1: no-tee-no-structure versus no-structure

Use the same multi-use local input again.

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

So the no-tee-no-structure variant really is stricter.
The no-structure variant is not just an alias for it.

## Concrete contrast 2: no-tee-no-structure versus full `simplify-locals`

The same `contrast` family also shows the structure boundary.

Before:

```wat
(if (i32.const 6)
  (then
    (local.set $a (i32.const 7)))
  (else
    (local.set $a (i32.const 8))))
(drop (local.get $a))
```

### `simplify-locals-notee-nostructure`

It keeps the arm-local sets and the later use:

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

It may convert the same family into an `if (result i32)` plus one outer use.

So the full pass finishes a structure-building cleanup family that this aggressive variant intentionally leaves behind.

## Concrete contrast 3: no-tee-no-structure versus no-nesting

The easiest difference here is not about multi-use locals.
It is about whether a direct one-use sink can still enter an existing consumer position.

### `simplify-locals-notee-nostructure`

- may still replace `drop(local.get $tmp)` with `drop(value)`
- may still replace another ordinary read with the stored value directly

### `simplify-locals-nonesting`

- refuses any sink that would create a nested use position
- has special fallback logic for copy chains instead of ordinary sinking

So `nonesting` is the variant that really tries to preserve flatness.
`notee-nostructure` is not.

## What “no structure” means exactly here

The disabled helper family is:

- `optimizeLoopReturn(...)`
- `optimizeBlockReturn(...)`
- `optimizeIfElseReturn(...)`
- `optimizeIfReturn(...)`

Those are the helpers that create new value-carrying control structure out of local traffic.

So in this variant, Binaryen deliberately refuses to create new:

- block result carriers
- `if (result ...)` carriers derived from local sets
- loop result carriers
- speculative one-armed `if` else-side `local.get`s

That is the exact meaning of “no structure” in this pass family.

## What “no tee” means exactly here

The shared source still contains a tee-creation branch in `optimizeLocalGet(...)`.

But `canSink(...)` prevents multi-use locals from ever becoming sinkable when `allowTee = false`.

So the operational meaning is:

- no new tee is created by the main sink loop
- multi-use locals stay as explicit local traffic
- only one-use locals get the direct sink treatment

That is sharper than the CLI name alone suggests.

## One more subtlety: existing tees are not sacred

“no tee” does **not** mean “leave every existing `local.tee` alone forever.”

The late `UnneededSetRemover` still removes dead or same-value sets, including tee-shaped ones.

So the real rule is:

- do not create new tees as part of sinking
- but still clean up useless existing tee traffic later if it becomes dead

## Why Binaryen chose this exact aggressive variant after `flatten`

The comment in `pass.cpp` says:

- `local-cse` is particularly useful after `flatten`
- but some amount of simplify-locals needs to happen first because `flatten` adds many redundant locals

This variant is a good fit for that job because it removes the simplest carrier noise while staying conservative about two things that could distort the next phase:

- no new tees
- no new value-carrying control structure

That combination leaves the function easier for `local-cse` to understand without turning the prelude into full late locals cleanup.

## Practical beginner summary

If you need a short memory hook, use this one:

- `simplify-locals-notee-nostructure` = “remove easy flatten temps, but don’t invent tees and don’t invent new result structure.”

Then remember the one caveat that the name hides:

- it may still create some ordinary nesting because it is **not** the nonesting variant

## Sources

- [`../../../raw/binaryen/2026-04-25-simplify-locals-notee-nostructure-primary-sources.md`](../../../raw/binaryen/2026-04-25-simplify-locals-notee-nostructure-primary-sources.md)
- [`../../../raw/research/0333-2026-04-25-simplify-locals-notee-nostructure-primary-sources-and-starshine-followup.md`](../../../raw/research/0333-2026-04-25-simplify-locals-notee-nostructure-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0129-2026-04-20-simplify-locals-notee-nostructure-binaryen-research.md`](../../../raw/research/0129-2026-04-20-simplify-locals-notee-nostructure-binaryen-research.md)
- [`../../../raw/binaryen/2026-05-05-simplify-locals-notee-nostructure-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-simplify-locals-notee-nostructure-current-main-recheck.md)
- [`../../../raw/research/0489-2026-05-05-simplify-locals-notee-nostructure-current-main-recheck.md`](../../../raw/research/0489-2026-05-05-simplify-locals-notee-nostructure-current-main-recheck.md)
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SimplifyLocals.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-notee-nostructure.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-notee-nostructure.txt>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nostructure.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nostructure.txt>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nonesting.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nonesting.txt>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals.txt>
