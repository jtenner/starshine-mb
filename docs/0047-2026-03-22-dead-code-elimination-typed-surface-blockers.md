# DeadCodeElimination Typed Surface Blockers

## Scope

Record the current blocker state for the remaining `DeadCodeElimination`
research items that still depend on missing typed instruction surface.

## Current Repo Surface

The typed IR used by the landed DCE port currently exposes:

- `TTryTable`
- GC/reference instructions already covered by the Slice 9 commits
- typed string instructions, including the array-backed `string.new_*_array` and
  `string.encode_*_array` nodes landed in
  `docs/0050-2026-03-22-string-array-surface-for-dce.md`

It does not currently expose:

- typed EH `try` / `pop` nodes that would let the optimizer mirror Binaryen's
  nested-pop fixup behavior directly
- stack-switching instructions such as `resume` and `resume_throw`

## Consequence

The earlier string-sensitive DCE blocker is now closed: the local typed IR can
model the focused string array fixtures, and the `string.new_wtf16_array` /
`local.tee` regression is covered.

The remaining DCE blocker state is narrower. The unresolved follow-ups are
still blocked on missing EH `try` / `pop` and stack-switching instruction
surface, not on a known missing rewrite in the current optimizer
implementation.

That means no string-typed-surface blocker remains in this repo today. The
dependency-blocked backlog is now only the EH `pop` and stack-switching work.

## Follow-Up

- Reopen the EH `pop` fixup slice once typed EH `try` / `pop` support exists.
- Reopen the stack-switching slice once `resume` / `resume_throw` support
  exists.
