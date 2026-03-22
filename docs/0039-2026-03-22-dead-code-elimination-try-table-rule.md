# DeadCodeElimination TryTable Rule

Status: completed the typed-IR EH half of Slice 7 from [`docs/0017-2026-03-22-dead-code-elimination.md`](/home/jtenner/Projects/starshine-mb/docs/0017-2026-03-22-dead-code-elimination.md). In this codebase the typed instruction surface currently exposes `try_table`, not a separate typed `try`, so this checkpoint covers the reachable `try_table` rule and leaves the later EH `pop` fixup follow-up for a later slice.

## Scope

Checkpoint the `try_table`-specific unreachable propagation rule:

- if the rewritten `try_table` body is unreachable, the `try_table` itself must become unreachable-equivalent
- keep the wrapper instead of replacing the whole node with the body

## Landed Behavior

- [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) now routes typed `try_table` nodes through a dedicated DCE helper.
- Concrete-result `try_table` nodes with an unreachable body now degrade to `void` while preserving the `try_table` wrapper and catch table.
- The local reachability helpers now treat `try_table` as unreachable whenever its rewritten body is unreachable, so parents like `drop` can observe the EH node as unreachable.

## Correctness Constraints

- `drop(try_table (result i32) ... unreachable)` must not remain a stale concrete-result `try_table`.
- DCE should keep the `try_table` wrapper in place instead of replacing the whole node with the body, matching the control-flow distinction documented in the research notes.
- This slice does not yet implement the later nested-`pop` block-fixup work from Binaryen because the current typed-IR test surface here does not expose a local `pop` producer path.

## Validation

- Added focused whitebox coverage in [`src/optimization/dead_code_elimination_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/dead_code_elimination_wbtest.mbt) for a concrete-result `try_table` under `drop` with an unreachable body.
- Verified with `moon test src/optimization/dead_code_elimination_wbtest.mbt`.

## Performance Impact

- Negligible. The new rule only inspects the already-rewritten `try_table` body.

## Next Work

- The next DCE slice is the branch-value and ancestor-propagation stress cases.
- After that, land the GC/reference-sensitive regressions and revisit the later EH `pop` fixup follow-up if the typed surface grows that path.
