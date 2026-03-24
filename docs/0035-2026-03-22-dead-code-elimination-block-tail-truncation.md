# DeadCodeElimination Block Tail Truncation

Status: completed Slice 3 from [`docs/0017-2026-03-22-dead-code-elimination.md`](/home/jtenner/Projects/starshine-mb/docs/0017-2026-03-22-dead-code-elimination.md). The typed `DeadCodeElimination` runner now trims dead tails from enclosing `typed instruction body` lists and collapses trivial `[unreachable]` blocks, but it still does not track live breaks or update enclosing block result types.

## Scope

Checkpoint the first enclosing-control-flow behavior for `DeadCodeElimination`: truncate code after the first terminating item in a typed expression list, keep outer code alive after nested `br 0` blocks, and fold `block { unreachable }` into the child.

## Landed Behavior

- `run_dead_code_elimination` now installs a legacy recursive optimizer-body hook in [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) that walks child instructions first, then truncates the rebuilt `typed instruction body` after the first terminating instruction.
- Terminating instructions at the current list level currently include direct `unreachable`, `return*`, `throw*`, `br`, and `br_table`.
- Nested `block` instructions only terminate an enclosing parent list when their final surviving child still escapes the parent expression, currently limited to `unreachable`, `return*`, and `throw*`.
- Trivial `block` instructions whose rewritten body is exactly `[unreachable]` now collapse to the child instead of preserving a redundant wrapper.

## Correctness Constraints

- A nested `block` ending in `br 0` must truncate that block body but must not make sibling instructions after the block disappear.
- A rewritten helper block like `block(drop(prefix), unreachable)` must still count as terminating for the outer list so code after it is removed.
- This slice must stay conservative around block result typing: it trims dead tails, but it does not yet retag concrete block types based on removed breaks.

## Validation

- Added focused whitebox coverage in [`src/optimization/dead_code_elimination_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/dead_code_elimination_wbtest.mbt) for:
  - code after `return` in a function body
  - code after `br` inside a nested block while preserving outer code
  - code after a rewritten unreachable block
  - trivial `[unreachable]` block collapse
- Verified with `moon test src/optimization/dead_code_elimination_wbtest.mbt`.

## Performance Impact

- Negligible. The slice adds one linear scan per rewritten typed expression list.

## Next Work

- Slice 4 is still required: track live incoming breaks and synchronously update block result types when dead breaks disappear.
- After that, land the `if`-specific unreachable rules from the main research doc.
