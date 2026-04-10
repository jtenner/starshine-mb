---
kind: entity
status: supported
last_reviewed: 2026-04-10
sources:
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/registry_test.mbt
related:
  - ../no-dwarf-default-optimize-path.md
---

# Binaryen Pass Folder Map

## Scope

- This page is the namespace catalog for active implemented pass folders under `docs/wiki/binaryen/passes/`.
- Treat each pass folder as the stable home for:
  - `wat-shapes.md` when the pass is meaningfully shape-driven
  - `binaryen-strategy.md`
  - `starshine-hot-ir-strategy.md`
  - pass-specific notes, decisions, or parity pages

## Active Module Passes

- [`duplicate-function-elimination/index.md`](duplicate-function-elimination/index.md) - Expanded folder with overview, shapes, Binaryen strategy, Starshine strategy, metadata and type-compaction notes, and parity status.
- [`remove-unused-module-elements/index.md`](remove-unused-module-elements/index.md) - Expanded folder with overview, shapes, Binaryen strategy, Starshine strategy, retention and rewrite rules, and parity status.
- [`memory-packing/index.md`](memory-packing/index.md) - Scaffolded folder for future memory-packing research and strategy notes.
- [`once-reduction/index.md`](once-reduction/index.md) - Scaffolded folder for future once-reduction research and strategy notes.
- [`global-refining/index.md`](global-refining/index.md) - Scaffolded folder for future global-refining research and strategy notes.
- [`global-struct-inference/index.md`](global-struct-inference/index.md) - Folder now has a landing page plus the existing parity note.
- [`reorder-locals/index.md`](reorder-locals/index.md) - Folder now has a landing page plus parity and multivalue-call scope notes.

## Active Hot Passes

- [`ssa-nomerge/index.md`](ssa-nomerge/index.md) - Folder now has a landing page plus the current parity note for the remaining debug-artifact validation blocker.
- [`vacuum/index.md`](vacuum/index.md) - Scaffolded folder for future vacuum research and strategy notes.
- [`dead-code-elimination/index.md`](dead-code-elimination/index.md) - Scaffolded folder for future DCE research and strategy notes.
- [`remove-unused-names/index.md`](remove-unused-names/index.md) - Folder now has a landing page plus the current parser-gap note.
- [`remove-unused-brs/index.md`](remove-unused-brs/index.md) - Folder now has a landing page plus parity and returned-ladder shape notes.
- [`optimize-instructions/index.md`](optimize-instructions/index.md) - Scaffolded folder for future optimize-instructions research and strategy notes.
- [`heap-store-optimization/index.md`](heap-store-optimization/index.md) - Scaffolded folder for future heap-store-optimization research and strategy notes.
- [`heap2local/index.md`](heap2local/index.md) - Folder now has a landing page plus the current parity note.
- [`pick-load-signs/index.md`](pick-load-signs/index.md) - Folder now has a landing page plus the current parity note.
- [`tuple-optimization/index.md`](tuple-optimization/index.md) - Expanded folder with WAT shapes, Binaryen strategy, Starshine HOT-native strategy, scheduler and feature-gate notes, reduced repro tracking, and current parity status.
- [`precompute/index.md`](precompute/index.md) - Scaffolded folder for future precompute research and strategy notes.
- [`simplify-locals/index.md`](simplify-locals/index.md) - Scaffolded folder for future simplify-locals research and strategy notes.

## Current Maintenance Rule

- Every implemented pass should now have a stable folder landing page, even when detailed subpages are still missing.
- Expand folders from scaffold to full multi-entry form in priority order, starting from passes that already have artifact parity work or active backlog slices.
