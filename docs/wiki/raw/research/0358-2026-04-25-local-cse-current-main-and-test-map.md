---
kind: research
status: supported
last_reviewed: 2026-04-25
sources:
  - ../binaryen/2026-04-25-local-cse-current-main-code-map.md
  - ../binaryen/2026-04-22-local-cse-primary-sources.md
  - ../../binaryen/passes/local-cse/index.md
  - ../../binaryen/passes/local-cse/implementation-structure-and-tests.md
  - ../../binaryen/passes/local-cse/binaryen-strategy.md
  - ../../binaryen/passes/local-cse/basic-block-windows-and-barriers.md
  - ../../binaryen/passes/local-cse/wat-shapes.md
  - ../../binaryen/passes/local-cse/starshine-strategy.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/simplify_locals.mbt
  - ../../../../src/passes/reorder_locals.mbt
  - ../../../../agent-todo.md
---

# `local-cse` current-main and implementation/test-map follow-up

## Why this follow-up exists

The existing `local-cse` folder already had a beginner-friendly overview, Binaryen strategy, window/barrier guide, shape catalog, and Starshine status page. The remaining durable gap was the same one already fixed for several neighboring late-local passes: there was no dedicated implementation/test-map page that told readers exactly which Binaryen files prove which part of the pass and which Starshine files are only future-port surfaces.

This follow-up closes that gap and refreshes the source bridge to 2026-04-25.

## Primary source recheck

Added:

- `docs/wiki/raw/binaryen/2026-04-25-local-cse-current-main-code-map.md`

The check used the existing `version_129` tagged-source manifest as the oracle and spot-checked current `main` for:

- `src/passes/LocalCSE.cpp`
- `src/passes/pass.cpp`
- `src/passes/opt-utils.h`
- `src/ir/linear-execution.h`
- `src/ir/effects.h`
- `src/ir/properties.{h,cpp}`
- `test/lit/passes/local-cse.wast`

No teaching-relevant drift was found. The live dossier should continue teaching `local-cse` as a scan/check/apply temp-local reuse pass for repeated whole expression trees inside limited linear execution windows.

## Durable findings

### 1. The owner-file/test surface is now explicit

The new page `docs/wiki/binaryen/passes/local-cse/implementation-structure-and-tests.md` records the file map that was previously scattered across the strategy and raw notes:

- `LocalCSE.cpp` owns candidate hashing, equality, request tracking, effect validation, and temp-local application.
- `linear-execution.h` owns the small window model, including the adjacent-block connection behavior that explains the before-`if` / then-arm positive family.
- `effects.h` and `properties.*` are correctness helpers, not optional background reading.
- `intrinsics.h` explains the narrow idempotent direct-call carveout.
- `cost.h` explains why small roots such as repeated `global.get` are usually not worth rewriting.
- `local-cse.wast` is the visible proof surface for the common examples, while some GC/idempotent-call edge families remain source-derived rather than directly isolated in a fixture.

### 2. The Starshine side remains a port map, not landed behavior

The recheck found the same local status as the 2026-04-22 follow-up:

- `src/passes/optimize.mbt:144-151` keeps `local-cse` in the removed-name registry.
- `src/passes/optimize.mbt:455-473` rejects removed pass flags before dispatch.
- `src/passes/pass_manager.mbt:8629-8648` has no `local-cse` dispatcher entry.
- `agent-todo.md:403-415` keeps the `LCSE` backlog slice.
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md:33` keeps the canonical slot.

The Starshine page now points readers more sharply to the closest implementation neighbors: `simplify_locals.mbt` for local-effect and sinkability reasoning, and `reorder_locals.mbt` for local-index scan/rewrite patterns.

### 3. The shape catalog remains correct but now has clearer evidence labels

The current-main check did not require replacing the shape catalog. The useful health fix was to keep the evidence level explicit:

- arithmetic repeats, load repeats, after-`if` barriers, local-write invalidation, nested-call negatives, switch-child ordering, and small-root no-ops are directly backed by the owner source plus dedicated lit file;
- idempotent direct-call positives and GC-generative allocation negatives are source-derived from `LocalCSE.cpp`, `intrinsics.h`, and `properties.cpp` and should continue to be labeled that way.

### 4. The local port checklist is now easier to follow

A future port should start with the new implementation/test-map page because it gives the shortest complete read path from upstream source to local landing zone. The implementation itself still needs to preserve:

- first-occurrence originals,
- parent-over-child request cancellation,
- limited linear windows,
- trap-insensitive validation for repeated roots,
- shallow non-trap side-effect and generativity filtering,
- idempotent direct-call exception,
- size/cost profitability thresholds,
- temp-local materialization, and
- the exact scheduler relationship to `flatten`, `simplify-locals-notee-nostructure`, `coalesce-locals`, and full `simplify-locals`.

## Files changed by this follow-up

### New raw source bridge

- `docs/wiki/raw/binaryen/2026-04-25-local-cse-current-main-code-map.md`

### New research note

- `docs/wiki/raw/research/0358-2026-04-25-local-cse-current-main-and-test-map.md`

### New living page

- `docs/wiki/binaryen/passes/local-cse/implementation-structure-and-tests.md`

### Refreshed living pages and catalogs

- `docs/wiki/binaryen/passes/local-cse/index.md`
- `docs/wiki/binaryen/passes/local-cse/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/local-cse/wat-shapes.md`
- `docs/wiki/binaryen/passes/local-cse/starshine-strategy.md`
- `docs/wiki/index.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/log.md`
- `CHANGELOG.md`

## Maintenance rule going forward

Treat the `local-cse` folder as a deep unimplemented-pass dossier. Future wiki work should not say the folder merely lacks provenance or a Starshine bridge; the remaining gap is implementation work. If upstream source behavior changes, update the strategy and implementation/test-map pages together so the algorithm narrative and proof-surface map remain aligned.
