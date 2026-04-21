---
kind: concept
status: supported
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0125-2026-04-20-reorder-globals-binaryen-research.md
related:
  - ./index.md
  - ./size-model-and-dependency-order.md
  - ./wat-shapes.md
  - ../string-gathering/index.md
  - ../../no-dwarf-default-optimize-path.md
---

# Binaryen `reorder-globals` strategy

## Upstream source rule

- Use Binaryen `version_129` as the current source oracle for this pass.
- The core implementation lives in `src/passes/ReorderGlobals.cpp`.
- Scheduler placement comes from `src/passes/pass.cpp`.
- Pass construction is declared in `src/passes/passes.h`.
- The walker helper surface for module-level code comes from `src/pass.h` and `src/wasm-traversal.h`.
- The ordering helper comes from `src/support/topological_sort.h`.
- The reason Binaryen can apply the final order without rewriting every use site is visible in `src/wasm.h`, where `GlobalGet` and `GlobalSet` refer to globals by `Name`.
- The main shipped behavior examples come from `test/lit/passes/reorder-globals.wast` and `test/lit/passes/reorder-globals-real.wast`.
- The most important internal caller I found is `src/passes/GlobalStructInference.cpp`, which uses `reorder-globals-always` after adding helper globals.

Primary source URLs:

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

## High-level intent

Binaryen uses `reorder-globals` to make the final binary smaller by moving more frequently referenced globals toward smaller indices.

That sentence is true but incomplete.

The actual implementation is a late **count + dependency-graph + candidate-search + pick-the-cheapest-order** pass.

A good mental model is:

| Stage | What Binaryen does | Why it exists |
| --- | --- | --- |
| Count | Count `global.get` and `global.set` uses in functions and module code | Find which globals are index-sensitive |
| Constrain | Build a DAG from global-initializer `global.get` dependencies | Keep declaration order valid |
| Search | Try several dependency-safe order heuristics | Pure greed is not always best |
| Score | Estimate encoded-index cost with the true counts | Pick the order that should shrink the binary most |
| Apply | Reorder the global declaration list and refresh maps | Change eventual binary indices |

That means this pass is not:

- a function-local peephole pass
- a CFG or effects analysis pass
- just a raw-count sort
- just a validity repair after `string-gathering`
- dead global elimination
- a use-site patching pass in Binaryen IR

## Pass names and scheduler placement

`pass.cpp` exposes two relevant names here:

- `reorder-globals`
- `reorder-globals-always`

The first is the production pass.
The second is a test pass / internal helper variant.

The default global optimization post-pass cluster runs `reorder-globals` when:

- `optimizeLevel >= 2`, or
- `shrinkLevel >= 1`

In the canonical no-DWARF `-O` / `-Os` path tracked in this repo, the pass appears:

- after `duplicate-import-elimination`
- after `simplify-globals-optimizing`
- after the late `remove-unused-module-elements`
- after `string-gathering` when strings are enabled
- before `directize`

The `pass.cpp` comment about `string-gathering` is the most explicit scheduler explanation:

- strings are gathered to globals right before `reorder-globals`, which will then sort them properly

So the intended late-tail division of labor is:

- `string-gathering`
  - fix up defining string globals so the module validates
- `reorder-globals`
  - do the stronger final cost-based global layout step

## Important public-vs-`always` fact

The public pass and the `always` variant are intentionally different.

The public production pass returns immediately when:

- there are fewer than `128` globals, and
- the pass is not in `always` mode

The source comment explains the reason:

- below `128`, global indices still fit in one-byte ULEB form, so reordering cannot improve size under the real production cost model

But that same comment also says there is still a dependency-fixup TODO.
That is why the `always` variant matters.

## Stage 1: count static global traffic

## The walker only cares about `global.get` and `global.set`

The scan phase uses a tiny function-parallel `PostWalker` that implements just:

- `visitGlobalGet(GlobalGet* curr)`
- `visitGlobalSet(GlobalSet* curr)`

Both increment a shared atomic count map keyed by global name.

This is the first easy beginner correction:

- writes count too, not just reads

The pass is trying to shrink index encodings wherever those indices appear in code, and both `global.get` and `global.set` encode a global index.

## Functions are scanned in parallel

`UseCountScanner` overrides:

- `isFunctionParallel() -> true`
- `modifiesBinaryenIR() -> false`

So Binaryen can count function-body uses in parallel without mutating the module while it scans.

## Module-level code is scanned separately

After scanning ordinary functions, the pass also calls:

- `runOnModuleCode(getPassRunner(), module)`

From `src/pass.h`, that delegates to the walker’s module-code traversal.
From `src/wasm-traversal.h`, that module-code walk covers expression-bearing module slots such as:

- table initializer expressions
- defined global initializers
- element-segment offsets
- element-segment items
- data-segment offsets

Practical beginner takeaway:

- the pass is broader than “global traffic in functions”
- it is meant to see global references anywhere Binaryen stores module-level expression code

## Stage 2: turn name counts into indexed count vectors

Binaryen first creates atomic counts keyed by global `Name` so parallel counting is safe.
After the scan, it converts to:

- `originalIndices: Name -> original index`
- `counts: vector<double>` indexed by original global position

`double` matters here because later candidate heuristics use fractional weighting.
So while the real observations are integer counts, the ranking layer is intentionally more flexible.

## Stage 3: build a dependency DAG from global initializers

The pass must keep global order valid.

For each non-imported global initializer, Binaryen finds every `GlobalGet` inside the initializer with `FindAll<GlobalGet>`.
If global `$b`’s initializer reads `$a`, then `$a` must appear before `$b`.

The pass stores that as a graph from:

- dependency -> dependents

Then it materializes a `TopologicalSort::Graph`.

Important scope limit:

- only initializer `GlobalGet` dependencies matter here
- not arbitrary function uses
- not exports
- not names
- not unrelated metadata

This is a declaration-order validity rule, not a whole-program dataflow problem.

## Stage 4: compute several candidate sorts

This is the main algorithmic point that the pass name hides.

Binaryen does **not** trust one obvious greedy answer.
It generates several candidate orders using the same dependency-aware sorting helper but different custom count vectors.

### Candidate 1: all zeroes

This candidate ignores profitability entirely.
It only respects:

- dependency constraints, and
- original-order tie-breaking

It is the closest thing to “keep the original order unless dependencies force a change.”
Binaryen adds it first so that equal-size ties prefer a stable low-churn result.

### Candidate 2: true counts

This is the obvious greedy version:

- among the globals currently legal to emit, prefer the one with the highest real count

### Candidate 3: sum of dependents

Binaryen computes a reverse-topological accumulation where each global’s custom count becomes:

- its own true count
- plus the full accumulated counts of its dependents

That lets a low-heat prerequisite rank highly if it unlocks a very hot chain.

### Candidate 4: exponentially weighted dependents

Binaryen also tries a discounted accumulation with:

- `EXPONENTIAL_FACTOR = 0.095`

That means a global gets:

- its own count
- plus a small discounted contribution from the things it unlocks

This is still dependency-aware, but less aggressive than a full sum.

## Stage 5: `doSort(...)` computes a minimal topological order under a custom comparator

All four candidates call:

- `doSort(customCounts, deps, module)`

That helper delegates to:

- `TopologicalSort::minSort(deps, comparator)`

`topological_sort.h` describes `minSort(...)` as the lexicographically minimal topological sort under a comparator.

Binaryen’s comparator uses three priorities, in this exact order:

1. imports before non-imports
2. higher custom count before lower custom count
3. original order as the tie-break

So the actual behavior is:

- keep only dependency-valid orders,
- among currently legal choices, pick the best according to this comparator,
- make ties stable by original declaration order.

## Stage 6: score candidates with the *real* size model

After building each candidate order, Binaryen computes its estimated size with:

- `computeSize(sort, counts)`

That second argument is always the **true** observed counts.

This is a crucial distinction:

- the custom counts are only search heuristics
- the final objective is still the true count-weighted encoding cost

## Production size model

The real pass tracks when ULEB encodings grow in size.
The important thresholds are the usual ones for 7-bit groups:

- `0..127` -> 1 byte
- `128..16383` -> 2 bytes
- later thresholds continue similarly

For each global position in the candidate order, Binaryen multiplies:

- how often that global is used
- by the current estimated LEB byte count for that index

and sums the results.

## `always` size model

In `always` mode, Binaryen uses a smooth synthetic factor:

- `1.0 + i / 128.0`

The source comment says this is not realistic, but smooth, and mainly useful for testing.

That is why the small lit tests mostly use `--reorder-globals-always`: it makes differences visible even when the real pass would intentionally do nothing.

## Stage 7: pick the cheapest candidate, preferring earlier ties

Binaryen walks the candidate list in order and keeps the first strictly best size.
That means equal-size ties prefer the earliest candidate considered.

Because the zero-count / original-ish candidate is added first, ties prefer the order closest to the original declaration list.

This is one of the easiest details to miss if you only skim the pass.
It is not just “pick any cheapest order.”
It is “pick the first cheapest order among a deliberately ordered candidate list.”

## Stage 8: apply by reordering declarations, not patching uses

Once Binaryen has the winning order, it:

- moves the old `module->globals` vector aside,
- rebuilds it in the chosen order,
- calls `module->updateMaps()`.

It does **not** rewrite `global.get` or `global.set` sites.

The reason is visible in `src/wasm.h`:

- `GlobalGet` stores `Name name;`
- `GlobalSet` stores `Name name;`

So Binaryen IR identity is symbolic.
The physical numeric index only matters when writing the final binary.

This is a very important porting fact.
A future Starshine port must preserve the same externally visible effect, whether that means:

- reordering declarations with symbolic identities, or
- explicitly remapping every global-index user if the IR stores dense indices more directly

That second bullet is an inference from Binaryen’s representation and the local Starshine backlog, not a direct Binaryen source requirement.

## Analysis and helper dependencies

This pass depends on:

- `WalkerPass<PostWalker<...>>`
  - for the parallel use-count scan
- `runOnModuleCode(...)`
  - for module-expression coverage beyond functions
- `FindAll<GlobalGet>`
  - for building initializer dependency edges
- `TopologicalSort::sort(...)`
  - to accumulate dependent counts in reverse topological order
- `TopologicalSort::minSort(...)`
  - to choose a dependency-valid order under a comparator
- `Module::updateMaps()`
  - to refresh name lookups after the declaration reorder

This pass notably does **not** depend on:

- `Effects`
- liveness
- CFG reasoning
- type refinalization
- nested `PassRunner` reruns of the default function pipeline
- local fixups or non-nullable-local repair logic

## Main interactions with nearby passes

## After `string-gathering`

This is the most explicit interaction in source comments.

`string-gathering` may create or reuse canonical string globals and may move them earlier just enough to validate.
Then `reorder-globals` performs the stronger final ordering heuristic.

A port that merges those responsibilities may still work, but it will not mirror Binaryen’s actual late-tail contract cleanly.

## After late globals cleanup and pruning

Because it runs after `simplify-globals-optimizing` and the late `remove-unused-module-elements`, the pass sees the already-pruned final global surface.
It is not spending effort ordering globals that later cleanup would delete.

## Before `directize`

The pass sits immediately before `directize`.
I did not find a stronger source-level handshake than scheduler adjacency, so the safest claim is simply:

- this is Binaryen’s final late global-layout cleanup before the optimizer moves on to the last indirect-call cleanup step

That last sentence is an inference from `pass.cpp`, not a direct comment from `Directize.cpp`.

## Internal use by `GlobalStructInference`

`GlobalStructInference.cpp` is a very useful neighboring source because it shows why the `always` variant exists in practice.
When that pass adds new helper globals, it immediately runs a nested `PassRunner` with:

- `reorder-globals-always`

That preserves validity by making new defining globals appear before their users, even in small modules where the public pass would bail out.

## What this pass is not

A useful beginner correction list:

- It is not a full “global optimization” pass.
- It is not dead-global elimination.
- It is not the same thing as `string-gathering`’s validity reorder.
- It is not a name-based sort.
- It is not purely greedy.
- It is not always active on small modules.
- It is not a use-site rewrite pass in Binaryen IR.

## Source-derived port checklist

A future Starshine port should preserve all of these:

- the late scheduler placement after `string-gathering`
- the public optimize/shrink gate
- the public under-`128` early-return rule if exact parity is desired
- counting both `global.get` and `global.set`
- counting uses in module code as well as functions
- building dependencies only from initializer `global.get` traffic
- imports-first ordering
- original-order tie-breaking
- the four candidate-search families (`zero`, `raw`, `sum`, `exponential`)
- scoring on the true counts rather than the heuristic counts
- earliest-minimum tie behavior
- the public-vs-`always` distinction
- representation-correct application of the new order

## Sources

- [`../../../raw/research/0125-2026-04-20-reorder-globals-binaryen-research.md`](../../../raw/research/0125-2026-04-20-reorder-globals-binaryen-research.md)
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
