---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-04-27-dataflow-optimization-port-readiness-primary-sources.md
  - ../../../raw/research/0423-2026-04-27-dataflow-optimization-port-readiness.md
  - ../../../raw/binaryen/2026-05-05-dataflow-optimization-current-main-recheck.md
  - ../../../raw/research/0446-2026-05-05-dataflow-optimization-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-23-dataflow-optimization-primary-sources.md
  - ../../../raw/research/0278-2026-04-23-dataflow-optimization-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0178-2026-04-21-dataflow-optimization-binaryen-research.md
related:
  - ./binaryen-strategy.md
  - ./flat-ir-dataflow-ir-and-boundaries.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
---

# Implementation structure and tests for `dataflow-optimization` / `dfo`

Use this page together with the raw primary-source manifests in [`../../../raw/binaryen/2026-04-23-dataflow-optimization-primary-sources.md`](../../../raw/binaryen/2026-04-23-dataflow-optimization-primary-sources.md), [`../../../raw/binaryen/2026-04-27-dataflow-optimization-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-27-dataflow-optimization-port-readiness-primary-sources.md), and [`../../../raw/binaryen/2026-05-05-dataflow-optimization-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-dataflow-optimization-current-main-recheck.md).
On 2026-04-23 the reviewed official Binaryen `version_129` release page still showed publish date **2026-04-01**. The 2026-04-25, 2026-04-27, and 2026-05-05 current-`main` rechecks did not surface teaching-relevant drift beyond the owner/test surface described here. For Starshine test sequencing, see [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

## Core pass file

### `src/passes/DataFlowOpts.cpp`

This is the actual pass implementation.
It proves all of the core contract documented in this folder:

- public role: optimize using DataFlow SSA IR
- hard precondition: call `Flat::verifyFlatness(func)` first
- scope: function-parallel walker pass
- build step: create `graph` plus `nodeUsers`
- optimization loop: work through `workLeft`
- rewrite family 1: identical-input phi collapse
- rewrite family 2: all-constant expression folding through nested `precompute`
- writeback rule: update underlying flattened wasm expression children when replacing users

This file is also the main reason the pass is easy to mis-teach:
its implementation is much smaller than the name suggests.

## Registration surface

### `src/passes/pass.cpp`

This file registers the upstream public CLI name:

- `dfo`

with the description:

- `optimizes using the DataFlow SSA IR`

That matters because Starshine's local registry currently uses the descriptive spelling:

- `dataflow-optimization`

A future local implementation should keep the alias split explicit instead of silently pretending the upstream public name is also the local one.

## Flatness dependency

### `src/ir/flat.h`

This is the key prerequisite file.
It documents the Flat IR model that `dfo` requires.

The pass depends on it in two ways:

- conceptually: flattened code is the intended input form
- mechanically: `DataFlowOpts.cpp` verifies flatness before doing any work

Without understanding `flat.h`, it is easy to overgeneralize `dfo` into a pass that can run on ordinary tree-shaped IR.
That would be a different contract.

## DataFlow helper files

### `src/dataflow/node.h`

This file defines the graph node vocabulary:

- `Var`
- `Expr`
- `Phi`
- `Cond`
- `Block`
- `Zext`
- `Bad`

It also shows that:

- `Expr` reuses real Binaryen expressions
- some nodes have no direct wasm-origin expression
- equality on nodes is structural for many node kinds
- comparison-like operations conceptually return `i1` in this side IR

This file is the best source for the statement that `dfo` is not a full replacement IR.
It is a narrow side graph.

### `src/dataflow/graph.h`

This file is the real analysis engine.
It proves:

- relevant-type filtering is integer-focused
- params begin as `Var`, non-param relevant locals as zero
- structured control flow is modeled through merged local states
- unsupported instructions degrade to `Var` or `Bad`
- loops intentionally avoid ordinary loop phis and instead use unknown loop-entry vars
- only a narrow unary/binary/select subset is represented precisely
- EH is explicitly unsupported

If someone wants to know what the pass can really "see," this is the file that answers that question.

### `src/dataflow/users.h`

This file builds and maintains the graph user relation.
It proves that the pass is designed around:

- counting uses
- skipping dead graph nodes
- updating users when replacements happen
- re-propagating simplifications through the worklist

### `src/dataflow/utils.h`

This file supplies small but crucial predicates such as:

- `allInputsIdentical(...)`
- `allInputsConstant(...)`

Those helpers explain the real rewrite surface precisely.
The pass is not using a big abstract lattice.
It is using small, direct graph predicates.

## Representative shipped test surface

### `test/lit/passes/flatten_simplify-locals-nonesting_dfo_O3.wast`

This is the most important reviewed test surface for `dfo`.
It is a combo file, not a pure isolated `dfo.wast`, but it still teaches a lot:

- `dfo` is used in a real flatten-era aggressive sequence
- the intended pipeline is `flatten -> simplify-locals-nonesting -> dfo -> ordinary optimization`
- some visible wins require neighboring flatten-era passes, not `dfo` alone
- the output still expects later cleanup rather than claiming `dfo` finishes the job by itself

This test is also valuable because it prevents a bad teaching shortcut.
The pass is not just "run dfo on arbitrary code." It is a shaped pipeline tool.

## What the absence of a dedicated pure lit file means

During this review I did **not** find a dedicated standalone `dfo.wast` in the official `version_129` lit roster.
That is itself a useful fact.

It suggests:

- upstream treats `dfo` partly as a pipeline component rather than a heavily isolated pass surface
- the combo test is legitimate evidence, not just a weak fallback
- future local docs should keep scheduler context visible instead of pretending the pass lives in isolation

## Freshness check against current `main`

The 2026-05-05 current-main recheck in [`../../../raw/binaryen/2026-05-05-dataflow-optimization-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-dataflow-optimization-current-main-recheck.md) covered the same implementation, helper, registration, flat-IR, and combo-lit surfaces.

Durable result:

- `DataFlowOpts.cpp` still presents `dfo` as a flat-input DataFlow SSA IR pass and retains the same two rewrite families
- `graph.h` still owns the integer relevance filter, unsupported-value degradation, EH unsupported boundary, and loop-precision cutoff
- `pass.cpp` still registers public upstream spelling `dfo`
- `flatten_simplify-locals-nonesting_dfo_O3.wast` remains the main visible combo-pipeline proof surface

So the documented behavior here is not sitting on a known current-main semantic drift.

## Test-to-behavior map

| Source | Main lesson |
| --- | --- |
| `DataFlowOpts.cpp` | hard flatness gate, worklist, real rewrite families |
| `pass.cpp` | public CLI name is `dfo` |
| `flat.h` | why flat input is required |
| `node.h` | side-IR node vocabulary and synthetic SSA helpers |
| `graph.h` | relevant-type filter, control-flow merges, loop boundary, supported op subset |
| `users.h` | user tracking and replacement propagation |
| `utils.h` | exact helper predicates that define the narrow optimization surface |
| `flatten_simplify-locals-nonesting_dfo_O3.wast` | real aggressive combo-pipeline role and visible shape expectations |

## What a future Starshine port should treat as canonical

If implementing this pass locally, the highest-value source order is:

1. `DataFlowOpts.cpp`
2. `graph.h`
3. `node.h`
4. `users.h`
5. `utils.h`
6. `flat.h`
7. `pass.cpp`
8. `flatten_simplify-locals-nonesting_dfo_O3.wast`

That order mirrors the real contract:

- required input shape
- side-IR design
- real supported subset
- actual rewrite logic
- real usage context

## Sources

- [`../../../raw/binaryen/2026-04-27-dataflow-optimization-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-27-dataflow-optimization-port-readiness-primary-sources.md)
- [`../../../raw/research/0423-2026-04-27-dataflow-optimization-port-readiness.md`](../../../raw/research/0423-2026-04-27-dataflow-optimization-port-readiness.md)
- [`../../../raw/binaryen/2026-05-05-dataflow-optimization-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-dataflow-optimization-current-main-recheck.md)
- [`../../../raw/research/0446-2026-05-05-dataflow-optimization-current-main-recheck.md`](../../../raw/research/0446-2026-05-05-dataflow-optimization-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-25-dataflow-optimization-current-main-recheck.md`](../../../raw/binaryen/2026-04-25-dataflow-optimization-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-23-dataflow-optimization-primary-sources.md`](../../../raw/binaryen/2026-04-23-dataflow-optimization-primary-sources.md)
- [`../../../raw/research/0278-2026-04-23-dataflow-optimization-primary-sources-and-starshine-followup.md`](../../../raw/research/0278-2026-04-23-dataflow-optimization-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0178-2026-04-21-dataflow-optimization-binaryen-research.md`](../../../raw/research/0178-2026-04-21-dataflow-optimization-binaryen-research.md)
