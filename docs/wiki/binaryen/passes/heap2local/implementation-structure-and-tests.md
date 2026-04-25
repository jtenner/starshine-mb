---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-heap2local-current-main-and-code-map.md
  - ../../../raw/binaryen/2026-04-22-heap2local-primary-sources.md
  - ../../../raw/research/0365-2026-04-25-heap2local-current-main-and-code-map.md
  - ../../../raw/research/0245-2026-04-22-heap2local-primary-sources-and-code-map-followup.md
  - ../../../raw/research/0135-2026-04-20-heap2local-binaryen-research.md
  - ../../../../../src/passes/heap2local.mbt
  - ../../../../../src/passes/heap2local_test.mbt
  - ../../../../../src/passes/heap2local_primary_test.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./validation-fixups-and-special-cases.md
  - ./wat-shapes.md
  - ./starshine-hot-ir-strategy.md
  - ./parity.md
---

# `heap2local` implementation structure and tests

This page maps the source-backed implementation and proof surfaces for Binaryen `heap2local`, then names the exact Starshine code and tests that currently implement the local subset.

Use this page when you want to answer:

- “Which upstream files actually own the pass?”
- “Which tests prove the public behavior?”
- “Where should I start reading Starshine code?”
- “Which behaviors are source-backed but not fully local yet?”

## Upstream owner-file map

### `src/passes/Heap2Local.cpp`

This is the whole upstream pass body. In `version_129` and current `main`, it owns these teaching-relevant pieces:

1. **Per-function setup**
   - `LazyLocalGraph`, scratch-local state, `Parents`, and branch-target state are prepared once per function.
   - An allocation finder gathers reachable structs and arrays and notes whether EH `pop` exists.

2. **Nonescape and exclusivity proof**
   - `EscapeAnalyzer` walks child-to-parent flow, local set/get flow, and branch-carried value flow.
   - Its `ParentChildInteraction` lattice separates `Escapes`, `FullyConsumes`, `Flows`, `Mixes`, and `None`.
   - `getsAreExclusiveToSets()` is the separate proof that a local get cannot read a competing provenance family.

3. **Array-to-struct lowering**
   - Eligible arrays are small fixed-size shapes: constant size, below the `< 20` cap, and analyzable element use.
   - Binaryen rewrites them into synthetic structs before scalarizing fields.
   - This is why upstream array behavior is broader than a simple “replace each element with a local” loop.

4. **Struct-to-local scalarization**
   - `Struct2Local` introduces field locals, descriptor locals, and scratch locals for initializer ordering.
   - It replaces disappearing reference traffic with `ref.null` placeholders when that keeps the tree valid during transition.
   - It folds direct `ref.is_null`, `ref.eq`, `ref.as_non_null`, `ref.test`, `ref.cast`, and `ref.get_desc` families when the optimized allocation makes the answer static.
   - It preserves packed-field semantics through packed get helpers and handles atomic, RMW, and cmpxchg variants when the object identity cannot synchronize with other threads.

5. **Repair**
   - In-pass `ReFinalize` repairs types after nullability, cast, OOB, or synthetic-type rewrites.
   - EH nested-pop repair runs when rewritten functions contained `pop`.

### `src/passes/pass.cpp`

`pass.cpp` contributes the public pass contract:

- public name: `heap2local`
- summary: `replace GC allocations with locals`
- scheduler placement in the GC mid-function cleanup cluster, gated by optimization level and GC support.

That one-line summary is deliberately smaller than the real source contract. Treat it as the public CLI label, not the full strategy.

### `src/pass.h` and `src/ir/type-updating.h`

The generic pass framework is part of the correctness story:

- `Heap2LocalPass` does not opt out of nonnullable-local fixups.
- The pass runner's after-effects path can call `TypeUpdating::handleNonDefaultableLocals(...)`.

This is why the dossier treats nondefaultable-local repair as part of Binaryen `heap2local`, even though some of it lives outside `Heap2Local.cpp`.

### Helper headers

The upstream pass also depends on these helpers:

- `src/ir/local-graph.h` for local set/get provenance and exclusivity checks.
- `src/ir/parents.h` for parent traversal.
- `src/ir/branch-utils.h` for branch-sent value flow.
- `src/ir/eh-utils.h` for nested-pop repair.
- `src/ir/bits.h` for packed-field get repair.
- `src/ir/properties.h` for expression-side-effect classification.
- `src/wasm-builder.h` for replacement expression construction.

## Upstream test map

### `test/lit/passes/heap2local.wast`

The dedicated lit file is the main visible proof surface. It covers the user-facing families future docs should keep recognizable:

- direct struct owners and field get/set replacement;
- local-copy and control-flow cases that keep the optimized allocation exclusive;
- bailout cases for escapes, mixed provenance, and nonexclusive local flow;
- array positives and negatives, including constant-size limits and dynamic-index boundaries;
- packed fields;
- atomic get/set and source-visible RMW/cmpxchg-related behavior;
- direct reference-operation folds and validation-sensitive shapes;
- cleanup interactions with later passes such as `vacuum`.

Important evidence boundary:

- The source is broader than the easiest-to-see lit snippets for descriptors, some cast families, and some atomic/RMW/cmpxchg details.
- The 2026-04-25 current-main check did not find a new teaching family in the dedicated lit file beyond the already-known typo cleanup. Keep the source-vs-lit split explicit.

## Current-main drift status

The 2026-04-25 current-main check did **not** change the teaching contract.

Keep this exact interpretation:

- `version_129` remains the released semantic oracle for the dossier.
- Current `main` has narrower source-level refinements already recorded in the older freshness note: tighter array interaction handling, clearer cmpxchg expected-vs-ref handling, and an explicit unreachable-`ref.test` skip.
- The dedicated lit file still does not visibly add a matching new broad teaching family.

## Current Starshine implementation map

Current Starshine implements a meaningful but narrower HOT/use-def subset.

### Registry, presets, and dispatcher

- `src/passes/heap2local.mbt:2-16`
  - descriptor, required HOT analysis (`use_def`), and invalidated analyses.
- `src/passes/heap2local.mbt:18-20`
  - public summary.
- `src/passes/optimize.mbt:201-205`
  - active hot-pass registry entry.
- `src/passes/optimize.mbt:253-257`, `src/passes/optimize.mbt:392-396`
  - `optimize` preset placements.
- `src/passes/optimize.mbt:265-269`, `src/passes/optimize.mbt:405-409`
  - `shrink` preset placements.
- `src/passes/pass_manager.mbt:8698`
  - direct hot-pass dispatcher case.

### Struct analysis and rewrite

- `src/passes/heap2local.mbt:84-145`
  - struct/default/descriptor-bearing allocation recognition.
- `src/passes/heap2local.mbt:468-558`
  - one-write struct owner candidate matcher.
- `src/passes/heap2local.mbt:1219-1347`
  - struct candidate rewrite into field locals, including tee/block wrapper repair.

### Array analysis and rewrite

- `src/passes/heap2local.mbt:562-658`
  - supported `array.new_default`, `array.new`, and `array.new_fixed` initializer gate with the `< 20` cap.
- `src/passes/heap2local.mbt:660-725`
  - direct array-use matcher for constant-index get/set families.
- `src/passes/heap2local.mbt:695-748`
  - array candidate matcher.
- `src/passes/heap2local.mbt:1164-1216`
  - direct array rewrite into element locals.

### Direct ref folds and driver

- `src/passes/heap2local.mbt:1056-1159`
  - direct fresh-struct `ref.eq`-against-null, descriptor `ref.get_desc`, and array `ref.test` folds.
- `src/passes/heap2local.mbt:1349-1376`
  - detached live-node deletion.
- `src/passes/heap2local.mbt:1379-1442`
  - public run function: module context, use-def, candidate scan, candidate application, direct-ref fold pass, cleanup, mutation marking.

## Current Starshine test map

- `src/passes/heap2local_test.mbt:86-453`
  - focused direct pass tests for struct owners, copy chains, tee owners, block flow, `ref.as_non_null`, successful `ref.cast`, direct `ref.eq`, descriptor-bearing `ref.get_desc`, array lowering, array `ref.test`, and parameter-backed bailout.
- `src/passes/heap2local_primary_test.mbt:158-568`
  - broader Binaryen-aligned primary suite covering positives plus call escape, mixed provenance, nonconstant array size, and loop-carried provenance bailouts.
- `src/passes/optimize_test.mbt:398-403`
  - preset neighbor lock for `remove-unused-brs -> heap2local -> simplify-locals`.
- `src/passes/optimize_test.mbt:435-446`
  - trace/order evidence that the modeled local pipeline hands `heap2local` output to `simplify-locals`.
- `src/passes/registry_test.mbt:2-31`, `src/passes/registry_test.mbt:102-133`, `src/passes/registry_test.mbt:146-160`
  - active hot-pass classification, descriptor requirement, and preset roster coverage.

## Local-vs-upstream matrix

| Surface | Binaryen `version_129` | Current Starshine |
| --- | --- | --- |
| Main proof model | `EscapeAnalyzer` plus `LazyLocalGraph` exclusivity | HOT use-def, one-write owner, supported-use family matching |
| Struct scalarization | Field locals, descriptor locals, scratch temps, null placeholders | Field locals for supported struct owner shapes; descriptor direct fold subset |
| Array path | Array -> synthetic struct -> struct scalarization | Direct array element locals for constant-index supported families |
| Direct ref ops | Broad direct `ref.*` family including casts/tests/descriptors | Focused `ref.eq` against null, descriptor `ref.get_desc`, array `ref.test`, plus selected candidate-use folds |
| Packed/atomic/RMW/cmpxchg | Source-backed and partly lit-backed | Not full upstream surface today |
| Repair | `ReFinalize`, EH nested-pop repair, generic nondefaultable-local fixups | HOT mutation/writeback path; no documented full equivalent to Binaryen's nondefaultable-local repair layer |
| Scheduler neighbors | Full GC/local cluster including missing local neighbors | Simplified active slot before `simplify-locals` |

## Practical reading order

For upstream behavior:

1. `Heap2Local.cpp`
2. `heap2local.wast`
3. `pass.cpp`
4. `pass.h` / `type-updating.h`

For Starshine behavior:

1. `src/passes/heap2local.mbt:1379-1442` for the pass driver.
2. `src/passes/heap2local.mbt:468-558` and `src/passes/heap2local.mbt:695-748` for accepted candidate shapes.
3. `src/passes/heap2local.mbt:1219-1347` and `src/passes/heap2local.mbt:1164-1216` for emitted replacements.
4. `src/passes/heap2local_test.mbt` and `src/passes/heap2local_primary_test.mbt` for current proof surfaces.

## Sources

- [`../../../raw/binaryen/2026-04-25-heap2local-current-main-and-code-map.md`](../../../raw/binaryen/2026-04-25-heap2local-current-main-and-code-map.md)
- [`../../../raw/binaryen/2026-04-22-heap2local-primary-sources.md`](../../../raw/binaryen/2026-04-22-heap2local-primary-sources.md)
- [`../../../raw/research/0365-2026-04-25-heap2local-current-main-and-code-map.md`](../../../raw/research/0365-2026-04-25-heap2local-current-main-and-code-map.md)
- [`../../../raw/research/0245-2026-04-22-heap2local-primary-sources-and-code-map-followup.md`](../../../raw/research/0245-2026-04-22-heap2local-primary-sources-and-code-map-followup.md)
- [`../../../raw/research/0135-2026-04-20-heap2local-binaryen-research.md`](../../../raw/research/0135-2026-04-20-heap2local-binaryen-research.md)
- [`../../../../../src/passes/heap2local.mbt`](../../../../../src/passes/heap2local.mbt)
- [`../../../../../src/passes/heap2local_test.mbt`](../../../../../src/passes/heap2local_test.mbt)
- [`../../../../../src/passes/heap2local_primary_test.mbt`](../../../../../src/passes/heap2local_primary_test.mbt)
