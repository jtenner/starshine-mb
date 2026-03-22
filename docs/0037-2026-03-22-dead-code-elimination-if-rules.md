# DeadCodeElimination If Rules

Status: completed Slice 5 from [`docs/0017-2026-03-22-dead-code-elimination.md`](/home/jtenner/Projects/starshine-mb/docs/0017-2026-03-22-dead-code-elimination.md). `DeadCodeElimination` now applies the two Binaryen-style `if` rewrites that were still missing from the typed runner.

## Scope

Checkpoint the `if`-specific control-flow rules:

- replace the whole `if` when the condition itself is unreachable
- treat a two-arm `if` with both arms unreachable as an unreachable-equivalent expression while keeping the condition in place

## Landed Behavior

- [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) now routes typed `if` nodes through a dedicated DCE helper.
- If the rewritten condition is unreachable, DCE now returns the condition directly and discards both arms.
- If both arms are unreachable and an `else` exists, DCE now rewrites the `if` to the local unreachable-equivalent form:
  - concrete result types degrade to `void`
  - the condition stays in place because it still executes
- The local reachability helpers now recognize both of those `if` outcomes, so parents like `drop` and enclosing expression lists can treat the rewritten `if` as unreachable.

## Correctness Constraints

- `drop(if (result i32) unreachable then ... else ...)` must become the unreachable condition, not a still-typed `if`.
- `drop(if (result i32) cond then unreachable else unreachable)` must keep the condition but stop pretending the `if` can still produce an `i32`.
- `if` without an `else` is not covered by the both-arms rule because the false path can still fall through.

## Validation

- Added focused whitebox coverage in [`src/optimization/dead_code_elimination_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/dead_code_elimination_wbtest.mbt) for:
  - unreachable-condition replacement
  - both-arms-unreachable propagation through a parent `drop`
- Verified with `moon test src/optimization/dead_code_elimination_wbtest.mbt`.

## Performance Impact

- Negligible. The new logic is local to typed `if` nodes and reuses the existing reachability helpers.

## Next Work

- Slice 6 is still next: replace loops whose rewritten body is the literal unreachable node and leave other loops alone.
- After that, land the EH `try` / `try_table` rules from the main research doc.
