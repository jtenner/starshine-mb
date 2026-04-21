---
kind: concept
status: supported
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0130-2026-04-20-vacuum-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
---

# `vacuum`: effect pruning and `traps-never-happen`

This page focuses on the easiest part of `vacuum` to misunderstand.

The pass is not mainly asking:

- `is this node a nop?`

It is usually asking:

- `if this value is unused, what effects still need to survive, and what typed shell do I need around them?`

## The three questions to keep in your head

Whenever `vacuum` looks at an unused result, three questions matter.

1. **May the parent node itself disappear?**
   - checked with `mustKeepUnusedParent(...)`
   - uses `Intrinsics` annotations and `ShallowEffectAnalyzer`
2. **Which children still matter because of effects?**
   - checked with full `EffectAnalyzer`
3. **If the parent disappears, can Binaryen still represent the expected type?**
   - handled with dummy zeros, `getDroppedChildrenAndAppend(...)`, or by giving up

That trio explains most of the real behavior.

## Case 1: no important effects remain

If the parent is removable and none of the children have unremovable side effects:

- `optimize(...)` returns `nullptr`
- the caller can erase the expression entirely

Example mental model:

```wat
(drop
  (i32.add
    (i32.const 1)
    (i32.const 2)))
```

The add and both children are pure, the result is unused, so the whole thing can vanish.

## Case 2: one important child remains

If only one child still has unremovable side effects:

- `vacuum` recurses into that child
- the parent wrapper disappears

That is how a shape like this behaves conceptually:

```wat
(drop
  (i32.eqz
    (call $impure)))
```

The `i32.eqz` wrapper has no effect of its own.

If the result is unused:

- keep the call
- drop the wrapper

That is the main `vacuum` trick.

## Case 3: multiple important children remain

If several children still matter, `vacuum` cannot just pick one.

Instead it may rebuild a sequence of the dropped children and append a dummy value of the original type.

That is what `getDroppedChildrenAndAppend(...)` is for.

But this only works if the original type is defaultable.

So the real rule is:

- multiple effectful children + defaultable type -> rebuild with children plus dummy zero
- multiple effectful children + non-defaultable type -> keep the original wrapper

## Why `typeMatters` exists

Many beginner summaries say `vacuum` removes unused values.

That is incomplete because some unused values are still structurally important.

Examples:

- block fallthrough type
- `if` arm result type
- dropped outer wrapper whose child list still needs a final typed placeholder

So `typeMatters` is the pass's reminder that:

- even unused values cannot always disappear freely

## The easiest concrete example: dropped `if` arms

In `vacuum-intrinsics.wast`, Binaryen can simplify dropped `if (result i32)` arms down to zeros when the result is unused outside the `drop`.

That works because:

- `i32` is defaultable
- zero is a valid dummy replacement

But when the arm result type is a tricky reference type and Binaryen cannot synthesize a safe default replacement, it leaves more structure in place.

So the practical lesson is:

- unused does not mean typeless

## `removableIfUnused` is stronger than ordinary effect checking

`mustKeepUnusedParent(...)` checks call annotations before generic shallow effects.

That means a dropped call can disappear if Binaryen already knows:

- this call is removable when unused

The shipped `vacuum-removable-if-unused.wast` and `vacuum-removable-if-unused-func.wast` tests show the important distinction:

- a dropped annotated call can vanish
- the same call, if its result is still used, must stay
- effectful operands to the call may still need to remain even when the call wrapper goes away

So the pass is not only reading generic side-effect facts.

It also respects Binaryen's explicit call annotations.

## Why generated global effects matter

`vacuum-global-effects.wast` shows another easy-to-miss interaction:

- after `--generate-global-effects`, some calls become known-effect-free enough for `vacuum` to erase them

That means `vacuum` is partially downstream of other analyses and passes.

A good mental model is:

- `vacuum` is small,
- but it becomes smarter when earlier passes or analyses sharpen the effect story.

## `traps-never-happen` is real, but not magical

When TNH is enabled, `vacuum` is allowed to ignore trap-only behavior in some situations.

But the important word is **some**.

## What TNH directly enables in `Vacuum.cpp`

### 1. Backward pruning before an explicit `unreachable` in a block

Binaryen can remove earlier code when execution is definitely heading into an explicit `unreachable`.

But it stops at barriers like:

- control transfer
- calls
- may-not-return behavior
- dangling `pop`

So TNH does **not** mean:

- `delete everything before a trap`

It means:

- `delete only what is definitely on the trap path and does not cross a barrier`

### 2. Removing one definitely-trapping `if` arm

In TNH mode, if exactly one arm is `unreachable` and the `if` itself is not already unreachable:

- Binaryen can replace the `if` with `drop(condition)` plus the live arm

But if both arms are `unreachable`:

- it leaves the shape for DCE

Again, TNH is useful but conservative.

### 3. Whole-function cleanup of trap-only void bodies

If a void function has no remaining unremovable side effects, `vacuum` may nop the whole body.

But the explicit-`unreachable` safeguard still applies.

So TNH can remove:

- implicit-trap-only whole bodies

but it intentionally does **not** remove:

- whole bodies that still contain explicit `unreachable`

because later passes should still be able to see and propagate that unreachability.

## Explicit `unreachable` versus implicit trap is a major distinction

This is one of the most important `vacuum` facts.

Binaryen treats these differently:

- explicit `unreachable`
- implicit traps like a bad load or trapping cast under options that let those be ignored

Why the distinction matters:

- removing an implicit trap in TNH is often just cleanup
- removing an explicit `unreachable` can hide a useful propagation signal from callers and later passes

That is why the `FindAll<Unreachable>` safeguard exists at function scope.

## Why the repo's earlier drift note needed correction

A previous repo-local note treated explicit-`unreachable` preservation as a newer trunk-only `Vacuum` behavior.

The 2026-04-20 source check corrected that:

- the real `Vacuum` commit is `f284d54...`
- `version_129` already includes it
- the previously cited `9ee4...` hash is actually a `RemoveUnusedBrs` change

So explicit-`unreachable` preservation belongs in the tagged `version_129` strategy itself.

## `ignore-implicit-traps` matters indirectly

The `vacuum-desc.wast` tests run under:

- ordinary mode
- `--ignore-implicit-traps`
- `--traps-never-happen`

`Vacuum.cpp` only branches explicitly on TNH.

So the best source-grounded inference is:

- `ignore-implicit-traps` changes what the effect analyzers report
- `vacuum` then benefits from those changed effect facts

In other words, `ignore-implicit-traps` matters here through the analyzers, not through a dedicated special-case `Vacuum.cpp` branch.

## Trap-sensitive examples that stay versus disappear

The tests show several useful contrasts.

### Stays by default because trap-sensitive

- `string.compare`
- nullable `i31.get`
- nullable `ref.as_non_null`
- many nullable descriptor and cast forms

### Can disappear because non-trapping or effectively harmless under options

- `string.eq`
- some dropped reference / descriptor forms under `ignore-implicit-traps` or TNH
- trap-only residue before explicit `unreachable` when the barrier rules allow it

### Stays because synchronization is still observable

- shared mutable `struct.atomic.get` examples in `vacuum-gc-atomics.wast`

So the pass is not using a crude `GC op = keep` rule.

It is using effect semantics.

## Calls and loops still block aggressive cleanup

The TNH tests also make two conservatism rules obvious.

### Calls remain barriers

Even if later code heads to an explicit trap:

- a call stays

Reason:

- calls may have non-trap effects
- they may not return

### Infinite or potentially non-returning loops remain barriers

Even in TNH mode, a loop is not removed just because an `unreachable` exists later.

Reason:

- the loop may never reach that trap

This is a good reminder that TNH is still control-sensitive.

## One-sentence rule for beginners

When the result is unused, Binaryen `vacuum` asks:

- `what effects still need to survive, and what is the smallest valid typed shell I can leave around them?`

That question explains the pass much better than:

- `does this look dead?`
