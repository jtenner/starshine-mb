---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-pick-load-signs-current-main-recheck.md
  - ../../../raw/research/0455-2026-05-05-pick-load-signs-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-22-pick-load-signs-primary-sources.md
  - ../../../raw/research/0136-2026-04-20-pick-load-signs-binaryen-research.md
  - ../../../raw/research/0228-2026-04-21-pick-load-signs-implementation-followup.md
  - ../../../raw/research/0244-2026-04-22-pick-load-signs-primary-sources-and-code-map-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/pick_load_signs.mbt
  - ../../../../../src/passes/pick_load_signs_test.mbt
  - ../../../../../src/passes/perf_test.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./parity.md
  - ./starshine-hot-ir-strategy.md
  - ../../no-dwarf-default-optimize-path.md
  - ../heap-store-optimization/index.md
  - ../optimize-instructions/index.md
  - ../precompute/index.md
---

# Starshine Strategy For `pick-load-signs`

Use this page together with [`./binaryen-strategy.md`](./binaryen-strategy.md), [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md), [`./wat-shapes.md`](./wat-shapes.md), [`./parity.md`](./parity.md), and the deeper local implementation note in [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md).

This page is the concise status-and-code-map layer for the current Starshine pass. It does **not** re-explain upstream Binaryen; it tells you where the active local pass lives, how it is wired, and where the current Starshine contract diverges from upstream.

## Current local status

`pick-load-signs` is an **active hot pass** in Starshine.
The registry surface in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) exposes it with the summary:

- `Pick narrower signed/unsigned load opcodes based on local use extension evidence.`

The active descriptor in [`../../../../../src/passes/pick_load_signs.mbt`](../../../../../src/passes/pick_load_signs.mbt) requires `use_def` and invalidates the same broad hot analyses the pass rewrites can disturb.

A 2026-05-05 current-main bridge recheck of upstream Binaryen found no teaching-relevant drift on the reviewed surfaces, so the only standing divergence to keep explicit here is the broader local i64 HOT surface.

That means the local pass is not a stub or removed-name alias.
It is a real HOT pass with a dedicated MoonBit owner file, tests, and replay lanes.

## Exact local code map

### Registry and preset placement

- [`src/passes/optimize.mbt:203-206`](../../../../../src/passes/optimize.mbt)
  - registers `pick-load-signs` as a hot pass
- [`src/passes/optimize.mbt:289-301`](../../../../../src/passes/optimize.mbt)
  - places it in the default `optimize` / `shrink` hot preset after `heap-store-optimization` and before `precompute`
- [`src/passes/optimize.mbt:443-460`](../../../../../src/passes/optimize.mbt)
  - keeps the same ordering in the preset builder helpers

### Pass-manager integration

- [`src/passes/pass_manager.mbt:7289-7302`](../../../../../src/passes/pass_manager.mbt)
  - raw HOT scan helper for `pick-load-signs`
- [`src/passes/pass_manager.mbt:8099-8103`](../../../../../src/passes/pass_manager.mbt)
  - raw skip path for `no-pick-load-signs-candidates`
- [`src/passes/pass_manager.mbt:8990-8994`](../../../../../src/passes/pass_manager.mbt)
  - module-pass dispatcher entry that calls `pick_load_signs_run(...)`

### Owner file and proof lanes

- [`src/passes/pick_load_signs.mbt:2-20`](../../../../../src/passes/pick_load_signs.mbt)
  - descriptor and summary
- [`src/passes/pick_load_signs.mbt:732-763`](../../../../../src/passes/pick_load_signs.mbt)
  - scan / analyze / rewrite driver
- [`src/passes/pick_load_signs_test.mbt:2-169`](../../../../../src/passes/pick_load_signs_test.mbt)
  - focused pass tests for the real local behavior
- [`src/passes/perf_test.mbt:6324-6409`](../../../../../src/passes/perf_test.mbt)
  - raw-skip and skip-aggregation coverage
- [`src/passes/registry_test.mbt:32-33`](../../../../../src/passes/registry_test.mbt)
  - registry category coverage
- [`src/passes/registry_test.mbt:175-176`](../../../../../src/passes/registry_test.mbt)
  - descriptor name and required HOT analysis coverage
- [`src/passes/registry_test.mbt:204-214`](../../../../../src/passes/registry_test.mbt)
  - preset ordering coverage
- [`src/cmd/cmd_wbtest.mbt:7017-7050`](../../../../../src/cmd/cmd_wbtest.mbt)
  - CLI replay coverage on the debug artifact
- [`src/cmd/cmd_wbtest.mbt:7058-7067`](../../../../../src/cmd/cmd_wbtest.mbt)
  - generated-artifact replay lane for the neighboring slot proof surface

## How the current local pass works

The current Starshine implementation is a HOT/use-def pass, not an AST visitor pass.
It scans exact local writes, analyzes read sites, and rewrites the narrowed load opcode when the local evidence is complete enough.

That yields two important local properties:

1. the pass is integrated with Starshine's existing HOT analysis stack
2. the pass is broader than upstream Binaryen on the i64 signedness surface

## The important Starshine divergence

Upstream Binaryen `version_129` `pick-load-signs` is effectively i32-only.
Current Starshine `pick-load-signs` recognizes i64 extension / mask / shift-pair families too.

That is a standing local divergence, not something to accidentally smooth over.
If future work wants strict upstream parity, this page and [`./parity.md`](./parity.md) should be updated together.

## How this page relates to the deeper HOT note

Use this page to answer:

- is the pass active?
- where is it wired?
- what are the exact local code anchors?
- where does local behavior diverge from upstream?

Use [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md) when you need the deeper rewrite narrative, raw fast-skip behavior, or detailed HOT/use-def mechanics.

## Maintenance rule

Keep the concise strategy page and the deeper HOT note in sync:

- both should point at the same active registry and dispatcher surfaces
- both should keep the upstream-vs-local i64 difference explicit
- both should keep the current `no-pick-load-signs-candidates` raw-skip behavior visible
- both should stay linked to the same local tests and replay lanes
