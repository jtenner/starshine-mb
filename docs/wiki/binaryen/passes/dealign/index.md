---
kind: entity
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-dealign-primary-sources.md
  - ../../../raw/research/0317-2026-04-24-dealign-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0221-2026-04-21-dealign-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
  - ../alignment-lowering/index.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./align-one-rewrite-surface-and-alignment-lowering-split.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../alignment-lowering/index.md
  - ../tracker.md
supersedes:
  - ../../../raw/research/0221-2026-04-21-dealign-binaryen-research.md
---

# `dealign`

## Role

`dealign` is a public Binaryen pass that deliberately weakens selected memory-access alignment metadata to `1`.

In Starshine today it is **upstream-only**:

- it is not an active HotPass or ModulePass
- it is not boundary-only or removed in `src/passes/optimize.mbt`
- explicit requests therefore fail as an unknown pass name
- it is not part of the canonical no-DWARF `-O` / `-Os` path
- `agent-todo.md` has no dedicated `dealign` slice

## Why this dossier exists

The neighboring [`alignment-lowering`](../alignment-lowering/index.md) dossier needs a precise sibling contrast.
Without a `dealign` page, it is easy to blur two different jobs:

- `alignment-lowering` legalizes weakly aligned scalar loads/stores by splitting them into smaller aligned accesses
- `dealign` keeps the same access node and only weakens its alignment immediate

## Beginner summary

A beginner-safe prediction rule is:

- visit function-body memory access nodes covered by the pass
- if the node is a `Load`, `Store`, or `SIMDLoad`, set its alignment field to `1`
- leave offsets, widths, signedness, children, value flow, control flow, and memory contents unchanged

So this pass is best taught as **alignment-metadata normalization to `align=1`**, not as a legality pass or a generic memory optimizer.

## Corrected source-backed takeaways

Fresh 2026-04-24 source review corrected the older 2026-04-21 dossier text:

- The reviewed Binaryen `version_129` implementation is a function-parallel `WalkerPass<PostWalker<DeAlign>>`, not a manual module pass with an explicit `module->memory.exists()` bailout.
- It defines visitors for `Load`, `Store`, and `SIMDLoad`.
- The reviewed file does **not** define `visitSIMDStore`.
- Each visitor unconditionally assigns `curr->align = 1`; already-`align=1` accesses are unchanged only because the assignment is idempotent.
- The dedicated lit file visibly proves small scalar `i32.load` / `i32.store` examples with default, explicit `align=1`, and explicit `align=2` forms. SIMD support is source-confirmed but not separately isolated by that lit file.
- A narrow current-`main` spot check did not surface teaching-relevant drift from the tagged `version_129` behavior.

## Important constraints

`dealign` preserves:

- opcode family
- access width
- scalar load signedness
- offset
- pointer child
- stored value child
- result type
- trapping behavior of the access itself
- surrounding control flow

It does not directly rewrite:

- atomics
- bulk-memory instructions
- `memory.copy`, `memory.fill`, `memory.init`, or `data.drop`
- tables
- GC instructions
- address computations outside the access node
- scalar chunks or helper locals

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md) - Corrected Binaryen strategy: public registration, `WalkerPass` shape, exact visitor surface, and assignment-only semantics.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md) - Source/test map for `DeAlign.cpp`, `pass.cpp`, and `dealign.wast`, including the lit-vs-source proof split.
- [`./align-one-rewrite-surface-and-alignment-lowering-split.md`](./align-one-rewrite-surface-and-alignment-lowering-split.md) - Focused guide to the `align=1` rewrite surface and the corrected split from `alignment-lowering`.
- [`./wat-shapes.md`](./wat-shapes.md) - Beginner-friendly before/after catalog for scalar and source-confirmed SIMDLoad shapes plus no-op and non-goal families.
- [`./starshine-strategy.md`](./starshine-strategy.md) - Current Starshine status bridge: no registry spelling, unknown-pass rejection, no backlog slice, and future-port implications.

## Maintenance rule

Treat this folder as the canonical home for future `dealign` research. Treat [`../../../raw/research/0221-2026-04-21-dealign-binaryen-research.md`](../../../raw/research/0221-2026-04-21-dealign-binaryen-research.md) as historical and superseded for mechanics where it mentions a no-memory bailout, `SIMDStore`, an `align > 1` branch, or broad lit-backed scalar type coverage.

## Sources

- [`../../../raw/binaryen/2026-04-24-dealign-primary-sources.md`](../../../raw/binaryen/2026-04-24-dealign-primary-sources.md)
- [`../../../raw/research/0317-2026-04-24-dealign-primary-sources-and-starshine-followup.md`](../../../raw/research/0317-2026-04-24-dealign-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0221-2026-04-21-dealign-binaryen-research.md`](../../../raw/research/0221-2026-04-21-dealign-binaryen-research.md) - historical; superseded for the corrected mechanics above
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DeAlign.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dealign.wast>
- Current-`main` spot-check sources:
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/DeAlign.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/dealign.wast>
