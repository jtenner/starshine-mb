---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-merge-blocks-current-main-source-correction.md
  - ../../../raw/binaryen/2026-04-22-merge-blocks-primary-sources.md
  - ../../../raw/research/0357-2026-04-25-merge-blocks-source-correction-and-code-map.md
  - ../../../raw/research/0255-2026-04-22-merge-blocks-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0111-2026-04-20-merge-blocks-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./starshine-hot-ir-strategy.md
  - ../../no-dwarf-default-optimize-path.md
supersedes:
  - ../../../raw/research/0111-2026-04-20-merge-blocks-binaryen-research.md
---

# `merge-blocks` WAT Shapes

This is the beginner-friendly shape catalog for Binaryen's `merge-blocks` pass, corrected against official `version_129` and current-main sources on 2026-04-25.

## Correct mental model

Older local notes taught this as a tail-child-only pass that merges unnamed wrappers. That is wrong for the official source.

Use this mental model instead:

- Binaryen removes redundant **named block layers**.
- It can retarget uses of an inner block name to an outer block name only after a branch-user and effect-safety proof.
- It also removes named wrappers in `if` arms and around terminal expression families.
- Nameless wrappers are a negative family in the official lit file.

## Quick glossary

- **named block**: a block with a label such as `$inner` that branches can target.
- **branch user**: a branch, switch, or related control expression that mentions a block label.
- **retargeting**: changing a branch's target name from an inner block to an outer block after removing the inner wrapper.
- **invalidating effect**: work that cannot be skipped or reordered across a retargeted branch.
- **deblocking**: removing a redundant block wrapper while preserving branch semantics.

## Positive family 1: direct same-name block layer

This is the easiest named case.

Before:

```wat
(block $outer
  (i32.const 0)
  (block $outer
    (drop (i32.const 1))))
```

After:

```wat
(block $outer
  (i32.const 0)
  (drop (i32.const 1)))
```

Why it can merge:

- the child is named;
- the parent has the same name;
- branches that used that name already refer to the same visible label family after the wrapper disappears;
- Binaryen still refinalizes after the edit.

## Positive family 2: different-name child whose branch users can be retargeted

The source is not same-name-only. Different child names can be removed when every use of the child name can be changed to the parent name safely.

Before:

```wat
(block $outer
  (block $inner
    (drop (i32.const 1))
    (br $inner)))
```

After, schematically:

```wat
(block $outer
  (drop (i32.const 1))
  (br $outer))
```

Why this is conditional:

- Binaryen must find all `$inner` branch users;
- each user's exiting block must itself be safely changeable to `$outer`;
- retargeting must not skip invalidating effects;
- the implementation rewrites scope-name uses after splicing.

Advanced caveat: do not generalize this into “any different-name block can merge.” The recursive `canChangeTo(...)` proof is the pass.

## Positive family 3: named block wrappers in `if` arms

`visitIf(...)` gives `merge-blocks` a separate `if`-arm surface.

Before:

```wat
(block $outer
  (if
    (i32.const 1)
    (then
      (block $inner
        (drop (i32.const 2))))
    (else
      (block $inner_else
        (drop (i32.const 3))))))
```

After, schematically:

```wat
(block $outer
  (if
    (i32.const 1)
    (then
      (drop (i32.const 2)))
    (else
      (drop (i32.const 3)))))
```

Why this matters:

- an `if` arm is not simply “the final child of a block list”;
- a future port that only checks block-tail children would miss this upstream behavior;
- branch-target and effect safety still bound which arm wrappers can disappear.

## Positive family 4: terminal expression wrapper names

The upstream file also visits terminal families such as `throw`, `rethrow`, and `return`.

Before, schematically:

```wat
(block $outer
  (block $inner
    (return)))
```

After, schematically:

```wat
(block $outer
  (return))
```

Why this can be safe:

- the terminal expression exits the current continuation anyway;
- the wrapper name can become pure structural noise;
- Binaryen keeps this in the same pass because it is another redundant block-name layer.

Advanced caveat: this page is describing the source-owned family, not licensing arbitrary label deletion around all control expressions.

## Negative family 1: nameless block wrappers

The official lit file has `no-merge-nameless` coverage.

Before and after stay the same:

```wat
(block $outer
  (block
    (drop (i32.const 1))))
```

Why it stays:

- the main helper looks for named block wrappers;
- there is no child name to retarget to the parent;
- this contradicts the older local claim that unnamed tail blocks are a primary positive family.

This is the easiest correction to remember: Binaryen and current Starshine diverge here. Starshine can flatten unlabeled branch-free HOT roots; Binaryen's upstream AST pass is name-driven.

## Negative family 2: ambiguous same-name branch retargeting

If `ProblemFinder` sees a branch-target ambiguity family anywhere in the function, Binaryen skips the normal merge walk for that function.

Before and after stay the same, schematically:

```wat
(block $outer
  (block $outer
    (block
      (br $outer))))
```

Why it stays:

- removing one `$outer` layer can make old branch targets ambiguous;
- updating branch names after deletion could update too much;
- Binaryen chooses a whole-function bailout rather than a local best effort.

## Negative family 3: retargeting would skip invalidating effects

Before and after stay the same when a branch retarget would bypass observable work.

```wat
(block $outer
  (call $has_effect)
  (block $inner
    (br $inner)))
```

Why it can stay:

- changing `$inner` to `$outer` may make a branch skip work it previously could not skip;
- `canChangeTo(...)` uses effect analysis to reject those unsafe retargets;
- the exact result depends on the branch users and positions, so reduce surprising cases with source line references rather than only visual nesting.

## Negative family 4: named grandchildren that cannot also be changed safely

When removing a middle block layer, Binaryen checks named child blocks inside it too.

Before and after can stay the same:

```wat
(block $outer
  (block $middle
    (block $grandchild
      (br $grandchild))))
```

Why it can stay:

- deleting `$middle` may expose `$grandchild` to a different parent scope;
- Binaryen does not strand named grandchildren in an unsafe retargeting state;
- the nested proof prevents a local splice from creating a later label-rewrite bug.

## What shapes this pass unlocks later

`merge-blocks` is often useful because it leaves simpler control surfaces for neighboring cleanup passes.

### Unlock family 1: direct branches for `remove-unused-brs`

Before:

```wat
(block $outer
  (block $inner
    (br $inner)))
```

After a safe merge:

```wat
(block $outer
  (br $outer))
```

A later branch-cleanup pass can now see a simpler direct branch shape.

### Unlock family 2: less label noise for `remove-unused-names`

Removing an inner named wrapper means later label cleanup has fewer names to preserve or clear.

### Unlock family 3: simpler typed regions for peepholes

After safe deblocking, later peephole passes see direct expressions instead of expressions hidden under one extra named block layer.

## Starshine-specific contrast

Current Starshine intentionally uses a different HOT-IR proof:

- it flattens branch-free region-root blocks;
- it refuses blocks whose labels are used anywhere;
- it has typed-carrier guards and dead-`unreachable` suffix repair;
- it does not implement Binaryen's recursive branch-name retargeting proof.

So do not use this Binaryen shape catalog as a one-to-one description of `src/passes/merge_blocks.mbt`. Use [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md) for that.

## Source strength note

- Positive and negative families are grounded in `MergeBlocks.cpp` plus the dedicated `merge-blocks.wast` lit file.
- The exact before/after examples above are simplified teaching shapes; consult the raw manifest for official source URLs.
- The main uncertainty is not whether the families exist, but the full set of combinations that the recursive `canChangeTo(...)` proof accepts. Treat nontrivial different-name examples as source-debugging tasks, not pattern-match-only transformations.

## Sources

- [`../../../raw/binaryen/2026-04-25-merge-blocks-current-main-source-correction.md`](../../../raw/binaryen/2026-04-25-merge-blocks-current-main-source-correction.md)
- [`../../../raw/research/0357-2026-04-25-merge-blocks-source-correction-and-code-map.md`](../../../raw/research/0357-2026-04-25-merge-blocks-source-correction-and-code-map.md)
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MergeBlocks.cpp>
- Binaryen `version_129` lit tests: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-blocks.wast>
