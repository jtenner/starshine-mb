---
kind: concept
status: supported
last_reviewed: 2026-05-04
sources:
  - ../../../raw/binaryen/2026-05-04-tuple-optimization-current-main-recheck.md
  - ../../../raw/research/0434-2026-05-04-tuple-optimization-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-22-tuple-optimization-primary-sources.md
  - ../../../raw/research/0254-2026-04-22-tuple-optimization-primary-sources-and-code-map-followup.md
  - ../../../raw/research/0239-2026-04-21-tuple-optimization-starshine-code-map-followup.md
  - ../../../raw/research/0144-2026-04-20-tuple-optimization-binaryen-research.md
  - ../../../../../src/passes/tuple_optimization.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/passes/tuple_optimization_wbtest.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../../src/cmd/cmd_native_wbtest.mbt
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./scheduler-and-gates.md
  - ./implementation-map.md
  - ./parity.md
  - ./reduced-repros-and-evidence.md
  - ../../no-dwarf-default-optimize-path.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./scheduler-and-gates.md
  - ./implementation-map.md
  - ./parity.md
  - ./reduced-repros-and-evidence.md
  - ../../no-dwarf-default-optimize-path.md
---

# Starshine `tuple-optimization` strategy

Use this page together with [`./binaryen-strategy.md`](./binaryen-strategy.md), [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md), [`./wat-shapes.md`](./wat-shapes.md), [`./scheduler-and-gates.md`](./scheduler-and-gates.md), and [`./implementation-map.md`](./implementation-map.md). The upstream contract is still the small Binaryen tuple-local scalarization pass; this page shows how the in-tree Starshine port implements that contract and where to follow the exact code.

## Current Starshine status

`tuple-optimization` is an **active direct hot pass** in Starshine.

The exact local status is:

- the pass is registered in [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- the pass manager dispatches it in [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- the explicit pass is accepted by the CLI and compare harness in [`src/cmd/cmd_wbtest.mbt`](../../../../../src/cmd/cmd_wbtest.mbt)
- the native Binaryen-oracle lane is covered in [`src/cmd/cmd_native_wbtest.mbt`](../../../../../src/cmd/cmd_native_wbtest.mbt)
- the pass stays out of the public `optimize` and `shrink` presets until the exact Binaryen neighborhood is represented honestly in-tree

So the current strategy is:

- keep the direct pass active
- keep the preset boundary honest
- keep the code map readable enough that a future preset-slot proof can reuse the same implementation without guessing

## How the Starshine port works

Starshine does **not** try to model Binaryen's WAT-pass internals literally.
It ports the same semantic idea onto HOT IR:

1. find exact spill / copy bridges with multivalue result arity greater than one
2. require the whole copy-connected component to stay inside the approved surface
3. split good tuple locals into fresh scalar locals
4. preserve tee semantics and host-lane yield values explicitly
5. run cleanup so the rewritten body stays valid and the later local-cleanup passes can finish the job

The important local distinction is that Starshine is working on lowered HOT structures, not on raw Binaryen AST nodes.
That is why the implementation has extra helper clusters for host-lane recovery, root-slot selection, carrier construction, and post-rewrite cleanup.

## Exact Starshine code map

The full line map is in [`./implementation-map.md`](./implementation-map.md). The shortest useful read-along path is:

- [`src/passes/tuple_optimization.mbt:97-114`](../../../../../src/passes/tuple_optimization.mbt#L97-L114)
  - active pass descriptor and summary
- [`src/passes/tuple_optimization.mbt:134-241`](../../../../../src/passes/tuple_optimization.mbt#L134-L241)
  - seed-group discovery and local ownership setup
- [`src/passes/tuple_optimization.mbt:1901-1935`](../../../../../src/passes/tuple_optimization.mbt#L1901-L1935)
  - analysis entry points
- [`src/passes/tuple_optimization.mbt:1955-2676`](../../../../../src/passes/tuple_optimization.mbt#L1955-L2676)
  - rewrite planning, rewrite masks, and split-local allocation
- [`src/passes/tuple_optimization.mbt:2684-3564`](../../../../../src/passes/tuple_optimization.mbt#L2684-L3564)
  - root-slot discovery and carrier builders
- [`src/passes/tuple_optimization.mbt:3628-5268`](../../../../../src/passes/tuple_optimization.mbt#L3628-L5268)
  - concrete rewrite entry points, cleanup, and top-level run
- [`src/passes/optimize.mbt:407-431`](../../../../../src/passes/optimize.mbt#L407-L431)
  - exact-slot prereq helper and the explicit preset omission rule
- [`src/passes/pass_manager.mbt:7938-7946`](../../../../../src/passes/pass_manager.mbt#L7938-L7946)
  - debug trace hook that prints tuple groups and the rewrite mask
- [`src/passes/pass_manager.mbt:8699`](../../../../../src/passes/pass_manager.mbt#L8699)
  - active hot-pass dispatcher arm
- [`src/passes/registry_test.mbt:137,172-235`](../../../../../src/passes/registry_test.mbt#L137-L235)
  - registry category and direct-pass acceptance tests
- [`src/passes/tuple_optimization_wbtest.mbt:120-1109`](../../../../../src/passes/tuple_optimization_wbtest.mbt#L120-L1109)
  - focused analysis, rewrite, and evidence families
- [`src/cmd/cmd_wbtest.mbt:1998-2369`](../../../../../src/cmd/cmd_wbtest.mbt#L1998-L2369)
  - explicit CLI acceptance and lowered-module validity coverage
- [`src/cmd/cmd_native_wbtest.mbt:404-1281`](../../../../../src/cmd/cmd_native_wbtest.mbt#L404-L1281)
  - direct Binaryen compare lane for the committed tuple families

## What the Starshine port is trying to preserve

- good tuple components should scalarize into fresh locals
- bad components should poison together if any member escapes the approved surface
- tuple tees should keep yielding the correct lane value
- copy-connected groups should stay readable in the lowered artifact
- later local cleanup should be able to see scalar lanes, not one opaque tuple bundle

That is the real Starshine analog of the upstream Binaryen pass.

## What Starshine intentionally does **not** claim here

This page should not be read as saying Starshine has the full Binaryen scheduler story already.
It does **not** claim:

- public preset slot parity
- a generic multivalue optimizer
- CFG / dominance / effects / liveness ownership inside this pass
- a separate module-pass implementation path
- a different upstream contract from the one taught in [`./binaryen-strategy.md`](./binaryen-strategy.md)

The current pass is direct and active; the preset question stays separate.

## Validation story

Use the pair of oracle-facing pages for the current evidence picture:

- [`./parity.md`](./parity.md) for direct native and compare status
- [`./reduced-repros-and-evidence.md`](./reduced-repros-and-evidence.md) for the reduced families that currently justify the port

The practical validation ladder is still:

1. focused white-box analysis / rewrite tests
2. command-surface validity checks
3. native Binaryen compare lanes
4. full artifact replay only after the neighborhood story is honest

## Bottom line

Starshine `tuple-optimization` is a narrow active HOT scalarization port with a clear preset boundary.
The code is already in-tree, the relevant oracle lanes are already green, and the missing work is not “what does the pass mean?” but “when can the exact Binaryen slot be represented honestly in presets?”
