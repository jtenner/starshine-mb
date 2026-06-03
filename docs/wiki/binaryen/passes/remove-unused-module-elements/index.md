---
kind: entity
status: supported
last_reviewed: 2026-06-03
sources:
  - ../../../raw/research/0545-2026-05-06-rume-direct-revalidation.md
  - ../../../raw/binaryen/2026-04-22-remove-unused-module-elements-primary-sources.md
  - ../../../raw/research/0243-2026-04-22-remove-unused-module-elements-primary-sources-and-code-map-followup.md
  - ../../../raw/research/0145-2026-04-20-remove-unused-module-elements-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/remove_unused_module_elements.mbt
  - ../../../../../src/passes/remove_unused_module_elements_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
related:
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./implementation-structure-and-tests.md
  - ./roots-reference-only-and-nullification.md
  - ./retention-and-index-rewrites.md
  - ./starshine-hot-ir-strategy.md
  - ./parity.md
  - ../../no-dwarf-default-optimize-path.md
---

# `remove-unused-module-elements`

## Role

- `remove-unused-module-elements` is an active implemented **module pass** in Starshine.
- In upstream Binaryen `version_129`, it is the main whole-module dead-element cleanup pass for:
  - functions
  - globals
  - tables
  - memories
  - tags
  - elem segments
  - data segments
- The real job is broader than the old landing page suggested and more subtle than the name implies.

A good beginner summary is:

- Binaryen builds a whole-module reachability graph,
- distinguishes between elements that are **strongly used** and those that are merely **still referenced**,
- propagates that information through code, tables, GC heap types, and segments,
- then deletes or weakens declarations while rewriting every surviving index surface.

For the shared Starshine function-index section model that RUME must preserve while deleting or remapping functions, see [`../../../binary/function-import-export-and-code-sections.md`](../../../binary/function-import-export-and-code-sections.md).

That is much closer to the official source than “remove dead functions.”

## Why this pass matters

- The old tracker queues are now clear enough that this thread had to justify an already-`deep` fallback pick.
- `remove-unused-module-elements` stayed worth revisiting because the upstream-side dossier was already strong, but the folder still lacked two practical durability surfaces:
  - an immutable raw primary-source manifest anchoring the reviewed official Binaryen release / source / test pages
  - an exact Starshine code-location map for the current MoonBit registry / dispatcher / liveness / rewrite / type-cleanup flow
- The canonical no-DWARF `-O` / `-Os` scheduler still runs the pass **three** times:
  - pre slot `2`
  - pre slot `6`
  - post slot `49`
- The 2026-05-06 direct revalidation note records that the generated-artifact `-O4z` trace contains real `remove-unused-module-elements` executions, so this is not just a theoretical preset entry.
- The 2026-05-06 direct-pass revalidation fixed the active-segment global-offset and empty active-element pruning drift, then reached `9972 / 10000` compared cases with `0` semantic mismatches.
- Ordered-neighborhood and artifact proof remain separate optimize-path work because the canonical no-DWARF path runs RUME repeatedly.

## Most important durable takeaways

- Binaryen RUME is **not** only a dead-function pass.
- Binaryen RUME is **not** a simple one-pass mark-and-sweep.
- The pass is built around five real ideas:
  1. seed roots from exports, start, module code, and function bodies
  2. distinguish **strong use** from **reference-only reachability**
  3. propagate liveness through a queue-driven fixed point
  4. remove unused function types before later non-function cleanup
  5. either delete, keep, or weaken declarations while rewriting all surviving users
  6. preserve `ref.func` declaration validity after function compaction, including active-to-declarative elem weakening when the active parent table is otherwise dead
- The helper surface matters a lot:
  - `ModuleUtils`
  - `ElementUtils`
  - `GCTypeUtils`
  - `TableUtils::FlatTable`
  - `FunctionTypeUtils`
  - `NullifyRemovableElement`
- The pass has a real sibling mode, `remove-unused-nonfunction-module-elements`, which reuses the same graph core and changes only the final deletion boundary.
- The source still carries a disabled `prepare()` fast path behind a FIXME about missing references hidden inside unreachable code, so the shipped `version_129` algorithm is the conservative scan-and-fixpoint path.

## Beginner warning: what the name hides

The easy wrong mental model is:

- walk the module once
- see what nobody uses
- delete it

The safer mental model is:

- Binaryen builds a richer module graph than that,
- tracks whether a thing is strongly used or merely still referenced,
- treats calls, `ref.func`, `call_ref`, GC field heap types, flat tables, active/passive segments, and exports differently,
- and sometimes replaces a reference-only non-function declaration with an inert placeholder instead of deleting it outright.

That difference matters a lot if Starshine ever wants fully honest parity here.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  - Deep dive into the actual Binaryen `version_129` implementation strategy, helper dependencies, queue stages, removal ordering, and scheduler meaning.
- [`./wat-shapes.md`](./wat-shapes.md)
  - Beginner-friendly module/WAT shape catalog covering positive, negative, reference-only, segment-parent, GC, and rewrite-heavy families.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  - Exact upstream file map, helper dependency story, official lit families, and the narrow source-trust rule for this dossier.
- [`./roots-reference-only-and-nullification.md`](./roots-reference-only-and-nullification.md)
  - Focused guide to the hardest part of the pass: strong roots versus reference-only roots, active-segment parent retention, and when Binaryen weakens a declaration instead of deleting it.
- [`./retention-and-index-rewrites.md`](./retention-and-index-rewrites.md)
  - Current in-tree Starshine rewrite surface for surviving func/global/table/memory/tag/elem/data/name/annotation indices, plus the local dead-type-cleanup path that now runs after pruning.
- [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md)
  - Current in-tree Starshine strategy with exact MoonBit registry, dispatcher, liveness, rewrite, type-cleanup, and test code locations; also explains why the pass remains module-scoped instead of becoming a pure HOT pass.
- [`./parity.md`](./parity.md)
  - Current signoff state, focused coverage, and remaining non-semantic compare noise.

## Current maintenance rule

- Treat this folder as the canonical home for future RUME parity and scheduler research.
- Keep the new source-backed split explicit:
  - `binaryen-strategy.md` for the overall upstream algorithm
  - `implementation-structure-and-tests.md` for file/test mapping
  - `roots-reference-only-and-nullification.md` for the most easily misunderstood semantic core
- If a future thread finds real current-main drift, record it explicitly instead of silently rewriting the `version_129`-anchored explanation.
- If new Starshine work changes the local retention or remap surface, update both:
  - [`./retention-and-index-rewrites.md`](./retention-and-index-rewrites.md)
  - [`./parity.md`](./parity.md)

## Sources

- [`../../../raw/binaryen/2026-04-22-remove-unused-module-elements-primary-sources.md`](../../../raw/binaryen/2026-04-22-remove-unused-module-elements-primary-sources.md)
- [`../../../raw/research/0243-2026-04-22-remove-unused-module-elements-primary-sources-and-code-map-followup.md`](../../../raw/research/0243-2026-04-22-remove-unused-module-elements-primary-sources-and-code-map-followup.md)
- [`../../../raw/research/0145-2026-04-20-remove-unused-module-elements-binaryen-research.md`](../../../raw/research/0145-2026-04-20-remove-unused-module-elements-binaryen-research.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- [`../../../../../src/passes/remove_unused_module_elements.mbt`](../../../../../src/passes/remove_unused_module_elements.mbt)
- [`../../../../../src/passes/remove_unused_module_elements_test.mbt`](../../../../../src/passes/remove_unused_module_elements_test.mbt)
- [`../../../../../src/cmd/cmd_wbtest.mbt`](../../../../../src/cmd/cmd_wbtest.mbt)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RemoveUnusedModuleElements.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/element-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/gc-type-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/table-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/FunctionTypeUtils.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-module-elements_all-features.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-module-elements-eh-old.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-module-elements-refs.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-nonfunction-module-elements_all-features.wast>
