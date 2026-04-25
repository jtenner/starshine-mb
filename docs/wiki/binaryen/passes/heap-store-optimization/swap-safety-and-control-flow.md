---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-heap-store-optimization-current-main-code-map.md
  - ../../../raw/binaryen/2026-04-22-heap-store-optimization-primary-sources.md
  - ../../../raw/research/0356-2026-04-25-heap-store-optimization-current-main-code-map.md
  - ../../../raw/research/0133-2026-04-20-heap-store-optimization-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
---

# `heap-store-optimization`: swap safety and control flow

This page focuses on the part of Binaryen `heap-store-optimization` that is easiest to underestimate.

The constructor rewrite itself is small.
The hard part is proving the moved value and the moved `local.set` still execute in a safe order.

## One question drives almost everything

When Binaryen rewrites this:

```wat
(local.set $x
  (struct.new $S OLD0 OLD1 ...))
(struct.set $S FIELD
  (local.get $x)
  NEW)
```

into this:

```wat
(local.set $x
  (struct.new $S OLD0 NEW ...))
(nop)
```

it has changed the order of evaluation.

The key safety question is:

- **can `NEW` happen earlier without changing what executes or what later code sees in `$x`?**

Binaryen answers that with three main checks:

1. effect ordering
2. target-local hazards
3. control-flow / skip-local-set hazards

## Safety check 1: effect ordering

## Later constructor operands are real barriers

Suppose the later field operands have effects:

```wat
(struct.new $S
  A
  B
  C)
```

If we are replacing `A`, then the moved value has to cross `B` and `C`.

Binaryen checks exactly that.

If moving `NEW` ahead of later operands would reorder conflicting effects, the optimization stops.

Practical consequences:

- safe if later operands are effect-free or independent enough
- unsafe if later operands read or write state that conflicts with `NEW`

This is why the test file separates:

- multi-field non-conflict shapes
- multi-field conflict shapes

## The descriptor operand is also a barrier

`StructNew` can carry an optional descriptor operand.

That means the moved value may also need to cross:

- `new_->desc`

Binaryen checks that separately.

This is easy to miss if you only read the simple `struct.new` examples.

## The constructor wrapper itself may matter

Binaryen also runs `ShallowEffectAnalyzer` on the `struct.new` node itself.

That is a subtle but important distinction.

The pass does **not** only care about child effects.
It also cares whether the allocation wrapper's own shallow effects or trap timing would make reordering unsafe.

## Safety check 2: target-local hazards

The next easy mistake is to think:

- if `NEW` is pure enough, just move it

But `NEW` can still be dangerous if it touches the local that stores the fresh ref.

If the moved value:

- reads `$x`
- writes `$x`

Binaryen rejects the rewrite.

Why?

Because after reordering, that read or write would happen at a different time relative to the `local.set` that makes the fresh struct visible.

## Safe mental model

Treat the ref local like a tiny synchronization point for this pass.

If the moved value talks about that local, the proof is much harder, so Binaryen simply bails out.

## Safety check 3: can control flow skip the `local.set`?

This is the hardest part.

Imagine this shape:

```wat
(block $out
  (local.set $x
    (struct.new $S OLD))
  (struct.set $S 0
    (local.get $x)
    (br_if $out
      (i32.const 1)
      (i32.const 42))))
(drop
  (struct.get $S 0
    (local.get $x)))
```

If Binaryen moved the `br_if` into the constructor, it might branch out **before** the `local.set` runs.
Then later code could observe the wrong value of `$x`.

That is what `canSkipLocalSet(...)` is defending against.

## Fast path: no transferred control flow, no special problem

If the moved value does not transfer control flow, Binaryen does not need the expensive local-graph query.

So the pass only pays for deeper reasoning on the tricky branchy cases.

## Slow path: `LazyLocalGraph::canMoveSet(...)`

When control flow is present, Binaryen asks the local-flow graph whether moving the `local.set` forward would expose bad local uses.

The important detail is that `canMoveSet(...)` is about:

- moving the set **forward**
- and checking which influenced `local.get`s become unsafe

That is exactly the HSO situation.

## The “one bad get is okay” rule

There is one very important exception.

If the only bad `local.get` is the one inside the `struct.set` itself, the pass still allows the optimization.

Why?

Because that `local.get` disappears in the rewrite.

So the real rule is:

- zero bad gets: safe
- exactly one bad get, and it is the set's own ref: still safe
- anything else: unsafe

## Function-external exits versus in-function exits

One of the easiest Binaryen-specific details to miss is:

- `ignoreBranchesOutsideOfFunc = true`

That means the pass mostly ignores exits that leave the function entirely, because its current correctness question is about local state observed **inside** the function.

So these tend to be safer than beginners expect:

- `return`
- return-call forms
- calls that may throw only outside the function

And these are more dangerous than beginners expect:

- `br` / `br_if` to an outer in-function block
- loop backedges that can re-enter earlier local uses
- calls that may throw to a `try` / `try_table` catch inside the same function

## `trySwap(...)` has a smaller job than it sounds like

The pass can also move the fresh `local.set(struct.new ...)` downward inside a block list.

That sounds dramatic, but Binaryen keeps it deliberately simple.

It refuses to swap when:

- the candidate blocker is the final element in the list
- the blocker is another `local.set` of `struct.new`
- the blocker's effects would invalidate the constructor set's effects

So `trySwap(...)` is not a general scheduler.
It is just a local helper for making a nearby `struct.set` adjacent enough to fold.

## Why the last element is a hard stop

The source comment on the last-element bailout is worth keeping in mind:

- if you swap the constructor set with the last list item, there is nothing after it to optimize against
- and you might also create a wrong stack/value shape by moving something that can leave a value after something that did not need to

So the pass simply refuses.

## Why another fresh constructor set is a hard stop

Binaryen also refuses to swap across another `local.set` of `struct.new`.

That avoids “going back and forth” between two constructors.

A good beginner way to think about it is:

- once two fresh constructor sites are competing for the same linear neighborhood, the pass gives up on local motion instead of trying to be clever.

## Old field side effects are preserved, not ignored

If the old constructor field expression had unremovable side effects, Binaryen keeps them with a drop/sequence wrapper.

This is easy to misread as a missed optimization.
It is actually part of the proof.

The pass is allowed to replace the field value only because it preserves the side effects that expression still had.

## `with_default` growth is intentional

Another thing that can surprise people:

- `struct.new_default` may expand into explicit default operands

That can increase code size.

Binaryen still does it because removing the later `struct.set` and making the constructor more direct is usually considered the better overall simplification.

## The test file already documents one scheduler dependency

The dedicated upstream lit test runs:

- `--remove-unused-names`
- then `--heap-store-optimization`

with a comment explaining that removing unused names lets the optimizer see there is no nonlinear control flow from those blocks.

So if a shape looks surprisingly unoptimizable with names intact, that is not necessarily a contradiction.
It is a real pass interaction.

## Easy misunderstandings to avoid

### Misunderstanding 1: “Any call in `NEW` makes it unsafe.”

Not always.

A call that only throws out of the function can still be safe here.
The unsafe case is usually:

- a call whose throw can be caught inside the function

### Misunderstanding 2: “Any branch in `NEW` makes it unsafe.”

Not always.

A branch that stays inside the moved subtree may still be safe.
The unsafe case is:

- a branch that can bypass the moved `local.set` and still leave later local observers alive

### Misunderstanding 3: “This is a general alias-analysis pass.”

It is not.

Most of the pass is still about a narrow constructor/store pattern plus simple motion checks.

### Misunderstanding 4: “If the old field had side effects, the pass should give up.”

No.

Binaryen often preserves those side effects and still folds the new value into the constructor.

## What a future Starshine port must keep honest

- effect checks must cover later operands, descriptor operands, and constructor wrapper effects
- target-local reads and writes must still block reordering
- function-external and in-function exits must not be conflated
- `canMoveSet(...)`-style local visibility proof must remain part of the contract when control flow is present
- preserving old field side effects is correctness work, not optional cleanup
