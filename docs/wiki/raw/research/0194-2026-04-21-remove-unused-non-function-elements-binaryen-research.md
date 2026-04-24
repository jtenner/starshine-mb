# Binaryen `remove-unused-non-function-elements` / upstream `remove-unused-nonfunction-module-elements` research

Date: 2026-04-21
Author: OpenAI Codex
Status: archived research feeding living wiki pages; superseded for raw-source provenance and Starshine local-status mapping by `0328-2026-04-24-remove-unused-non-function-elements-primary-sources-and-starshine-followup.md`, while still useful as the original source-confirmation note

## Scope and selection note

I re-read:

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`
- `src/passes/optimize.mbt`
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`
- the existing `remove-unused-module-elements` dossier

The original no-DWARF queue, the saved generated-artifact `-O4z` queue, and the first tracker-expansion wave are already dossier-covered.
That means the next eligible move has to be either:

- a justified major-gap fallback inside an already-deep folder, or
- a source-backed expansion for another real registry pass that still lacks a dedicated dossier

I picked exactly one pass:

- local registry alias `remove-unused-non-function-elements`
- upstream public Binaryen pass `remove-unused-nonfunction-module-elements`

I did **not** pick `type-un-finalizing` again.
I did **not** pick any pass from the explicit do-not-pick list.

`agent-todo.md` currently has **no dedicated `remove-unused-non-function-elements` or `remove-unused-nonfunction-module-elements` slice**.

## Why this is a justified tracker expansion

This is a justified upstream-only registry expansion because all of the following are true at once:

1. `src/passes/optimize.mbt` still names `remove-unused-non-function-elements` in the local boundary-only registry
2. `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md` still lists the same local alias in the boundary cleanup and ordering cluster
3. upstream Binaryen `version_129` still registers a real public sibling pass named `remove-unused-nonfunction-module-elements` in `src/passes/pass.cpp`
4. that sibling is not just a spelling alias for `remove-unused-module-elements`; it has a different constructor mode over the same engine
5. the real difference is teaching-important: Binaryen roots **all defined functions** before running the shared module-element pruner
6. Binaryen ships a dedicated pass test file, `test/passes/remove-unused-nonfunction-module-elements_all-features.wast`
7. without a dedicated folder, it is easy to mis-teach this pass as either:
   - a synonym for `remove-unused-module-elements`, or
   - a pass that literally never changes anything related to functions

That last mistake is especially likely because the local alias is slightly different from the upstream public name and because the real contract is more precise than the plain-English name suggests.

## Main source set

Primary official Binaryen `version_129` sources consulted:

- `src/passes/RemoveUnusedModuleElements.cpp`
- `src/passes/pass.cpp`
- `src/passes/passes.h`
- `test/passes/remove-unused-nonfunction-module-elements_all-features.wast`
- shared `remove-unused-module-elements*` lit files, especially:
  - `test/lit/passes/remove-unused-module-elements-configureAll.wast`
  - `test/lit/passes/remove-unused-module-elements-refs.wast`
  - `test/lit/passes/remove-unused-module-elements-tables.wast`
  - `test/lit/passes/remove-unused-module-elements_tnh.wast`

I also used the local `wasm-opt version 129` binary to run the dedicated upstream test file and inspect concrete output shapes for the sibling mode.

Important neighboring local pages already grounded in official sources:

- `docs/wiki/binaryen/passes/remove-unused-module-elements/*`
- `docs/wiki/binaryen/passes/remove-unused-types/*`
- `docs/wiki/binaryen/passes/global-type-optimization/*`

## High-level conclusion

Binaryen `remove-unused-nonfunction-module-elements` is the **same shared whole-module reachability and cleanup engine** as `remove-unused-module-elements`, but constructed with one crucial policy toggle:

- root all **defined** functions before analysis

That means the sibling should be taught as:

- **RUME with defined functions force-kept**
- not as a brand-new algorithm
- not as a pass that stops caring about function reachability completely
- not as a pass that promises to preserve every possible function-related declaration

A beginner-safe one-sentence summary is:

> Binaryen first marks every defined function as live, then runs the ordinary module-element cleanup pass so that memories, tables, globals, tags, segments, imports, and function types can still be pruned when unused.

## The biggest naming facts

There are two separate naming wrinkles here.

### Local versus upstream spelling

The Starshine local registry uses:

- `remove-unused-non-function-elements`

Upstream Binaryen registers:

- `remove-unused-nonfunction-module-elements`

So the local name is both shorter and more segmented than upstream:

- local keeps `non-function`
- upstream compresses that to `nonfunction`
- upstream also keeps `module` in the public pass name

That spelling split should stay explicit in future docs and port planning.

### The pass name is an approximation, not a literal law

The upstream name sounds like:

- “remove only non-function elements”

But the real implementation roots **defined** functions, not all functions.
So the pass can still change some function-adjacent things such as:

- unused imported functions
- unused function types
- start-function status when the start body is a no-op

That is the most important semantic correction in this dossier.

## Scheduler status

From `pass.cpp` and the local no-DWARF tracker:

- `remove-unused-nonfunction-module-elements` is a **real public Binaryen pass**
- it is **not** in the reviewed default no-DWARF `-O` / `-Os` path
- it does **not** appear in the saved generated-artifact `-O4z` skipped-pass audit
- locally it remains a **boundary-only** registry entry and is unimplemented

So this is a true upstream-only registry dossier, not a hidden preset gap.

## Core implementation structure

`RemoveUnusedModuleElements.cpp` defines one shared pass type:

- `struct RemoveUnusedModuleElements : public Pass`

The key mode field is:

- `bool rootAllFunctions`

The two public constructors are:

- `createRemoveUnusedModuleElementsPass()` -> `new RemoveUnusedModuleElements(false)`
- `createRemoveUnusedNonFunctionModuleElementsPass()` -> `new RemoveUnusedModuleElements(true)`

So the entire sibling split is source-backed and tiny:

- same analyzer
- same removal rules
- same helper dependencies
- different initial root policy

This is very similar in shape to other Binaryen sibling passes, but the practical effect is much larger than the size of the constructor delta.

## What the pass is *not*

This pass is **not**:

- a new module-analysis framework separate from RUME
- a preset-only internal mode with no public CLI name
- a promise to preserve imported functions
- a promise to preserve dead function types
- a promise to preserve a dead no-op start section
- a pass that stops reasoning about function references entirely

The correct teaching frame is:

- shared RUME engine
- defined functions force-rooted
- other removable module structure still cleaned normally

## Phase-by-phase reading of the upstream implementation

## Phase 0: `prepare()` still exists but is disabled

The file still contains a `prepare(module)` helper, but it returns immediately because the optimization is disabled behind a source comment about prior bugs.

That means the live `version_129` contract for both sibling passes is the conservative shared path.
There is no hidden pre-simplification step that the sibling depends on.

## Phase 1: root the start function, but drop no-op start metadata first

The pass begins by checking `module->start`.
If the start function is defined and its body is exactly `nop`, Binaryen removes the start declaration itself before adding roots:

- `module->start = Name{}`

Otherwise the start function becomes a root.

Important subtlety for the sibling:

- even if the start declaration is dropped for a no-op body,
- the defined function itself will still stay because the sibling later roots all defined functions

So the sibling can remove a start section without deleting the function body.

## Phase 2: the sibling-specific policy toggle roots all defined functions

This is the key branch:

- if `rootAllFunctions`, iterate all defined functions and root them as `ModuleElementKind::Function`

Binaryen does this with:

- `ModuleUtils::iterDefinedFunctions(*module, ...)`

That exact helper choice matters.
It means the sibling roots:

- every **defined** function

It does **not** automatically root:

- imported functions

This is the main source-backed reason the pass name must not be read too literally.

## Phase 3: ordinary RUME roots still apply too

After that sibling-specific step, the pass keeps all the usual RUME root logic:

- exports
- active segments that write to imported tables or memories
- active segments that may trap at startup unless `trapsNeverHappen`
- trapping element-segment initializers
- trapping global initializers

So the sibling is not merely “keep functions, remove everything else in one sweep.”
It still uses the full shared root model.

## Phase 4: the shared analyzer runs unchanged

The pass constructs the same:

- `Analyzer analyzer(module, options, roots);`

That shared analyzer computes the usual liveness sets and reachability edges.
So the sibling still depends on all the RUME helper surfaces:

- table flattening
- element contents
- `ref.func`
- `call_ref` and heap-type edges
- memory/table/tag/global use scanning
- startup trap retention

The sibling changes **what starts out rooted**, not **how the graph works**.

## Phase 5: removal rules run unchanged too

The cleanup stage is also shared.
The file still calls:

- `module->removeFunctions(...)`
- `module->removeGlobals(...)`
- `module->removeTags(...)`
- `module->removeMemories(...)`
- `module->removeTables(...)`
- `module->removeDataSegments(...)`
- `module->removeElementSegments(...)`

So the sibling does not skip the function-removal code path entirely.
Instead, it changes which function elements satisfy the analyzer's liveness checks.

That is a subtle but important porting rule.
A future port should not fork a brand-new simplified pass just because functions are kept more often.

## How the shared function-removal rule changes under `rootAllFunctions`

In ordinary RUME, functions fall into three broad cases:

1. strongly used -> keep them
2. referenced-only -> keep imported ones or replace defined ones with `unreachable`
3. unused and unreferenced -> remove them entirely

Under the sibling's `rootAllFunctions` mode, every defined function is rooted up front, so for **defined functions** the practical result is:

- they are kept as real bodies
- they are not replaced with `unreachable`
- dead defined cycles still survive

But because imported functions are not part of the special root-all step, unused imported functions can still be removed.

That one distinction explains most of the surprising observed outputs.

## Concrete observed output facts from the dedicated upstream test file

Using the local `wasm-opt version 129` binary on `test/passes/remove-unused-nonfunction-module-elements_all-features.wast`, I confirmed the following durable behaviors.

### Observed family 1: dead defined function islands stay

In the first module of the dedicated test file, dead defined functions like:

- `$remove0`, `$remove1`, `$remove2`, `$remove3`, `$remove4`

are still present after `--remove-unused-nonfunction-module-elements`.

That confirms the intended sibling policy: dead defined functions are preserved.

### Observed family 2: duplicate and unused function types still shrink

That same module drops duplicate function types such as:

- `$0-dupe`
- `$1-dupe`
- `$2-dupe`
- `$2-thrupe`

while keeping the defined functions that use the surviving canonicalized type set.

So the sibling is not “leave the function section completely untouched.”
It still compacts type-level module structure.

### Observed family 3: dead memories and tables can disappear entirely

Tiny modules containing only an unused memory and table reduce to:

```wat
(module)
```

That proves the sibling still does real non-function cleanup even when no functions exist at all.

### Observed family 4: exports still keep non-function elements alive

Imported or defined memories/tables survive when exported.
That is shared RUME behavior, inherited unchanged by the sibling.

### Observed family 5: active segments still keep parents alive when meaningful

Modules with active data or element segments keep the relevant imported memory or table alive, again through the shared engine.

### Observed family 6: real users keep parents alive too

Ordinary uses like:

- `i32.load`
- `memory.grow`
- `call_indirect`

still keep the corresponding memory/table alive.

### Observed family 7: dead imported functions can still be removed

One dedicated module in the upstream test file includes:

- imported function `$_puts` that is used
- imported function `$forget_puts` that is unused

After the sibling pass:

- `$_puts` stays
- `$forget_puts` is removed

That is the cleanest direct proof that the pass does **not** preserve all function declarations. It preserves all **defined** functions.

### Observed family 8: dead imported globals can still be removed

That same family also drops an unused imported global while preserving the imported global that still feeds a live global initializer.

### Observed family 9: dead tags can still be removed while defined functions stay

The last dedicated module removes non-exported tags but keeps the defined function body.
That confirms the sibling's intended area of aggression.

## Open-world versus closed-world meaning here

The sibling inherits the shared RUME analyzer, so the same open-world versus closed-world rules still matter in principle.
But because the sibling roots all defined functions, some of the most visible function-dropping differences become less dramatic.

A beginner-safe summary is:

- the shared engine still reasons about references conservatively in open world
- closed world can still matter for non-function reachability and for imported/reference-only surfaces
- but the sibling's force-rooting of defined functions intentionally overrides a large slice of ordinary function-elimination behavior

So if a future Starshine port models the sibling, it should reuse the same world-mode reasoning as the full pass rather than inventing a new simplified policy.

## Shared helper dependencies that still matter

Even though the sibling is a small constructor split, its real implementation still depends on the same helper world as RUME.

Key surfaces include:

- `ModuleUtils::iterDefinedFunctions(...)`
- `ModuleUtils::iterActiveDataSegments(...)`
- `ModuleUtils::iterActiveElementSegments(...)`
- `TableUtils` / flat table reasoning
- element-function-name iteration
- heap-type reachability helpers
- `FunctionTypeUtils` cleanup after function-level reachability is resolved

So a future port must preserve:

- shared whole-module graph reasoning
- shared type and index rewrite responsibilities
- sibling-specific root policy

and not just the final deletion list.

## Important module-shape families to teach

## Positive family 1: dead defined helper chain preserved

If a module contains dead defined helpers or cycles, the sibling keeps them.
That is the whole point of `rootAllFunctions = true`.

## Positive family 2: dead non-function declaration removed

If a memory, table, global, tag, data segment, or elem segment is unused and not otherwise retained by startup semantics, the sibling can still remove it.

## Positive family 3: dead function types cleaned even while bodies remain

The sibling can still shrink function types because the shared RUME cleanup surface includes type cleanup after function reachability is known.

## Positive family 4: unused imported function removed

If an imported function is unused and unreferenced, the sibling can still remove it because it is not part of the “root all defined functions” rule.

## Positive family 5: no-op start dropped while body remains

A defined no-op start function loses start status but remains in the module because the sibling roots defined functions after the no-op start check.

## Preserved family 1: exported non-function elements stay

Exports still root memories, tables, globals, and tags.

## Preserved family 2: active startup effects stay

Active segments writing into imported parents or potentially trapping during startup still keep the relevant declarations alive unless TNH changes the trap rule.

## Bailout family 1: `trapsNeverHappen` changes startup retention

The same shared TNH rule applies here.
Out-of-bounds startup segments may be removable under TNH even though they must stay without TNH.

## Bailout family 2: imported-versus-defined functions split the sibling contract

This is the easiest misunderstanding to preserve in docs.
The sibling's promise is effectively:

- keep defined functions

not:

- keep every function declaration of every kind

## What a future Starshine port must preserve

A faithful future port must preserve all of these source-backed rules:

1. use the shared RUME-style whole-module analyzer, not a brand-new ad hoc filter
2. model the local-vs-upstream naming split explicitly
3. root **defined** functions, not all functions
4. keep the ordinary export/start/segment/trap root logic unchanged
5. allow imported functions to remain removable when dead
6. keep function-type cleanup and other module-surface rewrites alive
7. preserve the no-op-start special case
8. preserve TNH-sensitive startup-segment retention
9. preserve the fact that this pass is not part of the default no-DWARF optimize path

## Easy mistakes to avoid

### Mistake 1: “This is just remove-unused-module-elements under another name.”

Wrong.
It is the same engine, but the root set changes enough to create a distinct public contract.

### Mistake 2: “This pass never changes anything related to functions.”

Wrong.
It still affects imported functions, function types, and start metadata.

### Mistake 3: “The upstream and local names match closely enough to ignore.”

Wrong.
The local alias drops `module` and changes `nonfunction` to `non-function`, which is exactly the kind of mismatch that later causes CLI or tracker confusion.

### Mistake 4: “Because functions are rooted, the rest of RUME no longer matters.”

Wrong.
The shared analyzer still drives most of the real behavior for memories, tables, globals, tags, and segments.

## Remaining uncertainty

I did **not** find an upstream public `version_129` registration for the even shorter local alias:

- `remove-unused`

So this thread does **not** claim that local alias corresponds to a real current public Binaryen pass.
That is a separate question and should not be silently conflated with the confirmed upstream sibling documented here.

## Bottom line

`remove-unused-nonfunction-module-elements` is best taught as:

- the **defined-functions-force-rooted** sibling of `remove-unused-module-elements`

That wording is more accurate than the public name alone, and it preserves the real source-backed contract:

- same `RemoveUnusedModuleElements.cpp` engine
- same module-element reachability logic
- one crucial `rootAllFunctions` policy split
- keep defined functions, but still clean the rest of the module honestly

## Source URLs

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RemoveUnusedModuleElements.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-nonfunction-module-elements_all-features.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-module-elements-configureAll.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-module-elements-refs.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-module-elements-tables.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-module-elements_tnh.wast>
