---
kind: concept
status: supported
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0111-2026-04-20-merge-blocks-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ../../no-dwarf-default-optimize-path.md
---

# `merge-blocks` WAT Shapes

This page is the beginner-friendly shape catalog for Binaryen's `merge-blocks` pass.

## Read this page with one mental model

A block can be flattened only when the inner block is just a safe wrapper around the **tail** of the outer block.

The pass is looking for:

```wat
(block $outer
  ...
  (block $child
    ...))
```

and asking:

- can I copy the child's contents directly into `$outer`?
- if I do, do branch targets still mean the same thing?
- do parent and child still promise the same result type?
- does any observable work disappear?

If the answer is yes, Binaryen merges the blocks.

## Quick glossary

- **tail child**: the final item in a block's instruction list
- **unnamed block**: a block with no branch label name
- **same-name block**: the child and parent use the same label name
- **typed block**: a block with an explicit result type like `(result i32)`
- **invalidating effects**: side effects or control effects that make it unsafe to retarget branches across the child body

## Shape 1: unnamed tail block merges

This is the easiest positive case and appears directly in Binaryen's lit tests.

Before:

```wat
(block $A
  (i32.const 0)
  (block
    (drop
      (i32.const 1))
    (br $A
      (i32.const 2))))
```

After:

```wat
(block $A
  (i32.const 0)
  (drop
    (i32.const 1))
  (br $A
    (i32.const 2)))
```

Why it merges:

- the child is the last item in the parent
- the child is unnamed, so it is not a named branch target
- flattening it does not change the block result contract

Why this shape matters:

- it is the core "remove a wrapper block" family
- it exposes later branch cleanup without needing any complicated name rewrite

## Shape 2: same-name typed tail block can still merge

Binaryen also merges a narrower named case.

Before:

```wat
(block $A (result i32)
  (i32.const 0)
  (block $A (result i32)
    (drop (i32.const 1))
    (br $A (i32.const 2))))
```

After:

```wat
(block $A (result i32)
  (i32.const 0)
  (drop (i32.const 1))
  (br $A (i32.const 2)))
```

Why this example is important:

- many people first reading the source assume that any same-name nested branch must be rejected
- Binaryen's own tests show that is too pessimistic
- the real hazard is narrower than "same-name child plus any branch to that name"

Beginner takeaway:

- same-name children are not automatically forbidden
- but they live in a much stricter safety zone than unnamed children

## Shape 3: same-name descendant branch hazard does **not** merge

This is the most important negative case and is also covered directly by Binaryen's lit tests.

Before and after stay the same:

```wat
(block $A (result i32)
  (block $A (result i32)
    (drop (i32.const 1))
    (block (result i32)
      (br $A (i32.const 2)))))
```

Why Binaryen keeps it:

- this is the shadowed same-name descendant-branch family that `ProblemFinder` is designed to catch
- if Binaryen removes the inner `$A` first and only then tries to retarget branches, some branch uses can become ambiguous
- upstream chooses safety and bails out of merging for the whole function

Beginner takeaway:

- the dangerous family is not just "nested names"
- it is nested names plus the wrong descendant-branch layout

## Shape 4: named child with branch-like effects stays intact

Binaryen's lit tests also preserve this family:

```wat
(block $B (result i32)
  (block $A (result i32)
    (i32.const 1)
    (br $B (i32.const 2))))
```

Why this should stay intact:

- the child has a name
- its body contains control effects
- flattening a named child is only safe when the child does **not** invalidate effects

Beginner version:

- if some retargeted branch could now skip the child body, and the child body does observable work, Binaryen refuses the merge

## Shape 5: different-name child does not merge

Derived directly from the source gate that only accepts unnamed children or same-name children.

```wat
(block $outer
  ...
  (block $inner
    ...))
```

Even if `$inner` is last, Binaryen does not treat that as an automatic merge candidate.

Why this matters:

- `merge-blocks` is intentionally narrow
- it is not a general named-label rewrite pass

## Shape 6: result-type mismatch does not merge

Derived directly from the `curr->type == child->type` gate.

Example family:

```wat
(block (result i32)
  ...
  (block
    ...))
```

or any other parent/child type mismatch.

Why it matters:

- a block type is part of the control-flow contract
- if flattening changes which block a branch is targeting, the branch payload contract must still match exactly

Beginner takeaway:

- structural cleanup is not allowed to silently change result typing

## Shape 7: non-tail nested block does not merge

Derived directly from the source's first candidate check.

```wat
(block
  (block
    ...)
  (call $later))
```

No merge.

Why it matters:

- the pass only knows how to flatten the **last** child safely
- if later siblings exist, flattening can change which code is still reachable after branching

## Shape 8: one bad same-name family can block the whole function

This is not a single before/after rewrite shape; it is an execution rule.

If a function contains the dangerous same-name descendant-branch family anywhere, Binaryen's `ProblemFinder` skips merging for that **entire function**.

Why this matters for examples:

- when you reduce a failing or surprising case, do not assume only the local nested block matters
- a separate bad same-name family elsewhere in the function can explain why an apparently easy candidate did not merge

## What shapes this pass usually unlocks later

`merge-blocks` often matters less for its own printed diff and more for the simpler shapes it leaves behind.

### Unlock family 1: fewer wrapper blocks for `remove-unused-brs`

Before merge-blocks:

```wat
(block $A
  (block
    (br $A)))
```

After merge-blocks:

```wat
(block $A
  (br $A))
```

Now a later branch-cleanup pass sees the direct branch shape more clearly.

### Unlock family 2: cleaner typed tails for later peepholes

Before merge-blocks:

```wat
(block (result i32)
  ...
  (block (result i32)
    (i32.const 7)))
```

After merge-blocks:

```wat
(block (result i32)
  ...
  (i32.const 7))
```

That is a simpler surface for later `precompute` or instruction cleanup.

### Unlock family 3: fewer useless structural names

If a same-name wrapper disappears, later `remove-unused-names` or follow-up cleanup has less structure to preserve.

## A simple rule of thumb

When reading a candidate shape, ask these four questions in order:

1. Is the child block the **last** item in the parent?
2. Is the child **unnamed** or the **same name** as the parent?
3. Do the parent and child have the **same result type**?
4. If the child is named, would skipping its body hide any **observable work**?

If any answer is "no", expect Binaryen to keep the wrapper.

## Source strength note

- Shapes 1 through 4 are directly grounded in Binaryen's shipped tests and source comments.
- Shapes 5 through 7 are direct simplifications of the source gates in `MergeBlocks.cpp`.
- The unlock examples are derived explanations of why the pass sits where it does in the late cleanup cluster.

## Sources

- [`../../../raw/research/0111-2026-04-20-merge-blocks-binaryen-research.md`](../../../raw/research/0111-2026-04-20-merge-blocks-binaryen-research.md)
- Binaryen `version_129` lit tests: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-blocks.wast>
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MergeBlocks.cpp>
