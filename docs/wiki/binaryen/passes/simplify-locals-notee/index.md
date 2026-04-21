---
kind: entity
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0166-2026-04-21-simplify-locals-notee-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../simplify-locals/index.md
  - ../simplify-locals/variant-matrix-and-scheduler.md
  - ../tracker.md
  - ../../no-dwarf-default-optimize-path.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SimplifyLocals.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-notee.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-notee.txt
related:
  - ./binaryen-strategy.md
  - ./variant-boundaries-and-registry-aliases.md
  - ./wat-shapes.md
  - ../simplify-locals/index.md
  - ../simplify-locals/variant-matrix-and-scheduler.md
  - ../simplify-locals-notee-nostructure/index.md
  - ../simplify-locals-nostructure/index.md
  - ../tracker.md
---

# `simplify-locals-notee`

## Role

- `simplify-locals-notee` is an upstream Binaryen public pass.
- It is currently **unimplemented** in Starshine.
- The current local registry placeholder in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) is spelled `simplify-locals-no-tee`.
- In Binaryen `version_129`, this pass is **not** part of the canonical no-DWARF `-O` / `-Os` path tracked in [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md).
- It is still a fair wiki target because it is:
  - a real upstream public pass name in `pass.cpp`
  - a still-tracked local removed-registry candidate
  - a close sibling of already-documented locals-family variants

## Main beginner correction

The easy wrong summary is:

- "`simplify-locals-notee` is just the no-structure pass with another name."

The source-backed summary is:

- Binaryen builds this pass from the same `SimplifyLocals` engine as the full pass family
- its exact identity is `SimplifyLocals<false, true>`
- so it still allows:
  - direct single-use sinking
  - block / `if` / loop result formation
  - late equivalent-copy cleanup
  - final dead-set cleanup
- it forbids one specific family of rewrite:
  - sinking a multi-use value by creating a new `local.tee`

So `-notee` is **not**:

- `-nostructure`
- `-nonesting`
- a dead-set-only cleanup pass

## Why this pass matters

- The existing full `simplify-locals` dossier now teaches the five-variant matrix, but this variant still lacked its own landing page and canonical source-backed explanation.
- The spelling mismatch between upstream `simplify-locals-notee` and local placeholder `simplify-locals-no-tee` was worth making explicit in the tracker and living docs.
- The dedicated `simplify-locals-notee` test proves a useful beginner-facing point:
  - this pass still performs structured rewrites even though it refuses tees.

## Most important durable takeaways

- `simplify-locals-notee` is a real public Binaryen pass, not an internal-only mode.
- Its exact implementation identity is:
  - `allowTee = false`
  - `allowStructure = true`
  - `allowNesting = true`
- It shares the same main phases as the larger family:
  1. repeated linear-execution sinking cycles
  2. effect-aware invalidation
  3. optional structure formation
  4. late `EquivalentSets` cleanup
  5. final `UnneededSetRemover` cleanup
  6. `ReFinalize` when required
- The biggest difference from full `simplify-locals` is narrow but important:
  - a multi-use sink may no longer become a `local.tee`
- The biggest difference from `simplify-locals-notee-nostructure` is equally important:
  - structure formation still remains enabled here.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  - Actual Binaryen `version_129` implementation shape, helper dependencies, scheduler facts, and the real tee-vs-structure split.
- [`./variant-boundaries-and-registry-aliases.md`](./variant-boundaries-and-registry-aliases.md)
  - Why the upstream/local spelling mismatch matters, plus the exact contrast against full, `-nostructure`, `-notee-nostructure`, and `-nonesting` siblings.
- [`./wat-shapes.md`](./wat-shapes.md)
  - Beginner-friendly positive, negative, and bailout shape catalog.

## Current maintenance rule

- Treat this folder as the canonical home for the upstream public `simplify-locals-notee` pass.
- Keep the local alias mismatch explicit instead of silently pretending the local removed-registry spelling is the upstream name.
- Keep the main correction explicit:
  - `-notee` still forms structure
  - `-notee` only forbids new tee creation
- If Starshine ever ports this pass, preserve the distinction from both `-nostructure` and `-notee-nostructure`.

## Sources

- [`../../../raw/research/0166-2026-04-21-simplify-locals-notee-binaryen-research.md`](../../../raw/research/0166-2026-04-21-simplify-locals-notee-binaryen-research.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../simplify-locals/index.md`](../simplify-locals/index.md)
- [`../simplify-locals/variant-matrix-and-scheduler.md`](../simplify-locals/variant-matrix-and-scheduler.md)
- [`../tracker.md`](../tracker.md)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SimplifyLocals.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Representative tests:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-notee.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-notee.txt>
