---
kind: research
status: supported
last_reviewed: 2026-04-25
sources:
  - ../binaryen/2026-04-25-code-folding-current-main-recheck.md
  - ../binaryen/2026-04-22-code-folding-primary-sources.md
  - ../../binaryen/passes/code-folding/index.md
  - ../../binaryen/passes/code-folding/binaryen-strategy.md
  - ../../binaryen/passes/code-folding/implementation-structure-and-tests.md
  - ../../binaryen/passes/code-folding/terminating-tails.md
  - ../../binaryen/passes/code-folding/wat-shapes.md
  - ../../binaryen/passes/code-folding/starshine-strategy.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/cli/cli_test.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../agent-todo.md
  - ../../binaryen/no-dwarf-default-optimize-path.md
---

# `code-folding` current-main source bridge and test map

## Why this follow-up exists

The `code-folding` folder already had the required overview, Binaryen strategy, shape catalog, terminating-tail guide, raw tagged-source manifest, and Starshine status page.
A health pass still found one durable gap: unlike neighboring folders, it lacked a dedicated `implementation-structure-and-tests.md` page that maps the source owner, helper surfaces, official lit tests, scheduler location, and local Starshine code/status surfaces in one beginner-readable place.

This follow-up fills that gap and adds a fresh current-main raw source bridge without duplicating the existing strategy explanation.

## Primary source rechecked

Captured immutably in:

- `docs/wiki/raw/binaryen/2026-04-25-code-folding-current-main-recheck.md`

The current-main recheck covered official Binaryen GitHub sources for:

- `src/passes/CodeFolding.cpp`
- `src/passes/pass.cpp`
- `src/passes/opt-utils.h`
- `src/passes/passes.h`
- `test/lit/passes/code-folding.wast`

The earlier tagged manifest remains the main `version_129` source anchor:

- `docs/wiki/raw/binaryen/2026-04-22-code-folding-primary-sources.md`

## Durable findings

### 1. No teaching-relevant current-main drift was found

The rechecked current-main surfaces still teach the same contract already documented for `version_129`:

- expression-exit folding over named block exits and foldable `if` arms
- a separate function-ending suffix algorithm for `return`, `return_call*`, and `unreachable`
- unsupported branch forms poisoning label-based folding
- movement-safety checks around branch-target scope and EH-sensitive motion
- helper-block insertion governed by size heuristics
- EH nested-pop repair after block-adding rewrites

So the right wiki action was to add a source bridge and implementation/test map, not to rewrite the algorithm pages.

### 2. The official test surface is one dedicated lit file plus helper-sensitive negative families

`test/lit/passes/code-folding.wast` remains the central upstream proof surface.
It is important because it exercises more than the obvious positive examples:

- identical unnamed `if`-arm folds
- branch-value tail sharing
- branch-plus-fallthrough exit sharing
- function-ending helper-label folds
- `br_on_*` poisoning of label-based folds
- branch-target-scope bailout cases

This is now captured in the new implementation/test-map page so future Starshine port work can start with the official proof families instead of rediscovering them from the long strategy page.

### 3. The local status is unchanged and still worth spelling out precisely

Starshine still has no `src/passes/code_folding.mbt`, no `pass_manager` dispatcher branch for `code-folding`, and no active HOT descriptor for the pass.
The local status is instead:

- `src/passes/optimize.mbt:144-151` tracks `code-folding` under removed names
- `src/passes/optimize.mbt:469-471` rejects removed active-pass requests
- `src/cli/cli_test.mbt:159-165`, `src/cli/cli_test.mbt:297-303`, and `src/cli/cli_test.mbt:307-309` preserve the `--code-folding` spelling and explicit pass ordering
- `agent-todo.md:443-448` keeps the `CF` backlog slice alive
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md:33` records the canonical late slot before `merge-blocks`

The new page makes these exact local code locations easier to follow from the upstream source map.

## Files changed by this follow-up

### New raw-source manifest

- `docs/wiki/raw/binaryen/2026-04-25-code-folding-current-main-recheck.md`

### New living page

- `docs/wiki/binaryen/passes/code-folding/implementation-structure-and-tests.md`

### Refreshed living pages and catalogs

- `docs/wiki/binaryen/passes/code-folding/index.md`
- `docs/wiki/binaryen/passes/code-folding/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/code-folding/terminating-tails.md`
- `docs/wiki/binaryen/passes/code-folding/wat-shapes.md`
- `docs/wiki/binaryen/passes/code-folding/starshine-strategy.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`

## Supersession

This note does not supersede `0257`; it narrows and extends it.
`0257` remains the original source-manifest and Starshine-page follow-up.
This note adds the missing implementation/test-map page and a newer current-main source bridge.
