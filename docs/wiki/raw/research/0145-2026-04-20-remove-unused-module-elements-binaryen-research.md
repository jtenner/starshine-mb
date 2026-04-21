# 0145 - Binaryen `remove-unused-module-elements` research

## Scope

- Continue the Binaryen pass wiki-ing campaign after the refreshed `tuple-optimization` dossier.
- Follow the repo wiki workflow in `docs/README.md`.
- Re-check the tracker, index, canonical no-DWARF path, and active backlog before choosing a pass.
- Justify an already-`deep` fallback pick explicitly, because the tracker no longer has a `none` queue or an implemented-landing queue.
- Deepen the existing `remove-unused-module-elements` folder with a much more source-backed explanation of how Binaryen actually implements the pass.
- Keep the result beginner-friendly without hiding the important graph, rewrite, and reference-only details.
- File the durable conclusions back into:
  - `docs/wiki/binaryen/passes/remove-unused-module-elements/`
  - `docs/wiki/binaryen/passes/index.md`
  - `docs/wiki/binaryen/passes/tracker.md`
  - `docs/wiki/index.md`
  - `docs/wiki/log.md`

## Candidate selection

I followed the campaign instructions in order:

1. read `docs/README.md`
2. read `docs/wiki/binaryen/passes/tracker.md`
3. read `docs/wiki/binaryen/passes/index.md`
4. read `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
5. re-checked the relevant backlog context in `agent-todo.md`

The tracker no longer had any pass with wiki status `none`, and the old implemented-landing queue was already closed by the recent `remove-unused-names` work.
So this run needed a justified major-gap fallback instead of another obvious `none` or `landing` pick.

I picked `remove-unused-module-elements` for four source-backed reasons:

- It is still on the canonical no-DWARF optimize path three times:
  - early slot `2`
  - early slot `6`
  - late slot `49`
- It is also relevant to the saved generated-artifact optimize evidence even though it is not an unimplemented skipped-slot target:
  - `.artifacts/o4z-wasm-opt-debug.log` shows real `remove-unused-module-elements` executions at lines `51`, `68`, and `994`
- The existing folder was useful, but it still taught the pass mostly as a Starshine-side liveness/remap feature set:
  - the landing page was short
  - the Binaryen strategy page was still only a high-level summary
  - the folder did **not** yet have a dedicated page for the exact upstream file map, helper dependencies, or official test surface
  - the folder also lacked a focused living explanation of the easiest thing to misunderstand: Binaryen's split between `used` and `usedReferenced`, and the fact that some referenced-only non-function elements are weakened rather than deleted outright
- That gap is major because this pass sounds like “dead function cleanup,” while the official source is really a whole-module graph-and-rewrite pass with import/export roots, flat-table analysis, GC heap-type reachability, reference-only weakening, and function-type cleanup ordering

So this thread is not a tracker-status promotion job.
It is a “the folder exists, but it still lacks the exact upstream implementation teaching surface” job.

## Official Binaryen source inventory

Primary `version_129` sources used for this research:

- implementation:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RemoveUnusedModuleElements.cpp>
- pass registration and scheduler placement:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- important helper surfaces the pass actually depends on:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/element-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/gc-type-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/table-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/FunctionTypeUtils.cpp>
- representative official tests:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-module-elements_all-features.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-module-elements-eh-old.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-module-elements-refs.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-nonfunction-module-elements_all-features.wast>

## Freshness and source-trust rule

This dossier treats Binaryen `version_129` as the release oracle.

I did a narrow spot-check of the still-most-important `main` surfaces while researching the living pages:

- the scheduler still registers both `remove-unused-module-elements` and `remove-unused-nonfunction-module-elements`
- the core `used` / `usedReferenced` / `processUsers` / removal shape in `RemoveUnusedModuleElements.cpp` still matches the released algorithm on the sections checked here
- the source still keeps the disabled `prepare()` prepass behind the same FIXME about missing things hidden inside unreachable code

That is intentionally a **narrow** freshness statement, not a whole-file proof.
The durable wiki rule for now is:

- use `version_129` as the normative algorithm oracle
- treat later upstream changes as a future explicit follow-up, not as something this thread silently smuggles into the released summary

## Repo-local sources used for context

Starshine-side files that mattered while refreshing the dossier:

- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `.artifacts/o4z-wasm-opt-debug.log`
- `agent-todo.md` (`RUME` slice)
- `docs/wiki/raw/research/0090-2026-04-16-gen-valid-rume-imported-function-parity-followup.md`
- `docs/wiki/raw/research/0091-2026-04-16-gen-valid-rume-start-section-parity-followup.md`
- `src/passes/remove_unused_module_elements.mbt`
- `src/passes/remove_unused_module_elements_test.mbt`
- `src/passes/pass_manager.mbt`
- `src/passes/optimize.mbt`
- `src/cmd/cmd_wbtest.mbt`

## High-level conclusion

Binaryen `remove-unused-module-elements` is not mainly a dead-function pass.

It is a whole-module reachability and rewrite pass with five interlocked jobs:

1. seed liveness from exports, start, module code, and function bodies
2. distinguish **strongly used** elements from **merely referenced** ones
3. propagate reachability through function bodies, tables, GC field types, and element/data segment edges until the queue is empty
4. clean up function types before final removal
5. either delete, keep, or weaken surviving module elements while rewriting every remaining user surface

The pass name hides the two most important ideas:

- the graph is richer than “who calls which function?”
- some referenced-only non-function elements are not deleted; they are replaced with inert null-style definitions when Binaryen can prove that is valid

That second point is the real beginner trap.
The pass is not just “mark and sweep.”
It is “mark, distinguish strength of reachability, then remove or weaken accordingly.”

## Why the upstream implementation is easy to misread

The source file is long, but the actual algorithm is organized around a small number of durable stages.
The easiest wrong readings are:

### Wrong idea 1: “It just removes dead functions and then remaps indices.”

That misses:

- `call_ref` heap-type rooting
- flat-table entry rooting
- GC field-type rooting
- active-segment parent retention
- reference-only weakening of globals, tables, memories, and tags
- the separate `remove-unused-nonfunction-module-elements` mode

### Wrong idea 2: “Referenced means used.”

Binaryen explicitly keeps two sets:

- `used`
- `usedReferenced`

The difference matters because some elements can be named or typed without being semantically used in a way that forces the original declaration to stay intact.

### Wrong idea 3: “Deletion happens uniformly for every kind.”

It does not.
Functions, globals, tables, memories, tags, elem segments, and data segments all have different retention rules.
Non-function elements can also be nullified rather than removed.

## Exact Binaryen implementation structure

`RemoveUnusedModuleElements.cpp` actually ships two public pass names:

- `remove-unused-module-elements`
- `remove-unused-nonfunction-module-elements`

The implementation is one `Pass` subclass parameterized by `bool nonFunction`.
The non-function variant reuses the same graph logic but skips function deletion.

The important stages are these.

## Phase 0: setup and the disabled `prepare()` fast path

The pass owns:

- `ElementSet all`
- `ElementSet used`
- `ElementSet usedReferenced`
- `Module* module`
- `TableUtils::FlatTable flatTable`
- `bool nonFunction`

The source also still contains a disabled `prepare()` helper behind `#if 0`.
The comment says it misses references hidden inside unreachable code.
That means the shipped `version_129` algorithm is the conservative, slower path, not the aspirational future one.

This is a durable implementation fact worth teaching because it explains why the source still scans broadly instead of using a tighter one-shot summary.

## Phase 1: seed roots from module code and function-body scans

The top-level `scan()` phase does three big things.

### A. `FunctionInfoScanner` over defined functions

Binaryen iterates defined functions with `ModuleUtils::iterDefinedFunctions` and runs a nested scanner that:

- records function-to-function edges from calls and `ref.func`
- records strong non-function users found inside bodies
- records `call_ref` heap types
- records GC field/type references through `struct.get`

This is the main body-level user collection step.

### B. `useModuleCode()` over exports, start, and module-code expressions

Binaryen also roots:

- exports
- the start function
- module code such as global initializers and active segment offsets via `ModuleUtils::iterModuleCode`

This matters because a module element can be live even if no defined function body touches it.

### C. separate scans of globals, tables, memories, tags, elems, and data

The pass then walks every declared element kind and roots the ones already known to have direct users.
That gives the later queue stage a complete starting frontier.

## Phase 2: distinguish `used` from `usedReferenced`

This is the conceptual heart of the pass.

When Binaryen sees an element, it does **not** always treat it as strongly used.
The source keeps two sets.

### `used`

This means the element must stay semantically live in its strong original role.
Examples include:

- direct calls to functions
- exports and start
- strong table/memory/tag/segment operations
- active parent tables or memories for non-no-op segments

### `usedReferenced`

This means the element is still mentioned somewhere relevant, but the mention may be weak enough that Binaryen can later simplify or nullify the declaration.

This is how the pass represents cases such as:

- imported functions only referred to by `ref.func` / typed table traffic
- tables, memories, globals, or tags named by GC/reference metadata rather than strongly executed operations

The easiest beginner-safe summary is:

- `used` means “must stay as a real live declaration”
- `usedReferenced` means “cannot be forgotten yet, but might not need to stay in its original form”

## Phase 3: helper-specific edge discovery

Several official helper surfaces matter here.

### `useCallRefType(...)`

For a `call_ref` heap type, Binaryen uses `GCTypeUtils::collectHeapTypes` to gather the relevant heap types, then walks functions whose types are subtypes of those collected candidates.

That is why `call_ref` is a whole-module root, not just a local function-body detail.

### `useStructField(...)`

The pass also scans struct field types through `GCTypeUtils::collectHeapTypes` and can mark functions, tables, memories, or tags referenced by field heap types.

That is a big reason the pass matters for GC modules even when the surface name sounds like ordinary dead-code cleanup.

### `flatTable.build(...)`

`TableUtils::FlatTable` lets the pass inspect statically known table contents.
That means a referenced table can keep function references alive even when there is no direct call in any function body.

### `ElementUtils::iterAllElementFunctionNames(...)`

Element segment contents are another real edge source.
If an elem segment stays live, the functions named inside it may stay live too.

## Phase 4: queue-driven fixpoint over element users

After the initial scan, Binaryen calls `processUsers()`.
This is the real graph walk.

The source uses a queue of newly strong-used elements and processes them until no new user edges appear.
The durable mental model is:

- seed the queue from strong roots
- when an element becomes strongly used, inspect its outgoing edges
- any newly strong-used targets enter the queue
- stop only when the queue reaches a fixed point

Important examples:

- a newly live function can make more functions, globals, tables, memories, tags, elem segments, or data segments live through its body
- a newly live table can make elem segments and flat-table function contents relevant
- a newly live memory can keep active data segments alive
- a newly live elem or data segment can in turn root its own function or memory/table users

So the actual algorithm is closer to a whole-module graph propagation pass than to a one-pass filter.

## Phase 5: active-segment parent retention is shape-sensitive

Binaryen does **not** keep active parents alive unconditionally.
It checks whether the active segment is actually semantically meaningful.

The living rule visible in the source and tests is:

- non-no-op active elem segments can keep their parent table alive
- non-empty active data segments can keep their parent memory alive
- all-null active elem initializers can stop retaining the table
- zero-byte active data can stop retaining the memory

That nuance is exactly why this pass deserves a real WAT-shape page.

## Phase 6: removal is ordered, and function types are cleaned first

The removal phase is easy to oversimplify.
The source does it in a careful order.

### First: functions and function types

If `nonFunction` is false, Binaryen removes unused functions.
Then it runs `FunctionTypeUtils::removeUnusedTypes`.

That ordering matters because later deletion and remapping would otherwise leave type noise behind or force more awkward type rewrites.

### Then: globals, tables, memories, tags, elem segments, data segments

Those are removed or simplified only after the graph has stabilized and the function/type surface is cleaned up.

## Phase 7: non-function elements may be nullified instead of deleted

This is the single most important detail that the old dossier did not explain well enough.

For globals, tables, memories, and tags, the source distinguishes cases where an element:

- is strongly used -> keep it
- is not even referenced -> remove it
- is only referenced -> maybe replace it with a removable inert definition instead of keeping the original declaration

That weakening happens through `NullifyRemovableElement`.

The exact kind-specific legality rules are source-driven, but the durable beginner rule is:

- a reference-only non-function element can survive as a cheaper inert placeholder rather than as the original imported or defined declaration

This is the most important difference between “garbage collection” and “Binaryen RUME.”

## Phase 8: exported or externally visible items still constrain removal

The pass uses `canRemove`-style checks before deleting declarations.
That means exports and other visibility constraints still matter late in the pipeline.

So a future port must not collapse the logic to:

- “if not in `used`, erase it”

It must preserve the stronger source rule:

- visibility, reference strength, and kind-specific weakening legality all matter

## Official test-surface lessons

The official lit files teach the algorithm better than the pass name does.

### `remove-unused-module-elements_all-features.wast`

This is the broad surface file.
It proves the pass cares about:

- funcs, globals, tables, memories, tags
- elem/data operations and drops
- active versus passive segments
- index rewriting after removal
- all-features interactions rather than only MVP modules

### `remove-unused-module-elements-refs.wast`

This is the most useful file for the major gap this thread is closing.
It shows that the pass is really about:

- `ref.func`
- `call_ref`
- GC heap-type reachability
- reference-only versus strong-use distinctions

### `remove-unused-module-elements-eh-old.wast`

This proves tags and exception edges are part of the real surface.
The pass is not only about call/data/table reachability.

### `remove-unused-nonfunction-module-elements_all-features.wast`

This makes the sibling mode explicit:

- same overall graph style
- functions intentionally preserved
- non-function cleanup still applied

That file is the clearest proof that the `nonFunction` flag is not a documentation accident.

## Scheduler meaning

In the canonical no-DWARF optimize path, `remove-unused-module-elements` appears three times:

1. right after `duplicate-function-elimination`
2. again after `global-refining`
3. again late after `simplify-globals-optimizing`

That scheduler placement makes sense once the real algorithm is visible.

- early runs trim obvious dead module structure before later passes do more expensive work
- the middle run reclaims elements that become dead after global/type refinement
- the late run cleans up after whole-module global simplification has created new dead declarations

The saved generated-artifact optimize log also shows repeated real runs in practice, not just on paper.

## What is easy to misunderstand

### 1. This is not only a function pass in module clothing

The pass genuinely reasons about tables, memories, globals, tags, elem segments, data segments, exports, start, and module-code expressions.

### 2. `ref.func` and direct `call` do not mean the same thing here

`call` is a strong function-use root.
`ref.func` feeds the reference-aware side of the graph and interacts with `usedReferenced`.

### 3. Active parents are not kept alive unconditionally

A no-op active segment can stop retaining its table or memory.
The source and tests are deliberate about that.

### 4. “Referenced-only” does not always mean “keep the original declaration”

For non-function elements it can mean “replace with an inert removable declaration.”

### 5. The non-function sibling pass is real

`remove-unused-nonfunction-module-elements` is not a docs alias.
It is an actual mode with the same graph core and a different final deletion boundary.

## What a future Starshine port or maintenance pass must preserve

A faithful implementation must preserve all of these source-level contracts:

1. root seeding from exports, start, module code, and defined function bodies
2. separate tracking of strong use versus reference-only reachability
3. `call_ref` heap-type and GC field-type rooting
4. flat-table and elem-content function rooting
5. active-segment parent retention only for semantically non-no-op segments
6. queue-driven fixed-point propagation rather than one shallow scan
7. function deletion before unused function-type cleanup and before later non-function removal
8. kind-specific nullification/weakening of reference-only non-function elements
9. the sibling `remove-unused-nonfunction-module-elements` mode
10. full surviving-index rewrite honesty after removal

A faithful implementation does **not** need to copy the C++ literally.
But it does need to preserve those semantics.

## Durable documentation outcomes from this thread

This thread closes the biggest remaining teaching gap in the RUME folder by adding:

- a new raw research note anchored in official `version_129` sources, helper files, official tests, the canonical scheduler page, and the saved generated-artifact log
- a rewritten landing page that makes the real graph-and-rewrite nature of the pass explicit
- a rewritten Binaryen strategy page that explains the staged algorithm rather than only the three-state slogan
- a richer WAT/module-shape page that teaches positive, negative, and weakening families
- a new living page focused on the exact upstream file map and official tests
- a new living page focused on roots, reference-only reachability, and nullification, which was the biggest old beginner-to-intermediate gap

## Files updated in this change

- `docs/wiki/raw/research/0145-2026-04-20-remove-unused-module-elements-binaryen-research.md`
- `docs/wiki/binaryen/passes/remove-unused-module-elements/index.md`
- `docs/wiki/binaryen/passes/remove-unused-module-elements/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/remove-unused-module-elements/wat-shapes.md`
- `docs/wiki/binaryen/passes/remove-unused-module-elements/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/remove-unused-module-elements/roots-reference-only-and-nullification.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`

## Sources

- Repo process and tracker context:
  - `docs/README.md`
  - `docs/wiki/binaryen/passes/tracker.md`
  - `docs/wiki/binaryen/passes/index.md`
  - `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
  - `agent-todo.md`
- Repo-local pass evidence:
  - `.artifacts/o4z-wasm-opt-debug.log`
  - `docs/wiki/raw/research/0090-2026-04-16-gen-valid-rume-imported-function-parity-followup.md`
  - `docs/wiki/raw/research/0091-2026-04-16-gen-valid-rume-start-section-parity-followup.md`
  - `src/passes/remove_unused_module_elements.mbt`
  - `src/passes/remove_unused_module_elements_test.mbt`
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RemoveUnusedModuleElements.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/element-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/gc-type-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/table-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/FunctionTypeUtils.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-module-elements_all-features.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-module-elements-eh-old.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-module-elements-refs.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-nonfunction-module-elements_all-features.wast>
