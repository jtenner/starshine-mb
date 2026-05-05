---
kind: research
status: supported
last_reviewed: 2026-05-05
sources:
  - ../binaryen/2026-05-05-directize-current-main-recheck.md
  - ../binaryen/2026-04-26-directize-port-readiness-primary-sources.md
  - ../binaryen/2026-04-22-directize-primary-sources.md
  - ../../binaryen/passes/directize/index.md
  - ../../binaryen/passes/directize/binaryen-strategy.md
  - ../../binaryen/passes/directize/implementation-structure-and-tests.md
  - ../../binaryen/passes/directize/table-info-and-immutability.md
  - ../../binaryen/passes/directize/wat-shapes.md
  - ../../binaryen/passes/directize/starshine-strategy.md
  - ../../binaryen/passes/directize/starshine-port-readiness-and-validation.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../agent-todo.md
  - ../../binaryen/no-dwarf-default-optimize-path.md
---

# `directize` current-main recheck

## Why this follow-up exists

`directize` already had a healthy dossier, but the freshness bridge was still anchored to 2026-04-25. This follow-up refreshes the living pages with a 2026-05-05 current-main bridge and keeps the final-tail contract explicit instead of letting older freshness wording linger.

## Primary source added

New raw source bridge:

- `docs/wiki/raw/binaryen/2026-05-05-directize-current-main-recheck.md`

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
The same durable model still holds:

- module-wide table-info computation comes before any function rewrite;
- an all-tables-hostile module returns before walking functions;
- `CallIndirect` remains the direct visitor surface;
- constant targets classify to known direct call, known trap, or unknown;
- trap rewrites preserve child side effects;
- nonconstant targets still use the narrow `select` helper;
- post-edit type repair remains part of the pass contract;
- the dedicated lit surface still covers all-features table/direct/trap/select/mutation cases, GC subtype compatibility, and wasm64 index width.

### 2. The main beginner hazard remains over-widening the pass

The source bridge did not support teaching any of these as current Binaryen behavior:

- generic `call_ref` directization;
- arbitrary symbolic target solving;
- partial directization when a `select` has one known arm and one unknown arm;
- treating imported/exported tables as safe in ordinary mode;
- using `directize-initial-contents-immutable` to skip flat-table construction;
- a nested cleanup rerun owned by `Directize.cpp` itself.

### 3. `table.copy` remains a source-backed mutation barrier with weaker direct lit evidence

The current `table-utils.cpp` surface still treats destination `table.copy` as a table mutation barrier.
The living table-info page should keep that distinction explicit:

- source-backed barrier: destination `table.copy`;
- stronger direct lit evidence: `table.set`, `table.fill`, and `table.init`.

### 4. Starshine's exact local status is unchanged but now fresher

The recheck does not change the local status:

- `src/passes/optimize.mbt:281` still registers `directize` as an active module pass.
- `src/passes/pass_manager.mbt:8940` still dispatches `directize` through the module-pass path.
- `agent-todo.md:687-693` still tracks the `DIR` slice around indirect-to-direct eligibility and rewrite/artifact proof.
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md:35` still places `directize` as the final canonical no-DWARF post-pass slot after `reorder-globals`.

## Living pages refreshed

- `docs/wiki/binaryen/passes/directize/index.md`
- `docs/wiki/binaryen/passes/directize/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/directize/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/directize/table-info-and-immutability.md`
- `docs/wiki/binaryen/passes/directize/wat-shapes.md`
- `docs/wiki/binaryen/passes/directize/starshine-strategy.md`
- `docs/wiki/binaryen/passes/directize/starshine-port-readiness-and-validation.md`
- `docs/wiki/index.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/log.md`

## Follow-up rule

Future `directize` wiki work should start from the existing dossier plus this source bridge, not by making a new folder.
Only rewrite the pass strategy if a later primary-source check shows a real semantic change to table-info gating, target classification, select lowering, trap preservation, or post-rewrite type repair.
