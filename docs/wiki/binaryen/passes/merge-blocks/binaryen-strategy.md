---
kind: concept
status: supported
last_reviewed: 2026-07-11
sources:
  - ../../../raw/binaryen/2026-07-11-merge-blocks-expression-child-current-main-recheck.md
related:
  - ./index.md
  - ./wat-shapes.md
  - ./implementation-structure-and-tests.md
  - ./starshine-strategy.md
  - ./starshine-hot-ir-strategy.md
  - ../../no-dwarf-default-optimize-path.md
---

# Binaryen `merge-blocks` Strategy

## Correct current-source model

Binaryen `merge-blocks` is a function-local structured-cleanup pass with three connected routes:

1. **structural merging:** `visitBlock(...)` and `visitLoop(...)` remove eligible nested block/list structure;
2. **special control/cleanup visitors:** `visitDrop(...)`, `visitIf(...)`, and `visitThrow(...)` handle their particular safe motion surfaces; and
3. **generic non-control child extraction:** `visitExpression(...)` moves a legal prefix out of an eligible block-valued child while retaining its tail in that child slot.

The third route is the key current-source clarification. It covers ordinary expression operands such as `array.set`, calls, and stores; it is not limited to the named special visitors. Conversely, `drop`, an `if` condition, and `throw` must not be falsely described as generic `visitExpression(...)` cases: current Binaryen has dedicated visitors for them.

This is neither a named-label retargeting pass nor permission to flatten arbitrary nested blocks.

## Owner-file structure

| Current owner surface | Job |
| --- | --- |
| `visitBlock(...)` / `optimizeBlock(...)` | Merge eligible child blocks into a parent block list. |
| `visitLoop(...)` | Merge an eligible tail block into a loop body without changing the backedge contract. |
| `visitDrop(...)` / `optimizeDroppedBlock(...)` | Clean up a dropped block while preserving needed branch values. |
| `visitIf(...)` | Move a legal block prefix out of the condition only; arms remain regions. |
| `visitThrow(...)` | Simplify eligible throw operands under the pass's effect boundary. |
| `visitExpression(...)` | Extract a legal prefix from ordinary non-control expression children. |
| `visitFunction(...)` | Run the traversal and refinalize after a change. |
| `ProblemFinder` / break-value helpers | Protect structural cleanup paths that need branch/value reasoning. |

The previous live table mixed real helpers with nonexistent `optimizeIf(...)` / `optimizeThrow(...)` names and omitted generic `visitExpression(...)`; use this map instead.

## Generic non-control expression-child extraction

Conceptually, a non-control child can change from:

```wat
(i32.store
  (block (result i32)
    PREFIX
    ADDRESS)
  VALUE)
```

into:

```wat
PREFIX
(i32.store ADDRESS VALUE)
```

The tail remains in the address child slot. The same generic mechanism applies to other ordinary expression children; the current focused fixture demonstrates this route with aggregate and call operands.

### Preconditions

The generic path is deliberately narrow:

- the child is an **unnamed** list block;
- it has at least a prefix and a tail;
- the tail type matches the block result type;
- the tail remains in the original child slot; and
- moving the prefix passes Binaryen's effect-order proof against earlier children.

The relevant source test is `EffectAnalyzer::orderedBefore(...)`, not a casual “both sides look pure” rule. The rewrite must preserve WebAssembly's left-to-right operand evaluation order.

## Special visitor routes

`visitDrop(...)`, `visitIf(...)`, and `visitThrow(...)` are still important source surfaces:

- dropped blocks may need break-value handling;
- only the `if` condition is movable, never an arm body; and
- throw operands have their own effect-sensitive route.

The right beginner model is therefore: **special visitors cover important control shapes; generic child extraction covers the remaining ordinary expression shapes.**

## Structural block and loop merging

The pass also retains its classic work:

- splice eligible child block roots into a parent block list;
- merge a safe trailing block in a loop body;
- preserve branch and result behavior while changing list shape; and
- refinalize the rewritten AST.

Child-prefix extraction keeps the final block expression as an operand; structural merging can remove the wrapper itself. They share a cleanup goal but have different proof obligations.

## What the pass does **not** prove

- It does not generally rename or retarget labels.
- It does not move `if` arm bodies through the condition.
- It does not hoist arbitrary blocks or reorder observable operand effects.
- It does not replace downstream dead-code cleanup, branch cleanup, or refinalization.

## What this means for Starshine

Starshine has two HOT operations:

- region-root block flattening guarded by label, type-carrier, loop, and writeback constraints; and
- one narrower expression-child-prefix helper with branch and local effect-order gates.

This is useful correspondence, not blanket parity evidence. Starshine's single HOT helper supports its local `drop`, `if`, store, and `throw` fixtures; Binaryen reaches those shapes through both special and generic visitor routes. Read [`./starshine-strategy.md`](./starshine-strategy.md) for the local boundary.

## Sources

- [`../../../raw/binaryen/2026-07-11-merge-blocks-expression-child-current-main-recheck.md`](../../../raw/binaryen/2026-07-11-merge-blocks-expression-child-current-main-recheck.md)
- Binaryen current-main [`MergeBlocks.cpp`](https://github.com/WebAssembly/binaryen/blob/main/src/passes/MergeBlocks.cpp)
- Binaryen current-main [`merge-blocks.wast`](https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/merge-blocks.wast)
- Binaryen `version_130` [`MergeBlocks.cpp`](https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/MergeBlocks.cpp)
