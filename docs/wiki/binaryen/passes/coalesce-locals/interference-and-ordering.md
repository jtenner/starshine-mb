---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-coalesce-locals-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-22-coalesce-locals-primary-sources.md
  - ../../../raw/research/0352-2026-04-25-coalesce-locals-current-main-and-test-map.md
  - ../../../raw/research/0264-2026-04-22-coalesce-locals-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0118-2026-04-20-coalesce-locals-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ../local-subtyping/index.md
---

# `coalesce-locals`: interference and ordering

This page exists because the pass name invites two very common misunderstandings:

1. “If two locals are live at the same time, they obviously interfere.”
2. “Once you know the conflicts, the rest is just one trivial greedy pass.”

Both are wrong.

## Provenance note

Use [`../../../raw/binaryen/2026-04-22-coalesce-locals-primary-sources.md`](../../../raw/binaryen/2026-04-22-coalesce-locals-primary-sources.md) as the immutable source manifest for the official Binaryen release/source/test URLs rechecked on 2026-04-22.
Use [`../../../raw/binaryen/2026-04-25-coalesce-locals-current-main-recheck.md`](../../../raw/binaryen/2026-04-25-coalesce-locals-current-main-recheck.md) as the narrow current-`main` freshness bridge.
A focused 2026-04-25 spot check did not surface teaching-relevant drift beyond the `version_129` mechanics summarized here. For owner-file and lit-test landmarks, see [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md).

## Mental model first

A safe mental model is:

- Binaryen tracks where locals are live,
- but also what value each live local is known to hold,
- then it greedily reuses storage slots in an order that tries to delete useful copies.

So the real pass is not just liveness and not just coloring.
It is **value-aware liveness plus order-sensitive coloring**.

## Part 1: overlapping liveness is not enough for interference

The core interference rule is:

- two locals conflict when they are simultaneously live with **different** values

That extra condition matters a lot.

### Example A: implicit zero-init values can share

At function entry, body locals conceptually start with their default zero value.

So this is a positive case:

```wat
(local $x i32)
(local $y i32)
(drop (local.get $x))
(drop (local.get $y))
```

Binaryen can coalesce those locals because both are just the implicit `0` and never diverge.

That is why the official test has a dedicated `zero-init` case.

### Example B: equal constants can overlap and still share

This is another positive case:

```wat
(local $x i32)
(local $y i32)
(local.set $x (i32.const 42))
(local.set $y (i32.const 42))
(drop (local.get $x))
(drop (local.get $y))
```

Even though both locals are live, they hold the same value.
So Binaryen does not mark a conflict.

The tests `equal-constants` and `equal-constants-nonzero` exist to make this precise.

### Example C: different constants really do conflict

Flip one constant and the story changes:

```wat
(local.set $x (i32.const 42))
(local.set $y (i32.const 1337))
(drop (local.get $x))
(drop (local.get $y))
```

Now the live overlap contains different values, so the locals must stay separate.

That is the `different-constants*` family.

## Part 2: why wasm zero-init simplifies block-merge reasoning

The large source comment in `calculateInterferences()` makes one very wasm-specific argument.

Because locals always have a default value:

- if a local is live at the start of a block,
- then it must also be live at the end of every predecessor that reaches that block.

That means a merge-only conflict does not need a separate phi-style algorithm.
The conflict will already show up somewhere inside the predecessors.

This is one of the most important reasons a future port must not silently swap in a generic “textbook register allocator” explanation. Binaryen is using a simpler argument that depends on wasm locals never being truly uninitialized.

## Part 3: params are special because the ABI fixes them in place

Parameters are deliberately outside the normal coalescing game.

Binaryen forces them to interfere with each other and preserves their order.
That serves two roles:

- the function ABI stays stable
- the coloring code does not need ad hoc “maybe this is a param” special cases later

The entry-state fix with zero-init locals is the same kind of thinking:

- body locals conceptually start with implicit sets
- those implicit sets can conflict with params
- so Binaryen patches that relation in manually

## Part 4: effective sets matter more than many beginners expect

A set only matters for interference if some later get may actually read it.

Binaryen calls such a set **effective**.

If a set is ineffective:

- it does not start a meaningful live range for interference
- it may later be rewritten away entirely

That is why the test `this-is-effective-i-tell-you` matters.
A set inside structured control can still be effective even if the function shape makes it tempting to dismiss it casually.

## Part 5: instruction order can flip a result from positive to negative

The pair `if5` and `if5-flip` is the cleanest beginner example.

### Positive shape: handoff without overlap

Conceptually:

```wat
(drop (local.get $x))
(local.set $y (i32.const 1))
(drop (local.get $y))
```

Here `$x` dies before `$y` becomes live, so Binaryen can merge them.

### Negative shape: write first, read old local second

Conceptually:

```wat
(local.set $y (i32.const 1))
(drop (local.get $x))
(drop (local.get $y))
```

Now `$y` begins to matter before `$x` has finished, so the ranges overlap with different values.
Binaryen keeps them separate.

That is a great example of why “roughly the same code” is not good enough. Small local order changes are semantically relevant here.

## Part 6: greedy order matters after the interference matrix is known

Even after you know the conflicts, a greedy coloring pass can still end up with different results depending on the visit order.

Binaryen acknowledges that directly.

### The two default tries

The normal pass tries:

- a natural order, adjusted by copy priorities
- a reverse order, adjusted by the same priorities

Then it keeps the better result.

### Why copy priorities matter

`totalCopies` is not just a random tie-break.
Binaryen is saying:

- a coalescing choice that removes more copy code is often the better practical result

That is why it compares candidate solutions first by removed copies and only then by final max index.

### The `greedy-can-be-happy` / `greedy-can-be-sad` tests

Those two tests exist because order really can change the outcome.
They are the clearest proof that Binaryen is using a useful heuristic, not a guaranteed optimum.

## Part 7: loop backedges get extra influence on the order story

`increaseBackEdgePriorities()` is where Binaryen says:

- “copies on loop backedges deserve a little more weight.”

This matters because a copy on a backedge can behave like a loop-phi maintenance cost.
The `loop-backedge` test is the canonical example: Binaryen prefers the merge that removes the backedge copy rather than another equally-good-looking merge elsewhere.

Beginner takeaway:

- not all copies are equally important
- loop-carried copies are slightly more urgent

## Part 8: the learning variant proves the default heuristic is a heuristic

Binaryen also exposes `coalesce-locals-learning`, which uses a small genetic learner to search orderings.

That tells you something useful about the normal pass:

- the normal pass is intentionally heuristic
- Binaryen knows the order question is real enough to justify experimentation

But the default pipeline still uses plain `coalesce-locals`, so a faithful port should match the normal heuristic first.

## Part 9: exact type equality is why `local-subtyping` must run first

Coloring refuses to merge locals unless their types are exactly equal.

So this pass will not itself solve cases like:

- “these two locals could share if they were both narrowed to the same child-ref type.”

That is why `local-subtyping` must run first.
If it narrows several locals to one exact common type, then `coalesce-locals` can combine them later.

Without that scheduler order, the coalescer would be stuck with wider or mismatched types and miss legal opportunities.

## Easy-to-miss truths

If you only remember a few things from this page, remember these:

1. live overlap is only a problem when the live values differ
2. zero-init is part of the analysis model, not a side fact
3. params are fixed and specially protected
4. ineffective sets do not create interference the same way effective ones do
5. small source-order changes can flip a merge from legal to illegal
6. greedy order matters enough that Binaryen tries more than one
7. backedge copies deserve extra weight
8. exact type equality is one reason `local-subtyping` must come first

## Porting checklist

A future Starshine port should preserve all of these points:

- value-aware interference, not plain live-range overlap
- wasm default-value reasoning at merges
- explicit param freezing
- effective-set tracking
- source-order-sensitive overlap handling
- copy-weighted greedy ordering
- backedge copy prioritization
- the distinction between the normal heuristic and the optional learning variant

## Sources

- [`../../../raw/binaryen/2026-04-25-coalesce-locals-current-main-recheck.md`](../../../raw/binaryen/2026-04-25-coalesce-locals-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-22-coalesce-locals-primary-sources.md`](../../../raw/binaryen/2026-04-22-coalesce-locals-primary-sources.md)
- [`../../../raw/research/0352-2026-04-25-coalesce-locals-current-main-and-test-map.md`](../../../raw/research/0352-2026-04-25-coalesce-locals-current-main-and-test-map.md)
- [`../../../raw/research/0264-2026-04-22-coalesce-locals-primary-sources-and-starshine-followup.md`](../../../raw/research/0264-2026-04-22-coalesce-locals-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0118-2026-04-20-coalesce-locals-binaryen-research.md`](../../../raw/research/0118-2026-04-20-coalesce-locals-binaryen-research.md)
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/CoalesceLocals.cpp>
- Binaryen `version_129` liveness helper: <https://github.com/WebAssembly/binaryen/blob/version_129/src/cfg/liveness-traversal.h>
- Binaryen `version_129` value-numbering helper: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/numbering.h>
- Binaryen `version_129` lit tests: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/coalesce-locals.wast>
