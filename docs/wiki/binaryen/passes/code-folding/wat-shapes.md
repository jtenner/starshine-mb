---
kind: concept
status: supported
last_reviewed: 2026-04-22
sources:
  - ../../../raw/binaryen/2026-04-22-code-folding-primary-sources.md
  - ../../../raw/research/0112-2026-04-20-code-folding-binaryen-research.md
  - ../../../raw/research/0257-2026-04-22-code-folding-primary-sources-and-starshine-followup.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./terminating-tails.md
  - ./starshine-strategy.md
  - ../../no-dwarf-default-optimize-path.md
---

# `code-folding` WAT Shapes

This page is the beginner-friendly shape catalog for Binaryen's `code-folding` pass.
The 2026-04-22 raw-source capture rechecked the dedicated Binaryen test and pass surfaces for these teaching examples and did not surface a newer shape family that changes the page's current contract.

## Read this page with one mental model

Binaryen is looking for **duplicate tails** that already reach the same semantic exit.

It is not asking:

- “is there duplicate code anywhere?”

It is asking:

- “do several paths already end in the same place, and do they all end with the same suffix?”

If yes, Binaryen may keep only one copy of that suffix.

## Quick glossary

- **tail**: the last few expressions on a path
- **fallthrough tail**: normal flow reaches the end of a block
- **block-exit tail**: a tail ending in an unconditional `br $label`
- **terminating tail**: a tail ending in `return`, `return_call*`, or `unreachable`
- **poisoned label**: a block label Binaryen refuses to fold because an unsupported branch form targets it
- **shared suffix**: the one copy of code Binaryen keeps after merging duplicates

## Shape 1: identical unnamed `if` arm value blocks can fold completely

Before:

```wat
(if (result f32)
  (i32.const 0)
  (then
    (block (result f32)
      (f32.const -0)))
  (else
    (block (result f32)
      (f32.const -0))))
```

After:

```wat
(drop (i32.const 0))
(f32.const -0)
```

Why it folds:

- both arms are unnamed blocks
- the entire arm bodies are the same tail
- after moving the identical tail out, both arms are empty
- Binaryen replaces the empty `if` with `drop(condition)`

## Shape 2: `if` arms with only a shared suffix fold partially

Before:

```wat
(if (result f32)
  (i32.const 0)
  (then
    (nop)
    (f32.const 0))
  (else
    (f32.const 0)))
```

After:

```wat
(if
  (i32.const 0)
  (then
    (nop))
  (else))
(f32.const 0)
```

Why it folds:

- one arm already has a block-like tail
- the other arm's whole body equals that tail
- Binaryen can wrap the non-block arm in a synthetic block and then treat both as block tails

This is why the pass is slightly broader than “both arms must already be blocks” but still narrower than generic arm similarity.

## Shape 3: simple non-block `if` arms are *not* this pass's job

Before and after stay the same:

```wat
(if (result f32)
  (i32.const 0)
  (then
    (f32.const 0))
  (else
    (f32.const 0)))
```

Why Binaryen leaves it alone here:

- this pass only looks at `if`s with block arms, or a one-arm-wrap case
- the simpler pure-expression case is left to `optimize-instructions`

This is an easy way to tell whether a surprising non-fold is actually a bug.

## Shape 4: named `if` arm blocks do not fold

Before and after stay the same:

```wat
(if (result f32)
  (i32.const 0)
  (then
    (block $l1 (result f32)
      (f32.const 0)))
  (else
    (block $l2 (result f32)
      (f32.const 0))))
```

Why Binaryen keeps it:

- named arm blocks might be branch targets
- moving their suffixes out could make a branch skip code it used to execute

Beginner takeaway:

- arm similarity is not enough
- arm **names** matter

## Shape 5: multiple `br` tails to the same block can share a branch value

Before:

```wat
(block $l (result i32)
  (block
    (br $l
      (i32.const 1)))
  (block
    (br $l
      (i32.const 1)))
  (i32.const 1))
```

After, conceptually:

```wat
(block $l
  (block
    (br $l))
  (block
    (br $l))
  (drop
    (i32.const 1)))
(i32.const 1)
```

Why it folds:

- both tails end in unconditional `br $l`
- the carried branch value is identical
- Binaryen can move the value-producing suffix out and leave the branches behind as valueless branches

This is one of the easiest places to misunderstand the pass.

It is **not** removing the branches. It is sharing the value-producing suffix behind them.

## Shape 6: branch tail plus fallthrough tail can also share a value

Before:

```wat
(block $l (result i32)
  (drop
    (block (result i32)
      (br $l
        (i32.const 1))))
  (drop
    (block (result i32)
      (br $l
        (i32.const 1))))
  (i32.const 1))
```

Why it folds:

- the explicit `br $l` tails and the block's own fallthrough all reach the same semantic exit
- the shared value tail is identical

This is why the source keeps a special `fallthrough` tail representation.

## Shape 7: function-ending duplicated tails can be shared behind a helper label block

Conceptual before:

```wat
;; path A
...
(shared tail C)
(return)

;; path B
...
(shared tail C)
(return)
```

Conceptual after:

```wat
(block $folding-inner0
  ;; old body, but each old tail now branches here
)
(shared tail C)
(return)
```

Why it folds:

- both paths terminate the function anyway
- Binaryen can rewrite the old tails to branch to a fresh helper label
- only one copy of the shared terminating suffix remains

The real emitted shape is more detailed, but this is the right beginner mental model.

## Shape 8: outer-target branches stop a would-be fold

The shipped negative test `break-target-outside-of-return-merged-code` is the canonical example.

Two tails look nearly identical, but part of the moved code branches to a target that lives outside the safe region.

Binaryen keeps the duplicate code.

Why it matters:

- equality is not enough
- branch-target scope must still be valid after movement

## Shape 9: equal-looking switch tails can still be unsafe to hoist

The `careful-of-the-switch` test is even more instructive.

Two blocks differ only in internal label names, so they look alpha-equivalent. But each contains a `br_table` that also depends on an outer target staying in scope.

Binaryen refuses the hoist.

Beginner takeaway:

- “the labels line up if I rename them in my head” is not a proof that the move is safe

## Shape 10: unsupported branch forms poison label folding

Before and after stay the same in the important part:

```wat
(block $block
  (drop
    (br_on_null $block
      (ref.null none)))
  (drop
    (block (result i32)
      (call $br-on-null)
      (br $block)))
  (call $br-on-null))
```

Why Binaryen keeps the duplication:

- `br_on_null` is a branch form this pass does not yet fold with ordinary `br` tails
- the label therefore becomes unoptimizable for this family

This is the easiest visible example of the pass's “poisoned label” rule.

## Shape 11: atomic and non-atomic tails are not equal

Before and after stay the same:

```wat
(if (result i32)
  (i32.const 0)
  (then
    (i32.load $shared offset=22
      (local.get $x)))
  (else
    (i32.atomic.load $shared offset=22
      (local.get $x))))
```

Why it matters:

- code folding is not textual deduplication
- semantic effects still matter
- atomic and non-atomic operations are different tails

## Shape 12: unreachable-condition `if` with concrete arms is left alone

Before and after stay the same in the important part:

```wat
(if (result i32)
  (unreachable)
  (then
    (i32.const 1))
  (else
    (nop)
    (i32.const 1)))
(unreachable)
```

Why Binaryen skips it:

- rewriting an unreachable `if` into a concrete block result can create type-context problems
- Binaryen leaves this family to DCE rather than handling it here

## Shape 13: ref-typed contexts make result typing easy to get wrong

The `refined-type` / `refined-type-blocks` tests are not mainly about code size. They are about not leaving stale surrounding types.

Beginner takeaway:

- if a fold changes where a ref-typed value is produced,
- the outer expression type still has to make sense
- Binaryen's block-arm discipline and outer-type preservation are part of that contract

## What later passes tend to do with the new shape

`code-folding` often creates shapes that are intentionally temporary.

### Unlock family 1: `merge-blocks`

If code folding creates a helper wrapper block around an expression plus the shared suffix, `merge-blocks` may later flatten it.

### Unlock family 2: `remove-unused-brs`

If code folding rewrites several exits into simpler `br $folding-innerN` traffic, late branch cleanup may remove or simplify those branches.

### Unlock family 3: `remove-unused-names`

If helper labels or old labels become less useful after sharing a suffix, name cleanup may shrink the structure further.

### Unlock family 4: late peepholes and `rse`

Once only one copy of a tail remains, late `precompute(-propagate)`, `optimize-instructions`, `heap-store-optimization`, and `rse` see a cleaner single-copy tail to optimize.

## A simple rule of thumb

When you look at a possible `code-folding` candidate, ask these questions in order:

1. Do the candidate paths already reach the same semantic exit?
2. Are we looking at one of the families this pass actually handles?
   - named block exits
   - unnamed `if-else` block arms
   - function-ending `return` / `return_call*` / `unreachable`
3. Is the shared part really a **suffix**?
4. Can that suffix move without crossing one of its own branch targets or EH-sensitive boundaries?
5. Is the size win worth the helper structure?

If any answer is “no,” expect Binaryen to keep the duplicate code.

## Source strength note

- The positive and negative shapes above come directly from Binaryen's shipped `code-folding` lit tests plus the current `version_129` implementation comments.
- The unlock examples are derived explanations of why `code-folding` sits where it does in the late cleanup cluster.

## Sources

- [`../../../raw/binaryen/2026-04-22-code-folding-primary-sources.md`](../../../raw/binaryen/2026-04-22-code-folding-primary-sources.md)
- [`../../../raw/research/0112-2026-04-20-code-folding-binaryen-research.md`](../../../raw/research/0112-2026-04-20-code-folding-binaryen-research.md)
- [`../../../raw/research/0257-2026-04-22-code-folding-primary-sources-and-starshine-followup.md`](../../../raw/research/0257-2026-04-22-code-folding-primary-sources-and-starshine-followup.md)
- Binaryen `version_129` lit tests: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-folding.wast>
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/CodeFolding.cpp>
- Binaryen `version_129` scheduler source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
