---
kind: entity
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-abstract-type-refining-primary-sources.md
  - ../../../raw/research/0295-2026-04-24-abstract-type-refining-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0155-2026-04-21-abstract-type-refining-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../tracker.md
  - ../index.md
  - ../global-struct-inference/binaryen-strategy.md
  - ../unsubtyping/binaryen-strategy.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./traps-never-happen-exact-casts-and-descriptors.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../tracker.md
  - ../index.md
  - ../global-struct-inference/index.md
  - ../unsubtyping/index.md
---

# `abstract-type-refining`

## Role

- `abstract-type-refining` is an upstream Binaryen **module pass**.
- It is currently **unimplemented** in Starshine and still lives in the boundary-only registry in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).
- Upstream Binaryen `pass.cpp` registers the public CLI name:
  - `abstract-type-refining`
- In Binaryen `version_129`, the public pass summary in `pass.cpp` is:
  - `refine and merge abstract (never-created) types`

That summary is true, but too small.

A better beginner summary is:

- Binaryen scans the module for which **struct** types are ever actually created,
- treats public types as created conservatively,
- maps truly never-created struct families to bottom,
- and, only in `--traps-never-happen` mode, can refine an abstract parent type to the one still-relevant child branch that can actually exist at runtime.

It also has an important cleanup phase before shared type rewriting:

- exact casts,
- descriptor casts,
- `ref.get_desc`,
- `br_on_cast_desc_eq*`,
- and `struct.new_desc`

may need explicit rewrites so later type rewriting and refinalization do not make them invalid or silently change behavior.

So this is not generic type merging.
It is **closed-world creation-evidence-based struct-type refinement**.

## Why this pass matters

- The main no-DWARF / saved-`-O4z` parity queue is now fully dossier-covered, so this campaign needs another eligible pass from the tracker's upstream-only registry table.
- `abstract-type-refining` is already named in the local boundary-only registry, so this is a real Starshine-facing pass name.
- The current `global-struct-inference`, `global-type-optimization`, and `unsubtyping` dossiers already record it as a real late closed-world GC/type neighbor.
- `agent-todo.md` still has **no dedicated `abstract-type-refining` slice**, so a stable wiki home matters even more here.
- The official implementation hides several teaching traps that deserve an explicit dossier:
  - only **struct** types are optimized today
  - only `struct.new*` counts as creation evidence
  - public types are conservatively treated as created even in closed world
  - refining an abstract parent to a live child is **TNH-only**
  - mapping truly never-created families to bottom happens even without TNH
  - subtype-edge cleanup is intentionally left to later `unsubtyping`
  - exact and descriptor-bearing cast/allocation shapes need preoptimization before shared type rewriting

## Most important durable takeaways

- `abstract-type-refining` is **not** part of the repo's main open-world no-DWARF `-O` / `-Os` path.
- The default scheduler places it only in the **closed-world GC/type cluster** after `gsi` and before `unsubtyping`.
- The pass body itself checks:
  - GC features enabled
  - `--closed-world` enabled, or else it throws a fatal error
- Only **struct** heap types are optimized today.
- The pass distinguishes:
  - `createdTypes`
    - directly created by `struct.new*`
  - `createdTypesOrSubTypes`
    - the type itself or some subtype is created
- In all modes, a struct type with **no created instance and no created subtype** is rewritten to its bottom heap type.
- Only in `--traps-never-happen` mode can an abstract parent refine to a unique live child branch.
- Declared subtype edges are intentionally preserved here.
- Descriptor/exact-cast repair is part of the real contract, not optional polish.
- The 2026-04-24 raw primary-source manifest now anchors the dossier to the official `version_129` release page and source/test URLs, and the refreshed Starshine page maps the current local boundary-only status to exact code locations.
- A narrow 2026-04-24 freshness check found no teaching-relevant current-`main` drift from the reviewed `version_129` contract on the owner file, registration surface, helper headers, and dedicated lit files.

## Beginner warning: what the name hides

The easy wrong mental model is:

- Binaryen finds abstract types and merges them into related types.

The safer mental model is:

- Binaryen first proves which struct types are actually created,
- distinguishes “directly created” from “has a live created subtype,”
- maps impossible families to bottom,
- only then applies a narrower TNH-only parent-to-child refinement,
- and preoptimizes exact/descriptor shapes before global type rewriting would otherwise recreate invalid or behavior-changing IR.

That difference matters a lot.

## What the pass sounds like versus what it actually does

What it sounds like:

- a generic nominal-type merge pass for abstract types

What it actually is in `version_129`:

- a closed-world struct-only module pass with:
  - concrete `struct.new*` creation scanning
  - public-type freezing by treating public types as created
  - upward created-subtype propagation
  - TNH-only singleton-child refinement
  - always-on bottomization of fully never-created families
  - descriptor/exact-cast preoptimization
  - shared type rewriting that **preserves declared supertypes**
  - final refinalization

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  - Deep dive into the actual Binaryen `version_129` algorithm, helper dependencies, scheduler placement, and the exact phase structure.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  - File map for `AbstractTypeRefining.cpp`, `pass.cpp`, `subtypes.h`, `type-updating.*`, `module-utils.h`, `localize.h`, `drop.h`, and the official lit roster, plus the important fact that current `main` still matches the reviewed `version_129` surfaces.
- [`./traps-never-happen-exact-casts-and-descriptors.md`](./traps-never-happen-exact-casts-and-descriptors.md)
  - Focused guide to the hardest half of the pass: why TNH matters, why exact casts often collapse to bottom/null checks instead of refining to a live child, and how descriptor casts / `ref.get_desc` / `struct.new_desc` are repaired safely.
- [`./wat-shapes.md`](./wat-shapes.md)
  - Beginner-friendly WAT-shape catalog covering positive TNH refinements, always-on bottomization, multiple-child bailouts, descriptor/exact-cast repair families, `ref.get_desc` cases, allocation cases, and continuation robustness.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  - Current Starshine status and future port map: boundary-only registry entry, honest request rejection, active preset omission, no owner file, no active backlog slice, and the exact GC/type/parser/validator surfaces a future closed-world module pass would need to reuse.

## Current maintenance rule

- Treat this folder as the canonical home for future `abstract-type-refining` research in this repo.
- Keep this dossier clearly labeled as an **upstream-only boundary-only** pass for Starshine today.
- Keep the page honest about scheduler scope:
  - it belongs to Binaryen's closed-world GC/type cluster
  - it does **not** belong to the repo's current open-world no-DWARF optimize path
- Keep the scope boundary explicit:
  - the current `version_129` implementation is **struct-only**
  - arrays/functions are TODOs, not current behavior
- Keep the “leave subtype edges to `unsubtyping`” rule explicit instead of quietly implying this pass already does full relation minimization.
- Keep any future current-`main` drift notes explicit instead of silently rewriting the `version_129` contract.

## Sources

- [`../../../raw/binaryen/2026-04-24-abstract-type-refining-primary-sources.md`](../../../raw/binaryen/2026-04-24-abstract-type-refining-primary-sources.md)
- [`../../../raw/research/0295-2026-04-24-abstract-type-refining-primary-sources-and-starshine-followup.md`](../../../raw/research/0295-2026-04-24-abstract-type-refining-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0155-2026-04-21-abstract-type-refining-binaryen-research.md`](../../../raw/research/0155-2026-04-21-abstract-type-refining-binaryen-research.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../tracker.md`](../tracker.md)
- [`../index.md`](../index.md)
- [`../global-struct-inference/binaryen-strategy.md`](../global-struct-inference/binaryen-strategy.md)
- [`../unsubtyping/binaryen-strategy.md`](../unsubtyping/binaryen-strategy.md)
- Binaryen `version_129` sources:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/AbstractTypeRefining.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/subtypes.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/localize.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/drop.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/abstract-type-refining.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/abstract-type-refining-desc.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/abstract-type-refining-exact.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/abstract-type-refining-tnh-exact-casts.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/abstract-type-refining-cont.wast>
- Narrow freshness-check sources:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/AbstractTypeRefining.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/abstract-type-refining.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/abstract-type-refining-desc.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/abstract-type-refining-exact.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/abstract-type-refining-tnh-exact-casts.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/abstract-type-refining-cont.wast>
