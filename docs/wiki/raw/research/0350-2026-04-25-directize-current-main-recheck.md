---
kind: research
status: supported
last_reviewed: 2026-04-25
sources:
  - ../binaryen/2026-04-25-directize-current-main-recheck.md
  - ../binaryen/2026-04-22-directize-primary-sources.md
  - ../../binaryen/passes/directize/index.md
  - ../../binaryen/passes/directize/binaryen-strategy.md
  - ../../binaryen/passes/directize/implementation-structure-and-tests.md
  - ../../binaryen/passes/directize/table-info-and-immutability.md
  - ../../binaryen/passes/directize/wat-shapes.md
  - ../../binaryen/passes/directize/starshine-strategy.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../agent-todo.md
  - ../../binaryen/no-dwarf-default-optimize-path.md
---

# `directize` current-main recheck

## Why this follow-up exists

The pass tracker currently has no obvious still-`none` queue, so this run picked an already deep dossier with a concrete health issue: `directize` still carried 2026-04-22 freshness wording even though it is a final-tail, unimplemented parity blocker whose table-analysis and call-rewrite boundaries are easy to overstate.

This follow-up does not create a duplicate pass dossier.
It refreshes the existing one with a current-main source bridge and tightens the cross-page wording around what remains source-backed today.

## Primary source added

New raw source bridge:

- `docs/wiki/raw/binaryen/2026-04-25-directize-current-main-recheck.md`

It records the official Binaryen current-`main` URLs checked for:

- `src/passes/Directize.cpp`
- `src/passes/pass.cpp`
- `src/passes/passes.h`
- `src/passes/call-utils.h`
- `src/ir/table-utils.h`
- `src/ir/table-utils.cpp`
- `src/ir/type-updating.h`
- `test/lit/passes/directize_all-features.wast`
- `test/lit/passes/directize-gc.wast`
- `test/lit/passes/directize-wasm64.wast`

## Durable findings

### 1. No teaching-relevant drift from the `version_129` dossier

The current-main recheck did not find evidence that the existing living contract needs an algorithm rewrite.
The existing `version_129` model still holds:

- module-wide table-info computation comes before any function rewrite;
- an all-tables-hostile module returns before walking functions;
- `CallIndirect` remains the direct visitor surface;
- constant targets classify to known direct call, known trap, or unknown;
- trap rewrites preserve child side effects;
- nonconstant target support remains the narrow `select` helper;
- post-edit type repair remains part of the pass contract;
- the dedicated lit surface still covers all-features table behavior, GC subtype compatibility, and wasm64 index width.

### 2. The main beginner hazard remains over-widening the pass

The source bridge did not support teaching any of these as current Binaryen behavior:

- generic `call_ref` directization;
- arbitrary symbolic target solving;
- partial directization when a `select` has one known arm and one unknown arm;
- treating imported/exported tables as safe in ordinary mode;
- using `directize-initial-contents-immutable` to skip flat-table construction;
- a nested cleanup rerun owned by `Directize.cpp` itself.

The living pages were refreshed to keep those non-goals visible instead of letting the short public pass summary “turns indirect calls into direct ones” dominate the mental model.

### 3. `table.copy` remains a source-backed mutation barrier with weaker direct lit evidence

The current `table-utils.cpp` surface still treats destination `table.copy` as a table mutation barrier.
The living table-info page already taught this distinction correctly, but the refresh keeps the wording explicit:

- source-backed barrier: `table.copy` destination;
- stronger direct directize-lit evidence: `table.set`, `table.fill`, and `table.init`.

This is a useful confidence distinction for future Starshine tests.

### 4. Starshine's exact local status is unchanged but now fresher

The recheck does not change the local status:

- `src/passes/optimize.mbt:128-134` still tracks `directize` in `pass_registry_boundary_only_names()`.
- `src/passes/optimize.mbt:462-468` still rejects active pipeline requests for boundary-only passes.
- `agent-todo.md:687-691` still tracks the `DIR` slice around indirect-to-direct eligibility and rewrite/artifact proof.
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md:34-35` still places `directize` as the final canonical no-DWARF post-pass slot after `reorder-globals`.

The Starshine strategy page now cites the current-main bridge and keeps the exact code-location map visible.

## Living pages refreshed

- `docs/wiki/binaryen/passes/directize/index.md`
- `docs/wiki/binaryen/passes/directize/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/directize/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/directize/table-info-and-immutability.md`
- `docs/wiki/binaryen/passes/directize/wat-shapes.md`
- `docs/wiki/binaryen/passes/directize/starshine-strategy.md`
- `docs/wiki/index.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/log.md`

## Follow-up rule

Future `directize` wiki work should start from the existing dossier plus this source bridge, not by making a new folder.
Only rewrite the pass strategy if a later primary-source check shows a real semantic change to table-info gating, target classification, select lowering, trap preservation, or post-rewrite type repair.
