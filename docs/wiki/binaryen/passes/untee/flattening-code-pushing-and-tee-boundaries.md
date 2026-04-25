---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-untee-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-23-untee-primary-sources.md
  - ../../../raw/research/0347-2026-04-25-untee-current-main-recheck.md
  - ../../../raw/research/0185-2026-04-21-untee-binaryen-research.md
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/Untee.cpp
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/SimplifyLocals.cpp
  - ../code-pushing/binaryen-strategy.md
  - ../simplify-locals/variant-matrix-and-scheduler.md
  - ../simplify-locals-notee/variant-boundaries-and-registry-aliases.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../code-pushing/index.md
  - ../simplify-locals-notee/index.md
---

# `untee`: flattening, `code-pushing`, and tee boundaries

Use this page together with the raw primary-source manifest in [`../../../raw/binaryen/2026-04-23-untee-primary-sources.md`](../../../raw/binaryen/2026-04-23-untee-primary-sources.md) and the 2026-04-25 current-main bridge in [`../../../raw/binaryen/2026-04-25-untee-current-main-recheck.md`](../../../raw/binaryen/2026-04-25-untee-current-main-recheck.md).

This page covers the easiest part of `untee` to misread:

- why Binaryen bothers exposing a standalone pass for such a tiny rewrite
- how it differs from `simplify-locals-notee`
- why the unreachable fast path is part of the real contract

## Why `untee` exists at all

The most important clue is the top comment in `Untee.cpp`.
It says removing tees makes the code "flatter" with less nested side effects, and that this can make passes like `CodePushing` more effective.

That comment is easy to overread.
It does **not** mean:

- `untee` enforces Flat IR like `flatten`
- `untee` is a default optimize-path slot near `code-pushing`
- `untee` is a general-purpose simplifier

It means something smaller and more concrete:

- a `local.tee` hides a write and a value result in one node
- `untee` makes the write explicit as `local.set`
- then it makes the result explicit as `local.get`
- so later passes can reason about those steps separately

## Why that can help `code-pushing`

`code-pushing` is about moving a suffix of work deeper into control flow when that movement is safe and worthwhile.
A combined side-effect-plus-result node can be harder to treat as a simple movable suffix piece.

After `untee`, the shape is more explicit:

- the store side effect is visible
- the value readback is visible
- any later movement pass can decide about them separately or keep them together with less hidden behavior

Inference note:

- the official `Untee.cpp` comment is the direct source-backed claim here
- the exact future scheduler story for Starshine remains an open design question, not a settled upstream preset fact

## Why `untee` is not `simplify-locals-notee`

This is the most important family distinction.

### `untee`

- removes **existing** tee nodes
- does not do general local sinking
- does not do equivalent-copy cleanup
- does not form block/if/loop result structure
- only rewrites one exact node family

### `simplify-locals-notee`

- is still the broader `SimplifyLocals<false, true, true>` optimization pass
- still performs single-use sinking
- still forms structured result blocks/ifs/loops when legal
- still does late equivalent-copy cleanup
- only forbids transformations that would need to create a **new** tee

So the two passes point in different directions:

- `untee`: expand tees into explicit set/get form
- `simplify-locals-notee`: optimize locals broadly, but refuse to introduce new tee syntax

## Why `untee` is not `simplify-locals-nonesting`

Another easy confusion is the word "flatter".

`untee` can make code flatter in the sense of **less hidden side-effect nesting**, but it can also introduce visible `block (result ...)` wrappers around former tees.

`simplify-locals-nonesting`, by contrast, is explicitly about preserving flatness / avoiding new nesting in the `simplify-locals` family.

So "flatter" in the `Untee.cpp` comment should be read narrowly:

- flatter side-effect spelling
- not necessarily fewer explicit blocks in the printed tree

## Why the unreachable fast path matters

Without the unreachable special case, a naive port might try to rewrite:

```wat
(local.tee $x (unreachable))
```

into something like:

```wat
(block (result T)
  (local.set $x (unreachable))
  (local.get $x))
```

That would be a bad reading of the contract.

The real pass instead drops the tee shell entirely and keeps only the unreachable child.
Why?

- execution never reaches the write
- there is no meaningful produced value to read back
- the dedicated lit file treats this behavior as first-class, not incidental

So a future Starshine port must preserve this special case exactly.

## The safest one-sentence explanation

If a beginner asks what `untee` does, the safest short answer is:

> It rewrites `local.tee` into explicit `local.set` + `local.get`, except when the tee is already unreachable, in which case it deletes the tee wrapper.

That answer is much safer than:

- "it is a locals optimizer"
- "it is the same as `simplify-locals-notee`"
- "it makes the function flat"

## Sources

- [`../../../raw/binaryen/2026-04-25-untee-current-main-recheck.md`](../../../raw/binaryen/2026-04-25-untee-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-23-untee-primary-sources.md`](../../../raw/binaryen/2026-04-23-untee-primary-sources.md)
- [`../../../raw/research/0347-2026-04-25-untee-current-main-recheck.md`](../../../raw/research/0347-2026-04-25-untee-current-main-recheck.md)
- [`../../../raw/research/0185-2026-04-21-untee-binaryen-research.md`](../../../raw/research/0185-2026-04-21-untee-binaryen-research.md)
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/Untee.cpp>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/SimplifyLocals.cpp>
- [`../code-pushing/binaryen-strategy.md`](../code-pushing/binaryen-strategy.md)
- [`../simplify-locals/variant-matrix-and-scheduler.md`](../simplify-locals/variant-matrix-and-scheduler.md)
- [`../simplify-locals-notee/variant-boundaries-and-registry-aliases.md`](../simplify-locals-notee/variant-boundaries-and-registry-aliases.md)
