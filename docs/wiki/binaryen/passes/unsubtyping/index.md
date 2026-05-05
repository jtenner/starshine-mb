---
kind: entity
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-unsubtyping-current-main-recheck.md
  - ../../../raw/research/0444-2026-05-05-unsubtyping-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-24-unsubtyping-primary-sources.md
  - ../../../raw/research/0289-2026-04-24-unsubtyping-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0154-2026-04-21-unsubtyping-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../tracker.md
  - ../index.md
  - ../global-struct-inference/binaryen-strategy.md
  - ../global-type-optimization/binaryen-strategy.md
  - ../remove-unused-types/binaryen-strategy.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./descriptor-squares-casts-and-js-boundaries.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../tracker.md
  - ../index.md
  - ../global-struct-inference/index.md
  - ../global-type-optimization/index.md
  - ../remove-unused-types/index.md
---

# `unsubtyping`

## Role

- `unsubtyping` is an upstream Binaryen **module pass**.
- It is currently **unimplemented** in Starshine and still lives in the boundary-only registry in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).
- Upstream Binaryen `pass.cpp` registers the public CLI name:
  - `unsubtyping`
- In Binaryen `version_129`, the public pass summary in `pass.cpp` is:
  - `removes unnecessary subtyping relationships`

That summary is true, but too small.

A better beginner summary is:

- Binaryen scans the module for the smallest remaining subtype and descriptor relations needed for validation,
- keeps extra relations only when casts, descriptors, public boundaries, or JS-observable behavior still need them,
- rewrites private type declarations to match that minimized graph,
- repairs descriptor-bearing allocations when descriptor edges disappear,
- and refinalizes afterward because the changed type graph can sharpen or invalidate surrounding operations.

So this is not generic type merging.
It is **closed-world subtype/descriptor graph minimization**.

## Why this pass matters

- The main no-DWARF / saved-`-O4z` parity queue is now fully dossier-covered, so this campaign needs another eligible pass from the tracker's upstream-only registry table.
- `unsubtyping` is already named in the local boundary-only registry, so this is a real Starshine-facing pass name.
- The current `global-struct-inference`, `global-type-optimization`, and `remove-unused-types` dossiers already record it as a real late closed-world GC/type neighbor.
- `agent-todo.md` still has **no dedicated `unsubtyping` slice**, so a stable wiki home matters even more here.
- The official implementation hides several teaching traps that deserve an explicit dossier:
  - the pass is about **descriptors** as well as ordinary subtype edges
  - the pass body itself hard-requires `--closed-world`
  - ordinary casts only keep subtype edges when actual flowing inhabitants make cast success observable
  - exact casts are a narrower special case
  - JS boundary flow can keep subtype edges and descriptors alive
  - many official visible shrink results are shown under `--unsubtyping --remove-unused-types`, not `--unsubtyping` alone
  - allocation fixups and `ReFinalize()` are part of the real contract

## Most important durable takeaways

- The 2026-05-05 current-main recheck added an immutable freshness-layer manifest at [`../../../raw/binaryen/2026-05-05-unsubtyping-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-unsubtyping-current-main-recheck.md), and the folder now also has the missing port-readiness bridge at [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).
- `unsubtyping` is **not** part of the repo's main open-world no-DWARF `-O` / `-Os` path.
- The default scheduler places it only in the **closed-world GC/type cluster** after `gsi` and optional `abstract-type-refining`.
- The pass body itself checks:
  - GC features enabled
  - `--closed-world` enabled, or else it throws a fatal error
- The pass minimizes **descriptor** relations too, not only declared supertype edges.
- The actual algorithm is a **fixed point** over:
  - validation constraints
  - type-definition implications
  - cast-success preservation
  - descriptor-square completion
  - JS-boundary exposure
- Exact casts impose a smaller relation surface than ordinary casts.
- Public types are frozen.
- Descriptor-bearing allocations may need explicit fixups or synthetic globals when descriptor edges disappear.
- The 2026-05-05 current-main recheck found no teaching-relevant drift in the reviewed owner, registration, and lit surfaces beyond the existing `version_129` dossier claims.

## Beginner warning: what the name hides

The easy wrong mental model is:

- Binaryen looks for declared subtype edges that appear unused and deletes them.

The safer mental model is:

- Binaryen first computes which subtype and descriptor relations are still required by validation, casts, descriptors, and JS boundaries,
- then repeatedly adds any further relations that those requirements imply,
- and only after that does it rewrite private type declarations and affected allocations.

That difference matters a lot.

## What the pass sounds like versus what it actually does

What it sounds like:

- a declaration cleanup pass that removes redundant subtype arrows

What it actually is in `version_129`:

- a closed-world GC module pass with:
  - public-type freezing
  - IR-wide subtype-constraint discovery
  - ordinary-vs-exact cast distinction
  - descriptor-square completion
  - JS prototype-field keepalive logic
  - descriptor-allocation trap preservation
  - private-type graph rewriting
  - final refinalization

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  - Deep dive into the actual Binaryen `version_129` algorithm, helper dependencies, scheduler placement, and the exact fixed-point phases.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  - File map for `Unsubtyping.cpp`, `subtype-exprs.h`, `js-utils.h`, `type-updating.*`, and the official lit roster, plus the important caveat that most visible test shrinkage is checked under `--unsubtyping --remove-unused-types`.
- [`./descriptor-squares-casts-and-js-boundaries.md`](./descriptor-squares-casts-and-js-boundaries.md)
  - Focused guide to the hardest half of the pass: descriptor squares, ordinary-vs-exact casts, JS boundary flow through `any`, and the allocation fixups that preserve traps.
- [`./wat-shapes.md`](./wat-shapes.md)
  - Beginner-friendly WAT-shape catalog covering positive validation families, cast positives and negatives, descriptor keepalive/removal cases, JS-interaction cases, and stack-switching/continuation bailouts.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  - Current Starshine status and future port map: boundary-only registry entry, active request rejection, no owner file, no active backlog slice, no open-world no-DWARF role, and the exact type-section / descriptor WAT surfaces a future module pass would need to build on.
- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md)
  - Port-readiness bridge for the missing port: current local hold point, no-rewrite planner first slice, rewrite and refinalization requirements, validation ladder, and Binaryen oracle lanes.

## Current maintenance rule

- Treat this folder as the canonical home for future `unsubtyping` research in this repo.
- Keep this dossier clearly labeled as an **upstream-only boundary-only** pass for Starshine today.
- Keep the page honest about scheduler scope:
  - it belongs to Binaryen's closed-world GC/type cluster
  - it does **not** belong to the repo's current open-world no-DWARF optimize path
- Keep the combo-test rule explicit:
  - many official lit files run `--unsubtyping --remove-unused-types`
  - disappearing type definitions in those files are not always a pure `unsubtyping` effect
- Keep any future current-`main` drift notes explicit instead of silently rewriting the `version_129` contract.

## Sources

- [`../../../raw/binaryen/2026-04-24-unsubtyping-primary-sources.md`](../../../raw/binaryen/2026-04-24-unsubtyping-primary-sources.md)
- [`../../../raw/research/0289-2026-04-24-unsubtyping-primary-sources-and-starshine-followup.md`](../../../raw/research/0289-2026-04-24-unsubtyping-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0154-2026-04-21-unsubtyping-binaryen-research.md`](../../../raw/research/0154-2026-04-21-unsubtyping-binaryen-research.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../tracker.md`](../tracker.md)
- [`../index.md`](../index.md)
- [`../global-struct-inference/binaryen-strategy.md`](../global-struct-inference/binaryen-strategy.md)
- [`../global-type-optimization/binaryen-strategy.md`](../global-type-optimization/binaryen-strategy.md)
- [`../remove-unused-types/binaryen-strategy.md`](../remove-unused-types/binaryen-strategy.md)
- Binaryen `version_129` sources:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/Unsubtyping.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/subtype-exprs.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/js-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/localize.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/effects.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/wasm-type.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/unsubtyping.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/unsubtyping-casts.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/unsubtyping-cmpxchg.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/unsubtyping-desc.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/unsubtyping-desc-tnh.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/unsubtyping-jsinterop.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/unsubtyping-stack-switching.wast>
- Narrow freshness-check sources:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/Unsubtyping.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/unsubtyping.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/unsubtyping-casts.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/unsubtyping-cmpxchg.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/unsubtyping-desc.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/unsubtyping-desc-tnh.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/unsubtyping-jsinterop.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/unsubtyping-stack-switching.wast>
