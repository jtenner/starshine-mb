# 0472 - `merge-blocks` current-main anchor recheck

- **Date:** 2026-05-05
- **Pass:** `merge-blocks`
- **Scope:** refresh the living `merge-blocks` dossier after the 2026-05-04 source-correction refresh and repair stale local line anchors in the Starshine code-map pages.
- **Status:** corrective research note; use with [`../binaryen/2026-05-05-merge-blocks-current-main-anchor-recheck.md`](../binaryen/2026-05-05-merge-blocks-current-main-anchor-recheck.md)

## What changed

A fresh review of the official Binaryen current-main `merge-blocks` surfaces showed no semantic drift from the existing source-backed contract.

What did change was the local documentation layer: several line-number references in the Starshine strategy / implementation pages no longer matched the current `src/passes/*.mbt` layout.

## Durable conclusion

`merge-blocks` still teaches the same upstream story:

- merge safe child blocks into their parent block list;
- merge safe loop tails;
- move safe work out of `drop(block ...)`, `if` conditions, and `throw` operands;
- refinalize after edits;
- keep `ProblemFinder` in the dropped-block cleanup path, not in a label-retargeting story.

The wiki fix is therefore a reference-hygiene update, not a semantic correction.

## Files refreshed

- `docs/wiki/binaryen/passes/merge-blocks/index.md`
- `docs/wiki/binaryen/passes/merge-blocks/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/merge-blocks/wat-shapes.md`
- `docs/wiki/binaryen/passes/merge-blocks/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/merge-blocks/starshine-strategy.md`
- `docs/wiki/binaryen/passes/merge-blocks/starshine-hot-ir-strategy.md`
- `docs/wiki/index.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`

## Primary source

- [`../binaryen/2026-05-05-merge-blocks-current-main-anchor-recheck.md`](../binaryen/2026-05-05-merge-blocks-current-main-anchor-recheck.md)
