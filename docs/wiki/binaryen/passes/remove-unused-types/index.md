---
kind: entity
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-remove-unused-types-primary-sources.md
  - ../../../raw/research/0298-2026-04-24-remove-unused-types-source-correction-and-starshine-followup.md
  - ../../../raw/research/0149-2026-04-21-remove-unused-types-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/wast/parser.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../../../src/validate/env.mbt
  - ../tracker.md
  - ../index.md
  - ../late-pipeline-dispatch.md
  - ../global-refining/binaryen-strategy.md
  - ../global-struct-inference/binaryen-strategy.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./closed-world-visibility-and-rec-group-rewrite.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../tracker.md
  - ../index.md
  - ../global-refining/index.md
  - ../global-struct-inference/index.md
  - ../type-merging/index.md
  - ../unsubtyping/index.md
---

# `remove-unused-types`

## Role

`remove-unused-types` is an upstream Binaryen **closed-world GC module pass**.

In current Starshine it is **unimplemented** and kept as a boundary-only registry name in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).
There is no `src/passes/remove_unused_types.mbt` owner file today.

A good beginner summary is:

- Binaryen removes private heap types that are no longer used,
- keeps public type groups as external-boundary anchors,
- rebuilds the surviving private heap types into a fresh private rec-group layout with dependency ordering,
- and rewrites every module-wide type use through the new mapping.

So this pass is not just type-section garbage collection.
It is **closed-world private heap-type cleanup plus whole-module heap-type rewriting**.

## 2026-04-24 source correction

The older research note [`../../../raw/research/0149-2026-04-21-remove-unused-types-binaryen-research.md`](../../../raw/research/0149-2026-04-21-remove-unused-types-binaryen-research.md) is useful history, but its phase-by-phase algorithm reading is now superseded.

The corrected source reading from [`../../../raw/binaryen/2026-04-24-remove-unused-types-primary-sources.md`](../../../raw/binaryen/2026-04-24-remove-unused-types-primary-sources.md) is:

- `RemoveUnusedTypes.cpp` itself only:
  - requires GC,
  - fatally rejects explicit open-world execution,
  - and calls `GlobalTypeRewriter(*module).update()`.
- The pass file does **not** directly:
  - check `optimizeLevel >= 2`,
  - collect `publicTypes` with a pass-local call,
  - define a custom used-type scanner,
  - build a pass-local private `Builder`,
  - or copy whole old rec groups by hand.
- The scheduler in `pass.cpp` still places the pass only in the closed-world GC/type optimization neighborhood under broader optimization-level gating.
- `GlobalTypeRewriter` in `type-updating.h` owns the real mechanics.

This correction changes the teaching emphasis:

- old explanation: keep each live private type's whole old rec group
- corrected explanation: collect used private heap types, sort them by private dependency constraints, rebuild surviving private types into a new private group while preserving public groups as anchors, then remap the module

## Why this pass matters

- It is already named in Starshine's boundary-only registry, so the wiki needs a local status bridge rather than treating it as an upstream curiosity.
- Existing GC/type pages such as [`../global-refining/index.md`](../global-refining/index.md), [`../global-struct-inference/index.md`](../global-struct-inference/index.md), [`../type-merging/index.md`](../type-merging/index.md), and [`../unsubtyping/index.md`](../unsubtyping/index.md) all sit near the same closed-world type-graph problem space.
- The public pass summary in Binaryen is short enough to hide the important helper behavior.
- The corrected source reading avoids over-preserving private rec groups in future Starshine planning.

## Most important durable takeaways

- `remove-unused-types` is **not** part of Starshine's current open-world no-DWARF `-O` / `-Os` path.
- It is **not** the same pass as [`../remove-unused-module-elements/index.md`](../remove-unused-module-elements/index.md).
- The pass is closed-world and GC-only:
  - no-GC modules return unchanged,
  - explicit open-world execution is a fatal Binaryen usage error,
  - default scheduling only reaches it in the closed-world GC/type optimization neighborhood.
- Public type groups are anchors and are not freely reshaped away.
- Private types that are not used by the surviving IR can disappear.
- Surviving private types are rebuilt into a new private type group using predecessor constraints from private supertypes and described-type dependencies.
- The final output is a module-wide type-use rewrite, not merely a filtered list of type definitions.

## Beginner warning: what the name hides

The easy wrong mental model is:

- Binaryen walks the type section and deletes unreferenced type definitions one at a time.

The safer mental model is:

- Binaryen asks `GlobalTypeRewriter` to rebuild the module around the split between public groups and used private heap types.

That means the changed surface can include:

- type-section grouping,
- type names and type indices,
- function signatures,
- globals, tables, tags, and elements,
- heap-type references inside instructions,
- descriptor/described links,
- and validation-sensitive ref types.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  - Corrected source-backed Binaryen `version_129` strategy, including the tiny pass file, scheduler gate, and `GlobalTypeRewriter` phases.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  - File and test map for `RemoveUnusedTypes.cpp`, `pass.cpp`, `type-updating.h`, `module-utils.h`, and the dedicated lit proof surface.
- [`./closed-world-visibility-and-rec-group-rewrite.md`](./closed-world-visibility-and-rec-group-rewrite.md)
  - Focused guide to public-group anchoring, private dependency ordering, fresh private-group rebuilds, and the correction away from whole-old-rec-group preservation.
- [`./wat-shapes.md`](./wat-shapes.md)
  - Beginner-friendly module-shape catalog covering private removals, public retention, fresh private grouping, descriptor/supertype constraints, and open-world/no-GC boundaries.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  - Current Starshine status: boundary-only registry entry, active request rejection, no owner file, reusable type-section/parser/validator surfaces, and future port requirements.

## Current maintenance rule

- Treat this folder as the canonical home for future `remove-unused-types` research in this repo.
- Cite the 2026-04-24 raw primary-source manifest for the corrected source reading.
- Keep the 0149 research note as history only; do not reuse its superseded pass-local scanner / whole-old-rec-group explanation as the current algorithm.
- Keep the page honest about scheduler scope:
  - closed-world GC/type cluster in Binaryen,
  - boundary-only and inactive in current Starshine,
  - outside the current open-world no-DWARF optimize path.

## Sources

- [`../../../raw/binaryen/2026-04-24-remove-unused-types-primary-sources.md`](../../../raw/binaryen/2026-04-24-remove-unused-types-primary-sources.md)
- [`../../../raw/research/0298-2026-04-24-remove-unused-types-source-correction-and-starshine-followup.md`](../../../raw/research/0298-2026-04-24-remove-unused-types-source-correction-and-starshine-followup.md)
- Historical, superseded for algorithm details: [`../../../raw/research/0149-2026-04-21-remove-unused-types-binaryen-research.md`](../../../raw/research/0149-2026-04-21-remove-unused-types-binaryen-research.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- Binaryen `version_129` sources:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/RemoveUnusedTypes.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/remove-unused-types.wast>
