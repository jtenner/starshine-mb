---
kind: concept
status: supported
last_reviewed: 2026-05-04
sources:
  - ../../../raw/binaryen/2026-05-04-merge-blocks-current-main-refresh.md
  - ../../../raw/binaryen/2026-04-25-merge-blocks-current-main-source-correction.md
  - ../../../raw/binaryen/2026-04-22-merge-blocks-primary-sources.md
  - ../../../raw/research/0436-2026-05-04-merge-blocks-current-main-refresh.md
  - ../../../raw/research/0357-2026-04-25-merge-blocks-source-correction-and-code-map.md
  - ../../../raw/research/0255-2026-04-22-merge-blocks-primary-sources-and-starshine-followup.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./starshine-strategy.md
  - ./starshine-hot-ir-strategy.md
---

# `merge-blocks` WAT Shapes

This is the beginner-friendly shape catalog for Binaryen `merge-blocks`, corrected against current-main and `version_129`.

## Correct mental model

Binaryen `merge-blocks` is a local motion pass:

- it merges safe child blocks into their parent block list;
- it merges safe loop tails;
- it moves safe work out of `drop(block ...)`, `if` conditions, and `throw` operands;
- it preserves branch semantics and refinalizes after edits.

It is **not** a generic label-retargeting pass.

## Quick glossary

- **splicing**: moving a child's roots into the parent root list.
- **loop tail**: the trailing block-shaped part of a loop body that can sometimes be merged upward.
- **drop(block ...) cleanup**: removing a block that is only being discarded while preserving any needed break values.
- **effect-safe**: safe to move without changing observable work.

## Positive family 1: unnamed child block spliced into parent

Before:

```wat
(block
  (i32.const 1)
  (block
    (i32.const 2)
    (i32.const 3))
  (i32.const 4))
```

After:

```wat
(block
  (i32.const 1)
  (i32.const 2)
  (i32.const 3)
  (i32.const 4))
```

Why it merges:

- the child block is safe to absorb;
- the roots can be moved into the parent list;
- the final expression shape still makes sense after refinalization.

## Positive family 2: safe loop-tail merge

Before:

```wat
(loop
  (i32.const 1)
  (block
    (i32.const 2)
    (br 0)))
```

After, schematically:

```wat
(loop
  (i32.const 1)
  (i32.const 2)
  (br 0))
```

Why it merges:

- the loop body has a tail-shaped block that can be merged upward;
- the backedge still behaves the same;
- Binaryen keeps the loop contract intact.

## Positive family 3: `drop(block ...)` cleanup

Before:

```wat
(drop
  (block
    (i32.const 1)
    (i32.const 2)))
```

After, schematically:

```wat
(i32.const 1)
(drop (i32.const 2))
```

Why it matters:

- dropping a block can expose earlier values that still need to be preserved;
- the pass uses the break-value cleanup path to avoid silently losing work.

## Positive family 4: `if` condition motion

Before:

```wat
(if
  (block
    (call $side_effect_free)
    (local.get 0))
  (then (nop))
  (else (nop)))
```

After, schematically:

```wat
(call $side_effect_free)
(if
  (local.get 0)
  (then (nop))
  (else (nop)))
```

Why it matters:

- the pass can move safe work out of the condition;
- this is a real upstream surface, not just a block-list trick.

## Positive family 5: `throw` operand motion

Before:

```wat
(throw $tag
  (block
    (call $side_effect_free)
    (local.get 0)))
```

After, schematically:

```wat
(call $side_effect_free)
(throw $tag
  (local.get 0))
```

Why it matters:

- the operand can sometimes be simplified the same way as a block body;
- `merge-blocks` is broader than plain block flattening.

## Negative family 1: unsafe branch interaction

Before stays after when the move would change branch semantics:

```wat
(block
  (block
    (br 0)))
```

Why it can stay:

- the pass will not move code if the surrounding branch structure is unsafe;
- branch safety is part of the proof, not an afterthought.

## Negative family 2: unsafe loop backedge

Before stays after when the tail cannot be merged without changing the loop backedge meaning:

```wat
(loop
  (block
    (call $must_stay)
    (br 0)))
```

Why it can stay:

- some loop tails are effectful or structurally important;
- the pass only merges safe tails.

## Negative family 3: side effects block movement

Before stays after when moving work would skip an observable effect:

```wat
(block
  (call $has_effect)
  (block
    (i32.const 1)))
```

Why it can stay:

- the pass does not reorder effectful work across a merge boundary;
- effect safety is part of the contract.

## Negative family 4: live-label HOT shapes are a Starshine difference, not a Binaryen positive

Binaryen's upstream `merge-blocks` does not use the HOT live-label rule that current Starshine uses.

If you are looking for the local HOT behavior, read [`./starshine-strategy.md`](./starshine-strategy.md).

## What this pass unlocks later

`merge-blocks` often exposes simpler shapes for:

- `remove-unused-brs`
- `remove-unused-names`
- `vacuum`
- later `merge-blocks` reruns in the preset cluster

## Sources

- [`../../../raw/binaryen/2026-05-04-merge-blocks-current-main-refresh.md`](../../../raw/binaryen/2026-05-04-merge-blocks-current-main-refresh.md)
- [`../../../raw/research/0436-2026-05-04-merge-blocks-current-main-refresh.md`](../../../raw/research/0436-2026-05-04-merge-blocks-current-main-refresh.md)
- Binaryen current-main `merge-blocks.wast`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/merge-blocks.wast>
- Binaryen `version_129` `merge-blocks.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-blocks.wast>
