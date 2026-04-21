---
kind: entity
status: working
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0224-2026-04-21-legalize-and-prune-js-interface-binaryen-research.md
  - ../legalize-js-interface/index.md
  - ../../no-dwarf-default-optimize-path.md
  - ../../../../../agent-todo.md
  - ../tracker.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./prune-boundary-matrix.md
  - ./wat-shapes.md
  - ../legalize-js-interface/index.md
  - ../tracker.md
---

# `legalize-and-prune-js-interface`

## Role

- `legalize-and-prune-js-interface` is a real public Binaryen pass.
- It is currently **upstream-only** in this repo's living pass map: it is **not** in Starshine's local optimizer registry in `src/passes/optimize.mbt`.
- It is **not** part of the repo's canonical no-DWARF `-O` / `-Os` optimize path.
- `agent-todo.md` currently has **no dedicated `legalize-and-prune-js-interface` slice**.

## Why this dossier exists

The tracker currently has no obvious remaining pass entries with wiki status `none`.
That means a new dossier needs explicit justification.

`legalize-and-prune-js-interface` meets that bar because the newly-added plain `legalize-js-interface` dossier already depends on keeping the prune sibling explicit, but until now the sibling still had no canonical page of its own.

Without this folder, it was too easy to blur together:

- plain `legalize-js-interface`, which only legalizes `i64`-bearing function boundaries with wrappers and temp-ret helpers, and
- `legalize-and-prune-js-interface`, which first runs that same legalization and then removes exports or synthesizes trivial bodies for boundary items that still expose JS-hostile features.

## Beginner summary

A good beginner mental model is:

- start with ordinary `i64` JS-boundary legalization
- then ask whether any import/export surface is still illegal for JS because of SIMD, multivalue results, exception handling, or stack switching
- if an illegal function is imported, replace the import with a trivial internal function body
- if an illegal function or global is exported, remove the export
- refinalize afterward because `ref.func`-visible type facts may have changed

So this pass is best taught as:

- **plain JS-boundary `i64` legalization plus prune-mode boundary sanitization**
- not as a general feature-lowering pass
- not as a semantic-preserving JS shim for unsupported features
- not as a whole-module legalization pass

## Most important durable takeaways

- The entire reviewed `version_129` contract still lives in the same shared owner file as the plain sibling: `LegalizeJSInterface.cpp`.
- The pass is implemented as `LegalizeAndPruneJSInterface : LegalizeJSInterface`, and its `run(...)` literally calls the plain pass first and `prune(module)` second.
- The prune legality rule is broader than the plain pass's `i64` test: it rejects boundary-visible types whose feature set includes SIMD, multivalue, exception handling, or stack switching.
- Multivalue **params** are tolerated, but multivalue **results** are not.
- Illegal imported functions are turned into defined functions with one of three bodies: `nop`, a zero/default literal, or `unreachable`.
- Illegal exported functions and illegal exported globals simply lose their exports.
- Binaryen runs `ReFinalize()` after function pruning because `ref.func`-visible type facts may have shifted when imports become internal definitions.
- A current-`main` spot check found `LegalizeJSInterface.cpp` and the dedicated `legalize-and-prune-js-interface.wast` proof file unchanged from `version_129`.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Main implementation walkthrough: the two-phase run order, the subclass legality rule, import replacement, export removal, and the exact split from plain legalization.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  Compact owner-file and proof-surface map for the subclass inside `LegalizeJSInterface.cpp`, the public registration in `pass.cpp`, and the dedicated prune lit file.
- [`./prune-boundary-matrix.md`](./prune-boundary-matrix.md)
  Focused guide to the easy-to-forget behavior matrix: import vs export, function vs global, and defaultable vs nondefaultable result handling.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly before/after shape catalog for stubbed imports, removed exports, retained plain `i64` wrappers, and the import-plus-export combined case.

## Current maintenance rule

- Treat this folder as the canonical home for future `legalize-and-prune-js-interface` research.
- Keep it explicitly marked as an **upstream-only** dossier unless Starshine later grows a real registry entry for this surface.
- Keep the split from plain `legalize-js-interface` explicit: this sibling begins with the same `i64` wrapper pass, but then changes the boundary semantics from **adapt** to **adapt where possible, otherwise stub or hide**.
- Keep the split from `i64-to-i32-lowering` explicit too: this family only touches the JS boundary, not arbitrary internal `i64` module code.

## Sources

- [`../../../raw/research/0224-2026-04-21-legalize-and-prune-js-interface-binaryen-research.md`](../../../raw/research/0224-2026-04-21-legalize-and-prune-js-interface-binaryen-research.md)
- [`../legalize-js-interface/index.md`](../legalize-js-interface/index.md)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../tracker.md`](../tracker.md)
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LegalizeJSInterface.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/legalize-and-prune-js-interface.wast>
- Current-`main` spot-check sources:
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/LegalizeJSInterface.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/legalize-and-prune-js-interface.wast>
