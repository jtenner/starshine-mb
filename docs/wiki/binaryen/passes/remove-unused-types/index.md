---
kind: entity
status: supported
last_reviewed: 2026-07-18
sources:
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/RemoveUnusedTypes.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_131/test/lit/passes/remove-unused-types-open.wast
  - ../../../raw/research/1573-2026-07-18-binaryen-version-131-release-impact-audit.md
  - ../../../raw/research/0405-2026-04-26-remove-unused-types-port-readiness.md
  - ../../../raw/research/0477-2026-05-05-remove-unused-types-current-main-recheck.md
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
  - ./starshine-port-readiness-and-validation.md
  - ../tracker.md
  - ../index.md
  - ../global-refining/index.md
  - ../global-struct-inference/index.md
  - ../type-merging/index.md
  - ../unsubtyping/index.md
---

# `remove-unused-types`

## Role

`remove-unused-types` is an upstream Binaryen **world-mode-aware GC module pass**. Binaryen schedules it only in the closed-world GC/type cluster, but v131 also supports explicit open-world invocation.

In current Starshine it is **unimplemented** and kept as a boundary-only registry name in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).
There is no `src/passes/remove_unused_types.mbt` owner file today.

A good beginner summary is:

- Binaryen removes private heap types that are no longer used,
- keeps public type groups as external-boundary anchors,
- rebuilds the surviving private heap types into a fresh private rec-group layout with dependency ordering,
- and rewrites every module-wide type use through the new mapping.

So this pass is not just type-section garbage collection.
It is **world-policy-aware private heap-type cleanup plus whole-module heap-type rewriting**.
Binaryen v131 resolves the earlier current-main uncertainty: the wrapper passes `WorldMode` into `GlobalTypeRewriter`, and the focused open-world fixture proves that exposed types remain public while still-private types may be removed or regrouped.

## 2026-04-24 source correction

The older research note [`../../../raw/research/0149-2026-04-21-remove-unused-types-binaryen-research.md`](../../../raw/research/0149-2026-04-21-remove-unused-types-binaryen-research.md) is useful history, but its phase-by-phase algorithm reading is now superseded.

The retained correction research records the historical wrapper reading, but its direct-open-world-rejection wording is now stale. Binaryen v131 passes `getPassOptions().worldMode` into `GlobalTypeRewriter`, and `remove-unused-types-open.wast` establishes the released policy: open-world exposed types and their required identity closure stay public, while unrelated private types remain eligible for cleanup.

The durable correction remains:

- `RemoveUnusedTypes.cpp` is a small GC-gated coordinator around helper-owned rewriting, rather than a pass-local scanner/builder.
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
- The pass is GC/type-graph work whose historical scheduler home is the closed-world GC/type optimization neighborhood:
  - no-GC modules return unchanged,
  - v131 passes world mode to the helper and explicitly supports open-world runs with mode-aware public-type retention,
  - it remains outside Starshine's current open-world no-DWARF path.
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
- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md)
  - Future Starshine implementation ladder: no-rewrite analyzer first, private singleton deletion, old-rec-group member removal, descriptor/supertype dependency retention, full type-use repair, and closed-world Binaryen-oracle validation.

## Current maintenance rule

- Treat this folder as the canonical home for future `remove-unused-types` research in this repo.
- Cite the retained 2026-04-24 correction research for the algorithm correction and the v131 release audit plus open-world fixture for the released wrapper/admission policy.
- Keep the 0149 research note as history only; do not reuse its superseded pass-local scanner / whole-old-rec-group explanation as the current algorithm.
- Keep the page honest about scheduler scope:
  - closed-world GC/type cluster in Binaryen,
  - boundary-only and inactive in current Starshine,
  - outside the current open-world no-DWARF optimize path.

## Sources

- Binaryen v131 owner: <https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/RemoveUnusedTypes.cpp>
- Binaryen v131 open-world fixture: <https://github.com/WebAssembly/binaryen/blob/version_131/test/lit/passes/remove-unused-types-open.wast>
- [`../../../raw/research/0405-2026-04-26-remove-unused-types-port-readiness.md`](../../../raw/research/0405-2026-04-26-remove-unused-types-port-readiness.md)
- [`../../../raw/research/0298-2026-04-24-remove-unused-types-source-correction-and-starshine-followup.md`](../../../raw/research/0298-2026-04-24-remove-unused-types-source-correction-and-starshine-followup.md)
- Historical, superseded for algorithm details: [`../../../raw/research/0149-2026-04-21-remove-unused-types-binaryen-research.md`](../../../raw/research/0149-2026-04-21-remove-unused-types-binaryen-research.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- Binaryen `version_129` sources:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/RemoveUnusedTypes.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/remove-unused-types.wast>
