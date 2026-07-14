---
kind: concept
status: supported
last_reviewed: 2026-07-11
sources:
  - ../../../raw/binaryen/2026-07-11-merge-blocks-expression-child-current-main-recheck.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./starshine-strategy.md
  - ./starshine-hot-ir-strategy.md
---

# `merge-blocks` WAT Shapes

This beginner-oriented catalog separates Binaryen's current `merge-blocks` routes:

- **structural merge:** remove a safe block wrapper by splicing its roots into a parent block or loop body;
- **special visitors:** dropped-block cleanup, an `if` condition, and `throw` operands; and
- **generic non-control child extraction:** move a safe prefix out of an ordinary block-valued operand while retaining its tail as the operand.

The current-source correction is that special visitors are not the whole pass: ordinary expression children have a generic route too.

## Quick glossary

- **prefix:** all block roots except the final root.
- **tail:** the final root; it remains where the parent expression needs a value.
- **child slot:** one ordered operand of an expression, such as a store address or value.
- **effect order:** WebAssembly evaluates operands in order. A rewrite must not swap observable work.

## Structural positive: child block spliced into a parent

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

The wrapper can disappear only when the list/result/branch shape remains legal.

## Structural positive: loop-tail merge

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

The loop backedge and result behavior remain the safety boundary; not every tail block is mergeable.

## Special-visitor positive: `drop`

Before:

```wat
(drop
  (block (result i32)
    (drop (i32.const 7))
    (i32.const 9)))
```

After:

```wat
(drop (i32.const 7))
(drop (i32.const 9))
```

The first `drop` is the moved prefix. The final `i32.const 9` remains the value consumed by the outer `drop`.

## Special-visitor positive: `if` condition

Before:

```wat
(if (result i32)
  (block (result i32)
    (drop (i32.const 7))
    (local.get 0))
  (then (i32.const 1))
  (else (i32.const 2)))
```

After, schematically:

```wat
(drop (i32.const 7))
(if (result i32)
  (local.get 0)
  (then (i32.const 1))
  (else (i32.const 2)))
```

Only the condition is an ordinary expression child. The arm bodies are not hoisted through the `if`.

## Generic non-control child extraction: representative `i32.store` operands

Before:

```wat
(i32.store
  (block (result i32)
    (drop (i32.const 7))
    (i32.const 0))
  (block (result i32)
    (drop (i32.const 8))
    (local.get 0)))
```

After, schematically:

```wat
(drop (i32.const 7))
(drop (i32.const 8))
(i32.store (i32.const 0) (local.get 0))
```

This is a representative ordinary non-control operand shape for the generic owner-file route. The focused upstream fixture demonstrates generic extraction with aggregate and call operands; Starshine has the direct store fixture.

## Special-visitor positive: `throw` argument

Before:

```wat
(throw $tag
  (block (result i32)
    (drop (i32.const 7))
    (i32.const 9)))
```

After:

```wat
(drop (i32.const 7))
(throw $tag (i32.const 9))
```

## Negative: effect ordering blocks the move

Conceptually, this must stay nested when moving `PREFIX` past an earlier effectful operand would swap observable work:

```wat
(i32.store
  (call $effectful_address)
  (block (result i32)
    PREFIX
    (local.get 0)))
```

If `PREFIX` is also effectful, extracting it before `call $effectful_address` would be wrong. The current source uses `EffectAnalyzer::orderedBefore(...)` to reject effect-order violations.

## Negative: one-expression block

This is not a prefix-extraction opportunity:

```wat
(drop (block (result i32) (i32.const 9)))
```

There is no prefix to move and the tail must stay the `drop` operand.

## Negative: arm bodies are not condition operands

The pass does not move this arm prefix outside the `if` merely because the arm contains a block:

```wat
(if
  (local.get 0)
  (then
    (block
      PREFIX
      (nop))))
```

Control-region traversal has separate branch, result, and reachability constraints.

## Starshine reading boundary

Current Starshine has tests for the `if` condition, `drop`, `i32.store`, and `throw` examples at [`src/passes/merge_blocks_test.mbt:2168-2295`](../../../../../src/passes/merge_blocks_test.mbt). Its HOT rules add live-label, typed-carrier, loop-containing-region, branch-prefix, and local effect guards, so do not infer full upstream expression-family parity from these four fixtures.

## Sources

- [`../../../raw/binaryen/2026-07-11-merge-blocks-expression-child-current-main-recheck.md`](../../../raw/binaryen/2026-07-11-merge-blocks-expression-child-current-main-recheck.md)
- Binaryen current-main [`MergeBlocks.cpp`](https://github.com/WebAssembly/binaryen/blob/main/src/passes/MergeBlocks.cpp)
- Binaryen current-main [`merge-blocks.wast`](https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/merge-blocks.wast)
- [`../../../../../src/passes/merge_blocks_test.mbt`](../../../../../src/passes/merge_blocks_test.mbt)
