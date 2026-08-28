---
kind: entity
status: supported
starshine_status: active
last_reviewed: 2026-08-28
sources:
  - ../simplify-locals/index.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/cmd/cmd.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/simplify_locals.mbt
  - ../simplify-locals/variant-matrix-and-scheduler.md
  - ../tracker.md
  - ../../no-dwarf-default-optimize-path.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./variant-boundaries-and-registry-aliases.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../simplify-locals/index.md
  - ../simplify-locals/variant-matrix-and-scheduler.md
  - ../simplify-locals-notee-nostructure/index.md
  - ../simplify-locals-nostructure/index.md
  - ../tracker.md
---

# `simplify-locals-notee`

## Binaryen-v131 renewal

Closed on 2026-07-27. The refreshed `simplify-locals-notee` aggregate completed `10000/10000`: `2766` exact matches and `7234` strictly smaller Starshine outputs (`-54..-4` bytes), with zero validation, property, generator, or command failures. Idempotence is `1000/1000`.

## 2026-08-28 artifact-scale performance checkpoint

Fresh one-warmup/three-sample baseline medians on the canonical 4,977,401-byte production input were `15,124.449ms` Starshine pass-local and `17,507.965ms` no-trace command versus Binaryen v131 at `793.693ms` and `1,297.505ms`. Attribution isolated `10,067.547ms` in absolute function 10618 before any ordinary rewrite phase: the large-local tee/memory-write bailout recursively recomputed descendant effects through a heavily shared expression DAG.

The retained repair makes both that bailout and pending-set effect summaries one-visit traversals over reachable HOT nodes. It also mirrors the exact large tee/store no-op at SLNT's raw fallback after all existing raw rewrites, avoiding unnecessary lift without bypassing profitable transformations. Final medians are `906.936ms` pass-local versus Binaryen `787.321ms` (`1.152x`) and `2,980.543ms` command versus `1,284.329ms` (`2.321x`). Pass work is approximately 16.7x faster and now near Binaryen parity; the remaining command gap belongs to shared lowering, function-envelope, batch-validation, and CLI validation/encoding phases.

Every paired output is byte-identical at 4,893,604 bytes, SHA-256 `058f0ee1fe372c253f30b5ab7fc23464ce647caeefc86d87b4c0dc1ac941fe27`. Final native SHA-256 is `58fde6321d2ae50a492f55346047a2d0ba5d0c91e035605046be5cb6e9a1d537`.

## Role

- `simplify-locals-notee` is an upstream Binaryen public pass and now an **active Starshine hot pass**.
- The canonical spelling `simplify-locals-notee` and compatibility alias `simplify-locals-no-tee` both route to the shared policy engine with structure enabled, sink-tee creation disabled, and ordinary nesting enabled.
- Focused TDD proves single-use sinking, preservation of multi-use carriers without a fresh sink tee, and `if`-result synthesis. The current dedicated aggregate and idempotence closeout are recorded in [`./fuzzing.md`](./fuzzing.md).
- The 2026-04-24 source inventory is retained in research note 0329, alongside direct tagged source URLs.
- In Binaryen `version_131`, this pass is **not** part of the canonical no-DWARF `-O` / `-Os` path tracked in [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md).
- It is still a fair wiki target because it is:
  - a real upstream public pass name in `pass.cpp`
  - an active Starshine registry entry with a tested compatibility alias
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
- The spelling mismatch between upstream `simplify-locals-notee` and local compatibility `simplify-locals-no-tee` remains explicit, but both names are now active and share one canonical implementation.
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
  - Actual Binaryen `version_131` implementation shape, helper dependencies, scheduler facts, and the real tee-vs-structure split.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  - Source/test map for `SimplifyLocals.cpp`, `pass.cpp`, `passes.h`, helper files, the dedicated sibling fixtures, and neighboring comparison fixtures.
- [`./variant-boundaries-and-registry-aliases.md`](./variant-boundaries-and-registry-aliases.md)
  - Why the upstream/local spelling mismatch matters, plus the exact contrast against full, `-nostructure`, `-notee-nostructure`, and `-nonesting` siblings.
- [`./wat-shapes.md`](./wat-shapes.md)
  - Beginner-friendly positive, negative, and bailout shape catalog.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  - Exact current Starshine implementation, raw/HOT safety boundaries, performance architecture, and remaining shared-envelope work.

## Current maintenance rule

- Treat this folder as the canonical home for the upstream public `simplify-locals-notee` pass.
- Keep the canonical `simplify-locals-notee` spelling and compatibility alias `simplify-locals-no-tee` explicit.
- Keep the main correction explicit:
  - `-notee` still forms structure
  - `-notee` only forbids new tee creation
- If Starshine ever ports this pass, preserve the distinction from both `-nostructure` and `-notee-nostructure`.
- Treat the 2026-04-24 raw manifest and `0329` follow-up as the current provenance and local-status anchors; keep `0166` as historical source-confirmation research.

## Sources

- research note 0329
- research note 0166
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../simplify-locals/index.md`](../simplify-locals/index.md)
- [`../simplify-locals/variant-matrix-and-scheduler.md`](../simplify-locals/variant-matrix-and-scheduler.md)
- [`../tracker.md`](../tracker.md)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- Binaryen `version_131` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/SimplifyLocals.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/pass.cpp>
- Representative tests:
  - <https://github.com/WebAssembly/binaryen/blob/version_131/test/passes/simplify-locals-notee.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_131/test/passes/simplify-locals-notee.txt>
