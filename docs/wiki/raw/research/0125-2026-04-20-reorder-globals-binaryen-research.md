# 0125 - `reorder-globals` Binaryen research

## Status

- Date: 2026-04-20
- Type: One-off raw investigation
- Scope: document one currently unimplemented Binaryen late global-layout pass in Starshine, using Binaryen `version_129` plus the saved generated-artifact audit to explain what `reorder-globals` actually does, how it scores candidate orders, which helper utilities it depends on, which module / WAT shapes it rewrites or preserves, and what a future Starshine port must keep exact.

## Why this pass

- `docs/wiki/binaryen/passes/tracker.md` still listed `reorder-globals` with wiki status `none` when this thread started.
- It is one of the tracker’s top suggested next targets and one of only two remaining `both`-relevance passes without a dossier after the same-day `string-gathering` work.
- In the canonical no-DWARF late tail, it runs immediately after `string-gathering` and immediately before `directize`, so it is the exact next step in the same scheduler neighborhood.
- The saved generated-artifact `-O4z` audit records a real skipped top-level upstream slot:
  - slot `55`
- The saved Binaryen debug log shows the pass is real but very small in that captured run:
  - `0.000166174` seconds
- The backlog already tracks it as slice `RG` in `agent-todo.md`.
- This pass is very easy to misdescribe as either:
  - “just sort globals by use count”, or
  - “the pass that fixes global ordering after string-gathering”, or
  - “a trivial declaration reorder that always helps size”.
- The actual source contract is more specific and more subtle:
  - it counts `global.get` **and** `global.set`
  - it counts those uses in functions **and** in module-level code
  - it builds a dependency DAG from `global.get` in global initializers
  - it tries **four** candidate orderings, not one
  - it scores candidates on estimated binary-size impact using the *real* use counts
  - the public pass intentionally bails out when there are fewer than `128` globals
  - the internal / test `reorder-globals-always` variant removes that cutoff and uses a smoothed cost model instead

That combination makes `reorder-globals` a good dossier target: the implementation is short enough to read fully, but the scheduler meaning, the under-`128` no-op rule, the import/dependency constraints, and the multi-option search are all easy to misunderstand.

## Saved local source material

### Local Starshine / audit sources

- `src/passes/optimize.mbt`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/string-gathering/binaryen-strategy.md`
- `docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md`
- `docs/wiki/raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.json`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json`
- `.artifacts/o4z-wasm-opt-debug.log`
- `agent-todo.md`

### Official Binaryen `version_129` sources

- `src/passes/ReorderGlobals.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/ReorderGlobals.cpp>
- `src/passes/pass.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `src/passes/passes.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- `src/pass.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h>
- `src/wasm-traversal.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-traversal.h>
- `src/support/topological_sort.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/support/topological_sort.h>
- `src/wasm.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm.h>
- `src/passes/GlobalStructInference.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GlobalStructInference.cpp>
- `test/lit/passes/reorder-globals.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/reorder-globals.wast>
- `test/lit/passes/reorder-globals-real.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/reorder-globals-real.wast>

## Fast answer

Binaryen’s `reorder-globals` pass is a late **module-wide declaration-layout optimizer**.

Its goal is to shrink the final binary by putting more heavily used globals at smaller indices, because smaller indices usually encode to fewer LEB bytes.

That sentence is true but incomplete.

The actual `version_129` implementation does all of this:

1. count `global.get` and `global.set` uses in functions and module-level code,
2. build a dependency DAG saying which globals must appear before other globals,
3. try four different topologically valid ordering heuristics,
4. estimate the resulting encoded-size cost using the true observed use counts,
5. pick the cheapest candidate order,
6. apply it by reordering the module’s global list.

The most durable source-derived facts are:

- The production pass skips all work when there are fewer than `128` globals.
- The test/internal `reorder-globals-always` variant removes that cutoff and uses a smooth synthetic cost model.
- Dependencies come only from `GlobalGet` inside **non-imported global initializers**, not from arbitrary function dataflow.
- Imports are always kept before defined globals.
- The pass is not a simple raw-count sort: it also tries an original-ish dependency-only order, a greedy raw-count order, a summed-dependent-count order, and an exponentially weighted dependent-count order.
- Candidate orders are judged using the **real** use counts, even when the candidate was generated with a synthetic count model.
- Ties in estimated size prefer the earliest option considered, which intentionally means the “closest to original order” candidate wins ties.
- Binaryen IR references globals by `Name`, so the pass only reorders `module->globals` and refreshes maps; it does not patch every `global.get` / `global.set` use site manually.
- The pass is intentionally different from `string-gathering`’s local validity repair sort.
  - `string-gathering` only ensures defining globals appear early enough to validate.
  - `reorder-globals` does the stronger late profitability/layout step.

## Where it appears in the scheduler

## Registered pass names

`pass.cpp` registers two relevant names:

- `reorder-globals`
  - normal production pass
  - description: “sorts globals by access frequency”
- `reorder-globals-always`
  - test pass
  - description: “sorts globals by access frequency (even if there are few)”

`passes.h` declares both constructors explicitly:

- `createReorderGlobalsPass()`
- `createReorderGlobalsAlwaysPass()`

That distinction matters a lot. The public optimize pipeline uses `reorder-globals`, not the `always` variant.

## Top-level no-DWARF path

`pass.cpp` schedules `reorder-globals` in `addDefaultGlobalOptimizationPostPasses()` when:

- `optimizeLevel >= 2`, **or**
- `shrinkLevel >= 1`

In this repo’s canonical no-DWARF `-O` / `-Os` path, it appears:

- after `duplicate-import-elimination`
- after `simplify-globals-optimizing`
- after the late `remove-unused-module-elements`
- after `string-gathering` when strings are enabled
- before `directize`

The relevant `pass.cpp` comment is especially useful here:

- Binaryen gathers strings to globals right before `reorder-globals`, which will then sort them properly.

That comment makes the division of labor explicit:

- `string-gathering` does a narrow validity-preserving reorder
- `reorder-globals` does the stronger final global ordering heuristic

## Saved generated-artifact `-O4z` audit

The saved ordered generated-artifact replay records:

- slot `55`: `reorder-globals`

The saved Binaryen debug log records one top-level runtime sample:

- `0.000166174` seconds

So this is not a heavy analysis pass. The implementation difficulty is in preserving the exact cost model and ordering constraints, not in matching a large runtime budget.

## Nested internal use

I found one especially important internal caller in `version_129`:

- `GlobalStructInference.cpp`

After that pass unnests struct operands into new helper globals, it creates a nested `PassRunner`, adds `reorder-globals-always`, marks the runner nested, and runs it.

That is a strong source signal that:

- the normal public pass is **not** enough for internal validity repair on small modules,
- Binaryen expects the `always` variant to be available when another pass introduces globals that must move earlier than their new users.

This also explains why the early-return cutoff in `ReorderGlobals.cpp` has a TODO about still needing to sort sometimes to fix dependencies.

## Actual implementation structure

## 1. A tiny parallel use-counting walker

`ReorderGlobals.cpp` starts with a function-parallel `UseCountScanner`:

- `WalkerPass<PostWalker<UseCountScanner>>`
- `isFunctionParallel() -> true`
- `modifiesBinaryenIR() -> false`

It only visits two node types:

- `visitGlobalGet(GlobalGet* curr)`
- `visitGlobalSet(GlobalSet* curr)`

Both increment a shared atomic count for the referenced global name.

That gives two important beginner facts immediately:

- writes count as heat too, not just reads,
- the cost model is purely structural / static use counting, not runtime profiling.

## 2. Counting happens in functions and in module-level code

Inside `run(Module* module)`, Binaryen creates the scanner and calls both:

- `scanner.run(getPassRunner(), module)`
- `scanner.runOnModuleCode(getPassRunner(), module)`

From `src/pass.h`, `runOnModuleCode(...)` delegates to the walker’s module-code traversal.
From `src/wasm-traversal.h`, `walkModuleCode(...)` covers module-level expression code such as:

- table initializer expressions
- defined global initializers
- element-segment offsets
- element-segment items
- data-segment offsets

So the pass does **not** just count global traffic inside function bodies.
It also counts global references in module-level expression slots.

That matters because global initializer uses influence both:

- the dependency graph, and
- the total static use counts.

## 3. The normal pass bails out below `128` globals

The first major control decision is:

- if `globals.size() < 128 && !always`, return immediately

The source comment explains why:

- with fewer than `128` globals, all global indices still fit in one-byte unsigned LEB form, so reordering cannot reduce code size under the real cost model.

But the same comment also contains a very important caveat:

- `TODO: we still need to sort here to fix dependencies sometimes`

That means the public pass currently prefers “no profitable size change” over “repair dependency order on tiny modules.”

This is not just a theoretical distinction.
It is why other code such as `GlobalStructInference` uses `reorder-globals-always` when it needs a real fixup.

A faithful port needs to decide whether to preserve this exact upstream behavior or intentionally diverge and document the change.

## 4. Counts start as atomics by name, then convert to indexed doubles

The pass first builds an `AtomicNameCountMap` for every global name.
After parallel counting completes, it constructs:

- `originalIndices: Name -> original index`
- `counts: vector<double>` indexed by original global position

The use counts are stored as `double`, not integer, because later candidate heuristics use fractional weighting.

That is why the implementation has two layers:

- atomic integer-ish counting during scanning,
- floating-point ranking during sort search.

## 5. Dependency graph: “global X must appear before globals that read it in their initializer”

The pass next builds a dependency graph over global declarations.
For each **non-imported** global initializer, it finds every `GlobalGet` inside the initializer using `FindAll<GlobalGet>`.

If global `i`’s initializer reads global `j`, then Binaryen records that:

- `j` must appear before `i`

The code stores this in a graph of “dependency -> dependents,” then converts it to `TopologicalSort::Graph`.

Important scope limit:

- only global-initializer dependencies matter here,
- not arbitrary function control flow,
- not arbitrary dataflow,
- not export order,
- not names.

That matches the real validity constraint: a global initializer may only refer to globals that are already available.

## 6. Binaryen tries four candidate ordering heuristics

This is the heart of the pass.

Binaryen does **not** compute one order and stop.
It computes several candidate orders, each produced by the same dependency-respecting `doSort(...)` routine but fed different “importance counts.”

The four options are:

### Option A: zero-count / original-ish order

Binaryen sets every count to zero.
That means ordering is driven only by:

- dependency constraints, and
- original order tie-breaking.

This is the “closest to original order” candidate.
It is added **first** on purpose, so if all candidates end up equal in estimated size, Binaryen prefers the least disruptive answer.

### Option B: raw-count greedy order

Binaryen feeds the true use counts directly into `doSort(...)`.
This is the most obvious interpretation of the pass name:

- among currently available globals, emit the hottest one first.

But the implementation comments explicitly warn that pure greed can be suboptimal.

### Option C: summed-dependent counts

Binaryen computes a reverse-topological accumulation where each global’s custom count becomes:

- its own true count
- plus the accumulated counts of all dependents it unlocks

This means a low-heat dependency can still rank highly if emitting it makes very hot dependents available sooner.

### Option D: exponentially weighted dependent counts

Binaryen also computes an exponential accumulation using:

- `EXPONENTIAL_FACTOR = 0.095`

So each global gets:

- its own count
- plus a small discounted contribution from dependents

This is a more conservative “unlock” heuristic than simple summation.

## 7. `doSort(...)`: lexicographically minimal topological order under a custom comparator

All four candidate sorts call the same helper:

- `doSort(const IndexCountMap& counts, const TopologicalSort::Graph& deps, Module* module)`

This helper calls:

- `TopologicalSort::minSort(deps, comparator)`

`topological_sort.h` documents `minSort(...)` as the lexicographically minimal topological sort according to a comparator.

Binaryen’s comparator does three things, in this order:

1. imported globals always beat defined globals
2. higher custom counts beat lower ones
3. ties fall back to original index order

That means the sort is always dependency-respecting, but among currently legal choices it picks the earliest according to:

- imports first,
- then hotter globals,
- then original stability.

## 8. Candidate scoring uses the *real* observed counts

After each candidate order is built, Binaryen scores it with:

- `computeSize(sort, counts)`

The second argument is always the **true** observed use counts, not the synthetic counts used to create the candidate.

That is a key algorithmic detail.
The alternative count models are only search heuristics.
They are *not* the final objective function.

## 9. Real production size model vs `always` size model

### Production `reorder-globals`

The normal size model estimates LEB cost by tracking when index encodings grow.
The threshold logic corresponds to unsigned LEB growth points:

- `0..127` -> 1 byte
- `128..16383` -> 2 bytes
- and so on

For each position in the candidate order, the pass multiplies:

- the true use count of that global
- by the current estimated LEB byte count for its index

Then it sums those contributions.

### `reorder-globals-always`

The `always` variant uses a smooth synthetic cost:

- `1.0 + i / 128.0`

So later indices become gradually more expensive even before the real LEB-size jump.

The source comment says this is unrealistic but smooth, and mainly useful for testing.

That explains the test split:

- `reorder-globals.wast` mostly uses `--reorder-globals-always` to make small modules visibly reorder,
- `reorder-globals-real.wast` is where Binaryen proves the actual production cutoff and 128-boundary behavior.

## 10. Best-candidate selection prefers the earliest minimum

Binaryen walks the candidate list in the same order it built it.
A candidate replaces the best-so-far only if its estimated size is strictly smaller.

So if two candidates have equal estimated size:

- the earlier candidate stays selected.

Because the zero-count / original-ish candidate is added first, equal-size ties prefer the least disruptive order.
This is a real behavior contract, not just an incidental detail.

## 11. Applying the result is just a declaration-list reorder plus `updateMaps()`

Once Binaryen picks a best order, it does:

- move `module->globals` aside,
- rebuild the vector in the chosen order,
- call `module->updateMaps()`.

It does **not** rewrite every use site.

The reason is visible in `src/wasm.h`:

- `GlobalGet` stores `Name name;`
- `GlobalSet` stores `Name name;`
- module lookup maps are also keyed by name

So the Binaryen IR identity of a global is symbolic, not “whatever dense index it currently has in the section vector.”
The eventual binary index changes when the writer serializes globals in the new order.

This is very important for a future Starshine port:

- if Starshine IR uses symbolic global identities, a reorder can be similarly cheap,
- if Starshine IR uses dense raw indices, then a faithful port will need an explicit remap across every global-index user.

That final sentence is an inference from the Binaryen representation and the Starshine backlog wording about preparing a reusable global-index remapper.

## What the shipped tests actually prove

## `reorder-globals.wast`

This test file mainly exercises `--reorder-globals-always`, which is what makes small hand-written modules informative.

The file proves all of these source-level facts:

- a more-used independent global moves earlier,
- `global.set` counts as a use just like `global.get`,
- dependency edges from global initializers override raw popularity,
- mixed independent-plus-dependent cases can place an independent hot global first while still keeping a dependency chain valid,
- equal-size situations fall back to original order,
- imports stay before defined globals even when a defined global is hotter,
- symbol names themselves do not influence the order,
- non-greedy search matters because raw greedy choice can be suboptimal,
- the “sum” option can beat both the raw greedy and the original-ish options.

## `reorder-globals-real.wast`

This file proves the production behavior that the normal pass uses:

- real `reorder-globals` does reorder once there are at least `128` globals,
- a 129-global case can justify keeping a long dependency chain before an independent but moderately hot global,
- a modified 129-global case can make the greedy answer optimal,
- with one fewer global the pass intentionally leaves the order alone.

## Important uncertainty from the tests

I did **not** find a shipped lit case that clearly isolates “the exponential candidate is uniquely the winner.”

The source absolutely computes and considers that option, so it is part of the implementation contract.
But the lit suite I found most clearly demonstrates:

- original-ish winning ties,
- raw greedy winning some cases,
- sum winning some cases,
- production cutoff behavior.

I am therefore treating “exponential candidate exists and can matter” as a direct source fact, but “here is the exact shipped test where only exponential wins” as an unresolved gap in the public test surface.

## Pass interactions

## After `simplify-globals-optimizing`

`reorder-globals` runs after the late global simplification cluster.
That means it sorts the already-cleaned global set, not the pre-cleanup surface.
Constant-folded or alias-collapsed globals from earlier passes affect the later frequency and dependency picture the reorder sees.

## After late `remove-unused-module-elements`

It also runs after late module pruning.
So any dead globals or unused module elements that disappear before the tail are not part of the final layout problem.

## After `string-gathering`

This is the clearest source-backed interaction.

`string-gathering` may:

- create new defining globals,
- force those globals earlier for validity,
- but deliberately leave better global ordering to `reorder-globals`.

A faithful Starshine port should preserve that separation.
If a port merges the two passes’ responsibilities, it may still be semantically correct, but it will no longer match Binaryen’s actual pipeline contract cleanly.

## Before `directize`

`reorder-globals` runs immediately before `directize` in the default late tail.
I did not find a specific code comment in `Directize.cpp` that depends on global order here, so the strongest claim I can make is:

- this is the final late global-layout cleanup before the optimizer moves on to the last indirect-call cleanup.

That sentence is an inference from scheduler placement, not a directly documented directize-specific dependency.

## Internal nested use by `GlobalStructInference`

This is the strongest “other pass depends on reorder-globals behavior” source fact I found.

`GlobalStructInference` adds new helper globals and then immediately runs `reorder-globals-always` in a nested pass runner so the new globals appear before their uses.

That means a future Starshine port should likely think about two surfaces:

- the public production `reorder-globals` pass,
- and a reusable internal helper / variant that can repair ordering even on small modules.

## Easy misunderstandings to avoid

- It is **not** just “sort by number of `global.get`s.”
  - `global.set` counts too.
- It is **not** a single greedy algorithm.
  - It tries four candidate strategies.
- It is **not** a function-level or CFG analysis pass.
  - Everything interesting happens at module/global-layout level.
- It is **not** primarily a validity-repair pass.
  - The public pass may skip entirely under `128` globals.
- It is **not** the same thing as `string-gathering`’s reorder.
  - gathering reorders for validity; `reorder-globals` reorders for size.
- It is **not** driven by symbol names.
  - names are irrelevant except as stable identity keys.
- It is **not** an export-order pass.
  - exports are not part of the cost model.
- It is **not** a direct use-site rewrite pass in Binaryen IR.
  - Binaryen IR stores symbolic global names, so declaration order is enough.

## What a future Starshine port must preserve

## Core parity checklist

A faithful port of public `reorder-globals` should preserve all of these:

- schedule it in the late post-pass tail after `string-gathering` and before `directize`,
- only run it for the same optimize/shrink gate as Binaryen’s public scheduler,
- keep the public under-`128` early return if exact parity is the goal,
- count both `global.get` and `global.set`,
- count uses in functions and module-level code,
- derive dependency edges only from `global.get` inside non-imported global initializers,
- keep imports before defined globals,
- use original order as the final tie-break inside a comparator,
- consider the same candidate-family search (`zero`, `raw`, `sum`, `exponential` with factor `0.095`),
- score candidates using the true observed counts rather than the synthetic heuristic counts,
- prefer the earliest equal-size candidate,
- apply the chosen order in a way that preserves all global references correctly.

## Representation-specific Starshine note

Binaryen can apply the result cheaply because its IR uses symbolic global names.
If Starshine stores indices more directly, then the port must make that invisible to semantics by remapping at least:

- `global.get`
- `global.set`
- global-initializer `global.get`
- any other stored global references in module metadata / exports / helpers

The exact remap surface is Starshine-specific, but the user-visible result must match the Binaryen ordering semantics.

## Internal-helper note

Because `GlobalStructInference` uses `reorder-globals-always`, a pragmatic Starshine plan may need:

- the public parity pass, and
- a small always-sort helper for internal callers that need dependency repair on tiny modules.

That is not a claim that both must land at the same time. It is a source-backed warning that public-pass parity alone may not cover every nested use case Binaryen has.

## Open questions and uncertainty

- I found no shipped lit case that obviously demonstrates an exponential-only win; the source still makes that option part of the real algorithm.
- I found no additional internal `version_129` caller of `reorder-globals-always` beyond `GlobalStructInference.cpp`; that may be exhaustive for this tag, but I am labeling it as “I found one explicit caller,” not “there are definitely no others anywhere upstream.”
- The directize interaction beyond simple scheduler adjacency is an inference from pass order, not a documented code-level dependency.
- The `TODO` in `ReorderGlobals.cpp` means upstream itself acknowledges a gap between “size-driven public pass” and “sometimes you still need dependency repair.” A faithful port should record that tension explicitly rather than smoothing it away.

## Bottom line

`reorder-globals` is a small but nontrivial late module-layout pass.

If I had to compress the source contract into one beginner-friendly sentence, it would be:

- Binaryen searches a few dependency-respecting ways to put the most index-sensitive globals earlier, keeps imports and initializer dependencies honest, skips the whole thing on small modules in public mode, and leaves use-site rewriting unnecessary because its IR tracks globals by name.

That is a much better mental model than either:

- “sort by hottest global,” or
- “repair global order after string-gathering,” or
- “always optimize global declarations for size.”

## Sources

### Local sources

- `src/passes/optimize.mbt`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/string-gathering/binaryen-strategy.md`
- `docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md`
- `docs/wiki/raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.json`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json`
- `.artifacts/o4z-wasm-opt-debug.log`
- `agent-todo.md`

### Official Binaryen `version_129` sources

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/ReorderGlobals.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-traversal.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/support/topological_sort.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GlobalStructInference.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/reorder-globals.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/reorder-globals-real.wast>
