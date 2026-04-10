---
kind: entity
status: working
last_reviewed: 2026-04-10
sources:
  - ../../../raw/research/0076-2026-04-01-simplify-locals-binaryen-research-plan.md
  - ../../../../../src/passes/simplify_locals.mbt
  - ../../../../../src/passes/simplify_locals_test.mbt
  - ../../../../../src/passes/pass_manager.mbt
related:
  - ./wat-shapes.md
  - ./binaryen-strategy.md
  - ./starshine-hot-ir-strategy.md
  - ./implementation-map.md
  - ./effect-ordering-and-barriers.md
  - ./raw-lane-and-writeback.md
  - ./validation-and-signoff.md
  - ./performance-and-artifact-frontiers.md
  - ./parity.md
  - ../../no-dwarf-default-optimize-path.md
---

# `simplify-locals`

## Role

- `simplify-locals` is an active hot pass in Starshine's Binaryen namespace.
- The pass sits on the fault line between local sink parity, structured return rewriting, and artifact-scale no-op detection, so this folder needs more than one summary page.
- The pass is not just "remove dead locals." It is the main locals-traffic cleanup pass that decides when Starshine may:
  - replace a later `local.get` with an earlier producer
  - upgrade a multi-use producer into `local.tee`
  - rewrite blocks, `if`s, and loops to return values directly
  - canonicalize equivalent copied locals
  - erase lowered temporary locals after exact writeback
  - bypass artifact-shaped no-op families before hot lift

## Current Summary

- Binaryen treats `simplify-locals` as a staged locals optimizer with early no-structure variants and a later full structured pass.
- Starshine's in-tree work has focused first on the no-structure parity surface:
  - dead-set cleanup
  - sink and tee rewrites
  - equivalent-copy cleanup
  - exact writeback cleanup after lower
  - validator-heavy and builder-heavy raw-lane shortcuts for large artifact functions
- Full structured parity remains open work, but the implementation already carries meaningful structure-aware transforms, especially for block returns, one-armed `if`s, and loop fallthrough tails.
- The surrounding docs in this folder separate four different questions that were getting conflated in the old single-note layout:
  - which exact WAT patterns are supposed to change
  - which Binaryen strategy we are actually mimicking
  - how that strategy maps onto HOT IR and the raw lane
  - which parity and performance facts are durable enough to keep live

## Page Map

- [`./wat-shapes.md`](./wat-shapes.md) - Exact WAT-shaped families this pass transforms, declines to transform, or intentionally recognizes as raw-skip no-op families.
- [`./binaryen-strategy.md`](./binaryen-strategy.md) - Upstream stage breakdown, invalidation rules, and no-DWARF pipeline placement.
- [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md) - Current HOT-IR and raw-lane port strategy for the in-tree pass.
- [`./implementation-map.md`](./implementation-map.md) - Concrete map from the pass dossier to the actual helper clusters, rewrite entry points, and owning test files in tree.
- [`./effect-ordering-and-barriers.md`](./effect-ordering-and-barriers.md) - The barrier model that decides when pending locals may still commute past later code.
- [`./raw-lane-and-writeback.md`](./raw-lane-and-writeback.md) - The exact-instruction fallback path, raw rewrites, raw skips, and post-lower cleanup strategy.
- [`./validation-and-signoff.md`](./validation-and-signoff.md) - What each test lane proves, what it does not prove, and how to sign the pass off safely.
- [`./performance-and-artifact-frontiers.md`](./performance-and-artifact-frontiers.md) - Skip-reason taxonomy, artifact hotspot history, timer interpretation, and the current performance frontier.
- [`./parity.md`](./parity.md) - Current Binaryen parity status, retired artifact families, active frontiers, and known rejected ideas.

## Current Maintenance Rule

- Treat this folder as the canonical home for future simplify-locals parity notes.
- Add new simplify-locals material here only when it is durable enough to survive beyond one debugging session.
- Keep one-off reduction transcripts in `docs/wiki/raw/research/` or in the changelog; fold only the conclusions and stable examples back into this folder.
- When a new frontier is reduced, update:
  - [`./wat-shapes.md`](./wat-shapes.md) if the transformation family changed
  - [`./raw-lane-and-writeback.md`](./raw-lane-and-writeback.md) if the exact/raw split changed
  - [`./parity.md`](./parity.md) if the frontier or signoff state changed
