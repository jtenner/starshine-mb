---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-flatten-current-main-implementation-test-map.md
  - ../../../raw/binaryen/2026-04-23-flatten-primary-sources.md
  - ../../../raw/research/0360-2026-04-25-flatten-current-main-and-test-map.md
  - ../../../raw/research/0267-2026-04-23-flatten-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0127-2026-04-20-flatten-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
---

# `flatten`: Flat IR contract and preludes

## Why this page exists

The easiest way to misunderstand `flatten` is to think it simply “introduces locals for nested values.”

That is too vague.

The real pass is defined by two things together:

- the exact Flat IR contract in `src/ir/flat.h`
- the exact `preludes` movement algorithm in `src/passes/Flatten.cpp`

The 2026-04-25 current-main recheck in [`../../../raw/binaryen/2026-04-25-flatten-current-main-implementation-test-map.md`](../../../raw/binaryen/2026-04-25-flatten-current-main-implementation-test-map.md) found no teaching-relevant drift in those two surfaces from the tagged `version_129` dossier.

This page focuses on those two pieces.

## The formal Flat IR contract

`flat.h` defines Flat IR as four exact AST properties.

## 1. Ordinary operands must be simple

For ordinary instructions, children must already be one of:

- `local.get`
- constant expression
- `unreachable`
- `ref.as_non_null`

That means flatten is trying to eliminate children like:

- nested arithmetic trees
- nested calls
- nested `block (result ...)`
- nested `if (result ...)`
- nested `local.tee`
- nested branch payload producers

by computing them earlier and then reading a local instead.

## 2. Control flow may not return values

After flattening, these structures must no longer flow a value directly:

- `block`
- `loop`
- `if`
- `try`

The function body also must not remain a concrete value expression by itself.

This is why the pass does not just flatten *children*; it also rewrites the control nodes themselves.

## 3. `local.tee` is forbidden

In flat IR:

- `local.set` is the only allowed setting operation in expression positions
- `local.tee` must be eliminated into explicit earlier set plus later get behavior

## 4. `local.set` cannot directly hold control flow

Even if some control-flow child is otherwise type-correct, it is still too structured to sit directly under `local.set` in Flat IR.

That rule is easy to miss, but it is one reason flatten has to use placeholder `unreachable` nodes in some rewritten positions.

## Important nuance: `ref.as_non_null`

`flat.h` explicitly allows nested `ref.as_non_null`.

That is a special-case rule, not a generic exception for any non-null producer.

At the same time:

- `Flatten.cpp` still has an open non-nullability TODO
- shipped tests prove some non-null families already work

So the honest summary is:

- some non-null cases are already allowed
- some remain unfinished
- the exact supported set is narrower than “all non-null values” but broader than “none of them”

## The `preludes` model

The most important implementation idea in `Flatten.cpp` is the `preludes` map.

A prelude is:

- code that must execute immediately before a specific expression

That code is usually:

- a `local.set` computing a formerly nested value
- a rewritten control-flow expression that now runs earlier
- a real control effect such as an `unreachable`-typed exit that cannot stay nested in place anymore

## Why preludes exist

Consider a nested expression like:

```wat
(i32.add
  (block (result i32)
    (i32.const 1)
  )
  (i32.const 2)
)
```

Flat IR does not allow that `block (result i32)` child.

Binaryen therefore needs to turn it into something like:

```wat
(block
  (local.set $tmp
    (i32.const 1)
  )
)
(i32.add
  (local.get $tmp)
  (i32.const 2)
)
```

The block part is the prelude. The `local.get` is the flattened replacement child.

## The migration rule

After Binaryen builds `ourPreludes` for the current node, it decides where they can move.

### Case 1: non-control parent

If the parent exists and is **not** a control-flow structure:

- Binaryen migrates the current node’s preludes upward into the parent’s prelude list

Why that is safe:

- the parent is just another ordinary expression
- the prelude still executes immediately before the parent uses the child result

### Case 2: control-flow parent

If the parent is a control-flow structure, or there is no parent:

- the preludes stay attached to the current expression
- the control-flow parent will later place them explicitly in the right region

This is why control-flow nodes need custom logic.

They are where placement stops being purely local.

## Why this preserves evaluation order

The key source-derived reason flatten preserves side-effect order is:

- a nested effectful computation is not deleted
- it is merely moved into a prelude that executes immediately before the use site (or before the nearest enclosing control node that can place it correctly)

So a good mental model is:

- flatten converts stack-style nesting into statement-style sequencing
- it does not change the intended order of observable work

## Why flatten creates so many locals

Flatten is allowed to be wasteful.

That is deliberate.

Its job is:

- normalize shape first
- let later passes such as `simplify-locals-notee-nostructure` and `local-cse` clean up the extra traffic later

This is why `pass.cpp` immediately schedules those neighbors after `flatten` in aggressive mode.

## Named target temps for carried branch values

The second key implementation map is `breakTemps`.

This map stores:

- one temp local per named branch target

The purpose is simple:

- once Flat IR forbids branch instructions from carrying arbitrary nested value trees directly, those values need somewhere explicit to live

So flatten rewrites them through locals keyed to the target name.

## Why `br_if` is trickier than `br`

A plain `br` either exits or it does not matter what happens next.

A `br_if` is different:

- if the condition is false, its carried value may still matter to the surrounding expression context

`Flatten.cpp` documents a real mismatch case where:

- the target block expects one type
- the inner flowing-out context expects another type

When that happens, Binaryen may need:

- one temp for the target block’s carried type
- another temp for the value that can still flow outward when the branch is not taken

That double-temp rule is one of the most important beginner-unfriendly details in the whole pass.

## Why `switch` / `br_table` duplicates work

For switch values, flatten first stores the carried value once and then copies it into all unique target temps.

That may look redundant, but it expresses the right truth:

- before the branch fires, Binaryen does not know which label will be taken
- so each possible target’s carried-value channel must be made explicit

Again, flatten prefers a simple explicit representation over a clever compact one.

## The placeholder `unreachable` rule

One surprising part of `Flatten.cpp` is the generic rule for expressions that become `Type::unreachable`.

Binaryen does **not** just delete them.

Instead:

- it keeps the real expression in preludes
- it leaves a placeholder `unreachable` in the original spot

Why that matters:

- the original control effect still happens in the right order
- but the remaining AST position stays valid under Flat IR’s structural restrictions

This is especially important when a formerly nested control effect can no longer sit directly where it used to.

## Function-body repair

Flat IR also disallows the function body itself from being a concrete value expression.

So in `visitFunction(...)`, Binaryen:

- wraps a still-concrete body in `return`
- then attaches any remaining body preludes

This is why even a simple function body result can become extra local traffic after flattening.

## EH pop repair is part of the real contract

`Flatten.cpp` finishes functions with:

- `EHUtils::handleBlockNestedPops(...)`

That is not optional cleanup polish.

The source comment says flatten can create blocks inside `catch`, which invalidates where `pop` is allowed to appear.

So the real flatten contract includes:

- flattening first
- then repairing the EH stack discipline after the structural rewrite

A future port that skips this step would not be faithfully implementing the source contract.

## Unsupported and surprising boundaries

## `BrOn*` and `TryTable`

In `version_129`, Binaryen does not merely decline to optimize those.

It hard-fails with:

- `Unsupported instruction for Flatten`

That is a major boundary and should be documented explicitly in any future port plan.

## Selective non-null support

The source set is intentionally mixed here:

- `flat.h` treats `ref.as_non_null` specially
- `Flatten.cpp` still has a non-nullability TODO
- tests prove at least some non-null families work

So if a future Starshine port hits a non-null flatten case, the right question is not:

- “does flatten support non-null?”

The right question is:

- “is this one of the selective non-null families Binaryen already handles, or one of the families the TODO still covers?”

## Bottom line

The cleanest summary is:

- Flat IR is a very specific contract
- preludes are the mechanism that makes that contract implementable without reordering work
- `breakTemps` are the mechanism that makes carried branch values explicit
- placeholder `unreachable` plus EH pop fixup are part of the real correctness story
- and that is why flatten is much more than a generic “remove nesting” pass
