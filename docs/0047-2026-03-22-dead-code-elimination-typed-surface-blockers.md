# DeadCodeElimination Typed Surface Blockers

## Scope

Record the current blocker state for the remaining `DeadCodeElimination`
research items that still mention string-sensitive regressions and EH `pop`
fixups.

## Current Repo Surface

The typed IR used by the landed DCE port currently exposes:

- `TTryTable`
- GC/reference instructions already covered by the Slice 9 commits

It does not currently expose:

- typed string instructions such as `string.new_wtf16_array`
- typed EH `try` / `pop` nodes that would let the optimizer mirror Binaryen's
  nested-pop fixup behavior directly

## Consequence

The remaining DCE research bullets for string-sensitive regressions and EH
`pop` fixups are blocked on missing instruction surface, not on a known missing
rewrite in the current optimizer implementation.

That means the next actionable DCE work is pipeline interaction coverage for
the already-landed typed surface, while the string and EH follow-ups stay in
the backlog as dependency-blocked items.

## Follow-Up

- Reopen the string-sensitive DCE slices once typed string ops exist in the IR.
- Reopen the EH `pop` fixup slice once typed EH `try` / `pop` support exists.
