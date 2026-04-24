---
kind: research
status: supported
last_reviewed: 2026-04-24
sources:
  - ../binaryen/2026-04-24-simplify-locals-notee-primary-sources.md
  - ../../binaryen/passes/simplify-locals-notee/index.md
  - ../../binaryen/passes/simplify-locals-notee/binaryen-strategy.md
  - ../../binaryen/passes/simplify-locals-notee/implementation-structure-and-tests.md
  - ../../binaryen/passes/simplify-locals-notee/variant-boundaries-and-registry-aliases.md
  - ../../binaryen/passes/simplify-locals-notee/wat-shapes.md
  - ../../binaryen/passes/simplify-locals-notee/starshine-strategy.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/cmd/cmd.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/simplify_locals.mbt
  - ../../../../src/passes/simplify_locals_test.mbt
  - ../../../../src/passes/simplify_locals_wbtest.mbt
  - ../../../../src/passes/pass_manager_wbtest.mbt
  - ../../../../src/passes/registry_test.mbt
  - ../../../../src/passes/optimize_test.mbt
  - ../../../../agent-todo.md
---

# `simplify-locals-notee` primary-source and Starshine follow-up

## Why this follow-up exists

The existing `simplify-locals-notee` folder already had a useful overview, Binaryen strategy, variant-boundary note, and WAT-shape catalog.
However, it still had durable gaps:

- no immutable raw primary-source manifest
- no dedicated implementation/test-map page
- no dedicated Starshine status/port-strategy page
- living pages still leaned on the older `0166` research note plus direct online source links
- the local-vs-upstream naming mismatch was documented, but not tied to exact CLI, dispatcher, and active full-pass code surfaces

This follow-up closes those gaps while keeping the older `0166` note as the original source-confirmation research.

## Primary sources captured in this run

Captured immutably in:

- `docs/wiki/raw/binaryen/2026-04-24-simplify-locals-notee-primary-sources.md`

The main reviewed upstream surfaces were:

- official Binaryen `version_129` release page
- `src/passes/SimplifyLocals.cpp`
- `src/passes/pass.cpp`
- `src/passes/passes.h`
- `src/passes/opt-utils.h`
- helper surfaces: `linear-execution.h`, `effects.h`, `equivalent_sets.h`, `local-utils.h`, `branch-utils.h`, and `manipulation.h`
- dedicated tests `test/passes/simplify-locals-notee.wast` and `.txt`
- neighboring variant tests for full, no-structure, no-tee/no-structure, and nonesting comparisons
- current-`main` spot-check URLs for the public pass name, factory surface, and dedicated test paths

## Local Starshine surfaces rechecked

- `src/passes/optimize.mbt`
- `src/cmd/cmd.mbt`
- `src/passes/pass_manager.mbt`
- `src/passes/simplify_locals.mbt`
- `src/passes/simplify_locals_test.mbt`
- `src/passes/simplify_locals_wbtest.mbt`
- `src/passes/pass_manager_wbtest.mbt`
- `src/passes/registry_test.mbt`
- `src/passes/optimize_test.mbt`
- `agent-todo.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`

## Durable findings

### 1. The Binaryen side remains a shared-engine sibling, not a separate algorithm

The source-backed identity is still:

- public pass name: `simplify-locals-notee`
- factory: `createSimplifyLocalsNoTeePass()`
- implementation owner: `src/passes/SimplifyLocals.cpp`
- engine identity: `SimplifyLocals<false, true>`
- teaching identity:
  - `allowTee = false`
  - `allowStructure = true`
  - `allowNesting = true`

That keeps the core correction intact: the pass disables fresh tee creation for multi-use sinking, but still allows structure formation, ordinary nesting, equivalent-copy cleanup, final dead-set cleanup, and refinalization.

### 2. The exact Starshine status is a naming split plus removed alias

Current Starshine does not register the upstream spelling `simplify-locals-notee`.
Instead, `src/passes/optimize.mbt` tracks the local descriptive alias `simplify-locals-no-tee` in `pass_registry_removed_names()`.

That means:

- the upstream spelling is an unknown local pass name today
- the local alias is known but removed
- CLI parsing in `src/cmd/cmd.mbt` accepts only hot/module/preset categories, so removed names are rejected as unknown pass flags at the command boundary
- internal hot-pipeline expansion rejects the local alias as removed if it is requested directly through the registry expansion path

The dossier now states that distinction explicitly instead of implying the upstream and local names are interchangeable.

### 3. Full local `simplify-locals` is the closest implementation surface but not enough

`src/passes/simplify_locals.mbt` already has an active full HOT pass with sinkable tracking, effect conflict checks, structure lifting, equivalent-copy cleanup, and dead-set cleanup.
`src/passes/pass_manager.mbt` dispatches that active pass only under descriptor name `simplify-locals`.

That code is the right future landing zone, but it is not equivalent to `simplify-locals-notee` because it does not expose an `allowTee = false` sibling policy today.
The new Starshine page therefore frames the future port as a parameterized or forked HOT locals-family mode, not a brand-new whole-module pass.

### 4. The missing tests are sibling-specific policy tests

The existing tests cover active full `simplify-locals` behavior and registry categories, but this follow-up found no focused tests for the local no-tee alias or its exact policy boundary.

A future implementation should add at least:

- positive single-use sink
- positive structured `if` or block result rewrite
- negative multi-use case that would require a fresh `local.tee`
- inherited effect/EH barrier
- registry/CLI behavior for the canonical chosen spelling

### 5. This pass is not in the canonical no-DWARF default path

The canonical local scheduler docs still matter because they place nearby variants:

- early `simplify-locals-nostructure`
- later full `simplify-locals`

They do not place `simplify-locals-notee` in the main no-DWARF `-O` / `-Os` parity path.
So this refresh is a source/provenance and future-port bridge, not a claim that the pass is part of the current default optimization queue.

## Files changed because of this follow-up

### New raw-source manifest

- `docs/wiki/raw/binaryen/2026-04-24-simplify-locals-notee-primary-sources.md`

### New living pages

- `docs/wiki/binaryen/passes/simplify-locals-notee/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/simplify-locals-notee/starshine-strategy.md`

### Refreshed living pages

- `docs/wiki/binaryen/passes/simplify-locals-notee/index.md`
- `docs/wiki/binaryen/passes/simplify-locals-notee/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/simplify-locals-notee/variant-boundaries-and-registry-aliases.md`
- `docs/wiki/binaryen/passes/simplify-locals-notee/wat-shapes.md`
- `docs/wiki/index.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/log.md`
- `CHANGELOG.md`

### Older research note status

- `docs/wiki/raw/research/0166-2026-04-21-simplify-locals-notee-binaryen-research.md`
  - kept as the original source-confirmation note
  - superseded for raw-source provenance and exact Starshine local-status mapping by this `0329` follow-up

## Resulting maintenance rule

Future wiki work should not treat `simplify-locals-notee` as still missing a raw primary-source anchor or Starshine status page.
Future code work should start from the exact local distinction recorded here:

- upstream public name: `simplify-locals-notee`
- current local placeholder: `simplify-locals-no-tee`
- current status: removed alias, no active implementation
- likely implementation landing zone: parameterized HOT locals-family code in or beside `src/passes/simplify_locals.mbt`
