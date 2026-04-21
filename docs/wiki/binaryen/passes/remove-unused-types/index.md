---
kind: entity
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0149-2026-04-21-remove-unused-types-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
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
  - ../tracker.md
  - ../index.md
  - ../global-refining/index.md
  - ../global-struct-inference/index.md
---

# `remove-unused-types`

## Role

- `remove-unused-types` is an upstream Binaryen **module pass**.
- It is currently **unimplemented** in Starshine and still lives in the boundary-only registry in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).
- In Binaryen `version_129`, the public pass summary in `pass.cpp` is just:
  - `remove unused types`

That summary is true, but too small.

A better beginner summary is:

- Binaryen trims away heap types that are no longer needed **inside a closed-world GC module**,
- but it first protects externally visible types,
- then keeps whole live rec groups rather than isolated type nodes,
- and finally rewrites the module's remaining heap-type graph consistently.

So this pass is not just type-section garbage collection.
It is **type-section garbage collection plus whole-module heap-type rewriting**.

## Why this pass matters

- The main no-DWARF / saved-`-O4z` parity queue is now fully dossier-covered, so this campaign needs new eligible targets.
- `remove-unused-types` is already named in the local boundary-only registry, so it is a real Starshine-facing pass name, not just an upstream curiosity.
- The current living `global-refining` and `global-struct-inference` docs already record it as a genuine Binaryen neighbor in the **closed-world GC/type cleanup cluster**.
- The pass had no dedicated living folder before this thread.
- It is easy to underestimate because the owning source file is tiny while the real contract lives in helpers like:
  - `ModuleUtils::CodeScanner`
  - `ModuleUtils::getPublicHeapTypes`
  - `GlobalTypeRewriter`

## Most important durable takeaways

- `remove-unused-types` is **not** part of the repo's main open-world no-DWARF `-O` / `-Os` path.
- `remove-unused-types` is **not** the same pass as `remove-unused-module-elements`.
- The pass only runs when all three gates are true:
  - optimize level at least `2`
  - `closedWorld`
  - GC features enabled
- Binaryen keeps **public heap types** first, then reasons about **used private heap types**.
- A used private type keeps its **whole rec group**, not just itself.
- The tiny `RemoveUnusedTypes.cpp` file is mostly a coordinator; the hard rewrite logic lives in `GlobalTypeRewriter`.
- A narrow 2026-04-21 freshness check found the checked current-`main` source and dedicated lit file still matching `version_129` on the important reviewed surfaces.

## Beginner warning: what the name hides

The easy wrong mental model is:

- Binaryen just deletes any type that nobody mentions any more

The safer mental model is:

- Binaryen first protects externally visible heap types,
- then scans the module for remaining heap-type uses,
- then retains whole live private rec groups,
- and finally rebuilds the module's heap-type mapping so every remaining type reference still points at the right rewritten group.

That difference matters a lot.

## What the pass sounds like versus what it actually does

What it sounds like:

- a tiny mark-and-sweep pass over the type section

What it actually is in `version_129`:

- a closed-world, GC-only module pass with:
  - public/private heap-type visibility handling
  - declaration-level and code-level type-use scanning
  - rec-group-aware private-type retention
  - `Builder`-based reconstruction of used private groups
  - `GlobalTypeRewriter`-based full-module heap-type remapping

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  - Deep dive into the actual Binaryen `version_129` implementation, helper dependencies, scheduler placement, main phases, and the difference between the pass name and the real closed-world rewrite contract.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  - File map for `RemoveUnusedTypes.cpp`, `pass.cpp`, `type-updating.h`, `module-utils.h`, and the dedicated lit test surface, plus the narrow current-`main` freshness note.
- [`./closed-world-visibility-and-rec-group-rewrite.md`](./closed-world-visibility-and-rec-group-rewrite.md)
  - Focused guide to the hardest part of the pass: public versus private heap types, why used private types keep whole rec groups, and how `GlobalTypeRewriter` avoids disturbing public groups unnecessarily.
- [`./wat-shapes.md`](./wat-shapes.md)
  - Beginner-friendly module-shape catalog covering unused private singleton and rec-group removals, public-type retention, live-private-group retention, and the major bailout/no-op families.

## Current maintenance rule

- Treat this folder as the canonical home for future `remove-unused-types` research in this repo.
- Keep this dossier clearly labeled as an **upstream-only boundary-only** pass for Starshine today.
- Keep the page honest about scheduler scope:
  - it belongs to Binaryen's closed-world GC/type cluster
  - it does **not** belong to the repo's current open-world no-DWARF optimize path
- Keep any future current-`main` drift notes explicit instead of silently rewriting the `version_129` contract.

## Sources

- [`../../../raw/research/0149-2026-04-21-remove-unused-types-binaryen-research.md`](../../../raw/research/0149-2026-04-21-remove-unused-types-binaryen-research.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../tracker.md`](../tracker.md)
- [`../index.md`](../index.md)
- [`../late-pipeline-dispatch.md`](../late-pipeline-dispatch.md)
- [`../global-refining/binaryen-strategy.md`](../global-refining/binaryen-strategy.md)
- [`../global-struct-inference/binaryen-strategy.md`](../global-struct-inference/binaryen-strategy.md)
- Binaryen `version_129` sources:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/RemoveUnusedTypes.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/remove-unused-types.wast>
- Narrow freshness-check sources:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/RemoveUnusedTypes.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/remove-unused-types.wast>
