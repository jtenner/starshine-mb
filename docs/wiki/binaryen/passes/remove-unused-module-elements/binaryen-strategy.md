---
kind: concept
status: supported
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0145-2026-04-20-remove-unused-module-elements-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RemoveUnusedModuleElements.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/element-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/gc-type-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/table-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/FunctionTypeUtils.cpp
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./roots-reference-only-and-nullification.md
  - ./wat-shapes.md
  - ./parity.md
  - ../../no-dwarf-default-optimize-path.md
---

# Binaryen `remove-unused-module-elements` strategy

## Upstream source rule

Use Binaryen `version_129` as the current algorithm oracle for this pass.

Primary files:

- `src/passes/RemoveUnusedModuleElements.cpp`
- `src/passes/pass.cpp`
- `src/ir/element-utils.h`
- `src/ir/gc-type-utils.h`
- `src/ir/module-utils.h`
- `src/ir/table-utils.h`
- `src/passes/FunctionTypeUtils.cpp`
- the shipped `remove-unused-module-elements*` lit tests

This page stays algorithm-oriented.
Use [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md) for the exact file map and test inventory, and use [`./roots-reference-only-and-nullification.md`](./roots-reference-only-and-nullification.md) for the hardest semantic subtopic.

## High-level intent

Binaryen uses `remove-unused-module-elements` as a whole-module graph-and-rewrite pass.
It is not just a dead-function filter.

The real job is closer to:

- find which module elements are strongly used
- find which ones are only still referenced
- propagate both kinds of reachability through functions, tables, GC heap types, and segments
- then delete or weaken declarations and rewrite every remaining user surface

That is why the pass sits in module-pass territory instead of in a function-local cleanup layer.

## The pass in one table

| Stage | What Binaryen does | Why it matters |
| --- | --- | --- |
| Setup | build `all`, `used`, `usedReferenced`, and a `FlatTable` view | the pass reasons about more than one liveness strength and more than one edge source |
| Initial scan | inspect function bodies, exports, start, module code, globals, tables, memories, tags, elem, and data | roots do not come only from function calls |
| Queue fixpoint | process newly-strong-used elements until no new edges appear | this is a graph pass, not a one-pass filter |
| Function/type cleanup | remove unused functions, then clean unused function types | removal order is part of correctness and final compactness |
| Non-function cleanup | remove or weaken globals/tables/memories/tags/elem/data | some kinds can be nullified instead of deleted |

## Phase 0: setup and the still-disabled `prepare()` shortcut

The pass owns:

- `ElementSet all`
- `ElementSet used`
- `ElementSet usedReferenced`
- `Module* module`
- `TableUtils::FlatTable flatTable`
- `bool nonFunction`

The source also still contains a disabled `prepare()` helper behind `#if 0`.
The comment says it misses things hidden inside unreachable code.
That is a real source fact worth preserving:

- the shipped `version_129` algorithm is the conservative broad-scan path
- there is no hidden optimized pre-summary that the live pass already relies on today

## Phase 1: seed roots from function bodies and module code

The initial `scan()` phase does not just look at exports.
It has several root-seeding subpasses.

### A. scan defined functions with `FunctionInfoScanner`

Binaryen iterates defined functions with `ModuleUtils::iterDefinedFunctions` and visits their bodies to collect:

- direct function users like `call`
- reference-style function users like `ref.func`
- `call_ref` heap-type candidates
- strong users of globals, tables, memories, tags, elem, and data
- GC field-type references reachable through `struct.get`

### B. seed exports, start, and module code

`useModuleCode()` roots:

- exports
- the start function
- module-code expressions such as global initializers and active segment offsets through `ModuleUtils::iterModuleCode`

This is the first major beginner correction.
A module element can be live even if no ordinary function body calls or touches it.

### C. scan each declared element kind

The pass also iterates globals, tables, memories, tags, elem segments, and data segments directly.
That is how it discovers roots and edges that exist only in declaration structure or segment payloads.

## Phase 2: `used` versus `usedReferenced` is the semantic core

Binaryen keeps two different liveness-strength sets.

### `used`

This means the element must stay strongly live in its original semantic role.
Examples include:

- exports
- start
- direct calls
- live table/memory/tag operations
- live active parent tables or memories for meaningful active segments

### `usedReferenced`

This means the element is still named or typed somewhere relevant, but the reference is not always strong enough to force the original declaration to remain unchanged.

That distinction is what lets Binaryen be more precise than a plain mark-and-sweep pass.
The focused consequences are explained on [`./roots-reference-only-and-nullification.md`](./roots-reference-only-and-nullification.md), but the durable summary is:

- `used` = definitely semantically live
- `usedReferenced` = still matters somehow, but later removal/weakening rules may differ

## Phase 3: helper-driven edge discovery matters more than the name suggests

Several helper surfaces are part of the real algorithm.

### `GCTypeUtils::collectHeapTypes`

Binaryen uses this both for:

- `call_ref` rooting
- struct-field heap-type rooting

That means the pass follows GC-typed declaration edges, not just instruction indices.

### `TableUtils::FlatTable`

Binaryen builds a flat-table view so statically known table entries can keep functions referenced or live.
That is one of the reasons a table can matter even when it has no obvious direct call site.

### `ElementUtils::iterAllElementFunctionNames`

Live elem segments can keep functions around through their contents.
That is a direct official source edge, not an implementation accident.

### `FunctionTypeUtils::removeUnusedTypes`

Function-type cleanup is an explicit part of the pass contract after function removal.
It is not left to some generic later compaction pass.

## Phase 4: `processUsers()` is a queue-driven fixed point

After the initial scan, Binaryen repeatedly processes newly strong-used elements until no new ones appear.

This matters because liveness is not shallow.
A newly strong-used element can reveal more edges:

- a live function can mention more globals/tables/memories/tags/segments/functions
- a live table can keep elem segments and flat-table function contents alive
- a live memory can keep active data segments alive
- a live elem or data segment can keep its contents or parents alive

So the pass should be understood as a whole-module graph propagation step with several different edge kinds, not as one direct filter pass.

## Phase 5: active-segment parent retention is deliberately shape-sensitive

Binaryen does not automatically keep an active parent table or memory alive just because an active segment names it.

The retained rule is closer to:

- meaningful active elem segments can keep their parent table alive
- meaningful active data segments can keep their parent memory alive
- all-null active elem payloads can stop retaining the table
- zero-byte active data can stop retaining the memory

That nuance is a major source-backed reason this pass needs a real shape catalog.

## Phase 6: removal order is part of the strategy

The removal phase is not “delete everything dead in one sweep.”

### First: functions, unless `nonFunction` is enabled

When the full pass is running:

- remove unused functions
- then clean unused function types

This ordering is explicit in the source and matters for the final compact module surface.

### Then: globals, tables, memories, tags, elem segments, and data segments

Only after the graph is stable and the function/type surface is cleaned up does Binaryen finish the rest of the removal work.

That staged order is one of the main reasons the pass is easier to preserve as a module rewrite than as a collection of independent per-kind filters.

## Phase 7: some reference-only non-function elements are weakened, not deleted

This is the part the old folder explained least clearly.

For globals, tables, memories, and tags, the source distinguishes cases where an element is:

- strongly used -> keep it
- not even referenced -> remove it
- referenced-only -> maybe replace it with an inert removable declaration rather than keeping the original one

That weakening goes through `NullifyRemovableElement`.
So the pass is not only about deletion.
It is also about reducing a declaration to the weakest still-valid form.

## Phase 8: the sibling non-function pass is part of the real strategy

Binaryen also registers:

- `remove-unused-nonfunction-module-elements`

This is not a docs-only alias.
It is the same graph core with `nonFunction = true`, which means:

- keep functions
- still clean up non-function module elements

That variant is important both for understanding the source and for keeping future Starshine docs honest about what is one algorithm versus what is a separate public pass mode.

## Scheduler placement is part of the pass meaning

In the canonical no-DWARF path, Binaryen runs `remove-unused-module-elements` three times:

1. after `duplicate-function-elimination`
2. after `global-refining`
3. late after `simplify-globals-optimizing`

That makes sense once the actual algorithm is visible:

- early runs trim obvious dead module structure
- the middle run reclaims things exposed by global/type refinement
- the late run cleans up declarations made dead by global simplification and other whole-module rewrites

The saved generated-artifact optimize log also shows real executions in practice, not just on the preset page.

## What the pass sounds like versus what it actually is

What it sounds like:

- a module-level “delete dead declarations” cleanup

What it actually is:

- a whole-module graph pass with:
  - multiple root sources
  - strong versus reference-only reachability
  - GC/type and flat-table helper edges
  - shape-sensitive active-segment retention
  - ordered function/type cleanup
  - kind-specific deletion versus weakening rules
  - and a sibling non-function-only mode

That is the behavior a future Starshine parity port must preserve.

## Bottom line

Binaryen `remove-unused-module-elements` is a graph-and-rewrite pass whose central design idea is:

- **not every surviving mention is the same kind of liveness**

Once that idea is understood, the rest of the file makes much more sense:

- why it needs helper-heavy scanning
- why the queue is necessary
- why function types are cleaned in the middle
- and why some reference-only declarations are weakened instead of simply erased
