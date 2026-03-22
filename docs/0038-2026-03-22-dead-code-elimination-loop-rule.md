# DeadCodeElimination Loop Rule

Status: completed Slice 6 from [`docs/0017-2026-03-22-dead-code-elimination.md`](/home/jtenner/Projects/starshine-mb/docs/0017-2026-03-22-dead-code-elimination.md). `DeadCodeElimination` now implements the conservative loop rewrite from Binaryen instead of leaving literal-unreachable loop bodies wrapped in a redundant `loop`.

## Scope

Checkpoint the loop-specific rule only:

- if the rewritten loop body is the literal `unreachable` node, replace the loop with that child
- do not perform broader loop simplification

## Landed Behavior

- [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) now routes typed `loop` nodes through a dedicated DCE helper.
- When the surviving loop body is exactly `[unreachable]`, DCE now returns the child directly.
- Other loops, including normal branch-back loops, stay untouched even if they are still non-terminating.

## Correctness Constraints

- `loop { unreachable }` should not survive as a redundant wrapper after child rewriting.
- `loop { br 0 }` must remain a loop. This pass is not allowed to over-simplify or reinterpret ordinary looping control flow.
- This slice must not change the surrounding reachability model for non-literal loop bodies.

## Validation

- Added focused whitebox coverage in [`src/optimization/dead_code_elimination_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/dead_code_elimination_wbtest.mbt) for:
  - literal-unreachable loop body collapse
  - branch-back loop preservation
- Verified with `moon test src/optimization/dead_code_elimination_wbtest.mbt`.

## Performance Impact

- Negligible. The rewrite inspects only the already-rewritten loop body.

## Next Work

- The next DCE slice is EH `try` / `try_table` handling.
- After that, land the branch-value and ancestor-propagation stress cases from the main research doc.
