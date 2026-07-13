---
kind: research
status: current
created: 2026-07-12
sources:
  - ../../binaryen/no-dwarf-default-optimize-path.md
  - ../../binaryen/passes/reorder-locals/index.md
  - ../../binaryen/passes/reorder-locals/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/coalesce-locals/index.md
  - ../../binaryen/passes/coalesce-locals/starshine-port-readiness-and-validation.md
  - ./1401-2026-07-02-reorder-locals-o4z-closeout.md
  - ./0550-2026-05-08-coalesce-locals-ordered-slot-replay.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/optimize_test.mbt
---

# `reorder-locals` public preset scheduling

## Question

Now that the direct `reorder-locals` audit is closed and the late `reorder-locals -> coalesce-locals -> reorder-locals` neighborhood already has ordered-slot proof, should public `optimize` / `shrink` still claim only the early tuple/no-structure `reorder-locals` slot?

## Source-backed answer

No.

For the current local `version_130` Binaryen oracle, the canonical no-DWARF function pipeline still uses three `reorder-locals` slots:

1. `tuple-optimization -> simplify-locals-nostructure -> vacuum -> reorder-locals -> remove-unused-brs`
2. `... -> simplify-locals -> vacuum -> reorder-locals -> coalesce-locals`
3. `... -> coalesce-locals -> reorder-locals -> vacuum`

The direct `reorder-locals` O4Z closeout already removed pass-owner uncertainty for the standalone sorter. The missing question was scheduler evidence.

That evidence is already in-tree:

- `docs/wiki/raw/research/0550-2026-05-08-coalesce-locals-ordered-slot-replay.md` proves the exact `reorder-locals -> coalesce-locals -> reorder-locals` neighborhood in tests and on the checked-in debug artifact under representation-stable comparison.
- `docs/wiki/binaryen/passes/coalesce-locals/index.md` and `.../starshine-port-readiness-and-validation.md` treat both exact `coalesce-locals` neighborhoods as covered, not speculative.
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md` and the simplify-locals scheduler docs keep the late local-cleanup cluster explicit: `simplify-locals -> vacuum -> reorder-locals -> coalesce-locals -> reorder-locals -> vacuum`.

So the stale policy was no longer "safe conservatism". It had become a documented scheduler underclaim relative to already-proven neighboring behavior.

## Local change made

Public `optimize` and `shrink` now schedule the Binaryen-shaped `reorder-locals` count and late cluster that the repo already had evidence for:

```text
code-pushing -> tuple-optimization -> simplify-locals-nostructure -> vacuum -> reorder-locals -> remove-unused-brs
...
local-subtyping -> coalesce-locals -> local-cse -> simplify-locals -> vacuum -> reorder-locals -> coalesce-locals -> reorder-locals -> vacuum -> merge-blocks
```

This lands:

- the second public `reorder-locals` slot after `simplify-locals -> vacuum`
- the third public `reorder-locals` slot after the later `coalesce-locals`
- the matching late `vacuum` boundaries around that reorder/coalesce cluster

## Tests updated

`src/passes/optimize_test.mbt` now locks the live preset policy in three ways:

1. `tuple-optimization exact preset prereqs place code-pushing before the tuple slot`
   - keeps the early lane stable
2. `optimize and shrink presets schedule Binaryen-shaped reorder-locals cleanup slots`
   - asserts three public `reorder-locals` occurrences with the expected neighbors
3. `optimize and shrink presets keep the late simplify-locals reorder sandwich together`
   - locks the late `simplify-locals -> vacuum -> reorder-locals -> coalesce-locals -> reorder-locals -> vacuum` cluster

## What this does **not** claim

This change does **not** close all remaining public-preset gaps against Binaryen's full no-DWARF path.

The remaining preset-behavior owners still include the separate documented gaps in:

- the second pre-pass `remove-unused-module-elements` slot
- `code-folding`
- `redundant-set-elimination`
- the extra Starshine `remove-unused-brs` slot

Those remain under `[O4Z-PRESET-BEHAVIOR]`.

## Conclusion

Starshine should no longer document `reorder-locals` as a one-slot public preset pass.

The direct pass is closed, the late reorder/coalesce neighborhood already had ordered-slot proof, and public presets can now honestly claim the Binaryen-shaped three-slot `reorder-locals` schedule inside the currently implemented local-cleanup neighborhood.
