# Binaryen `reorder-globals-always` research

Date: 2026-04-21

## Scope and why this pass is eligible now

This thread had to pick exactly one Binaryen pass that still needed more wiki information.

The original no-DWARF queue is already dossier-covered.
The saved generated-artifact `-O4z` queue is already dossier-covered.
The first expanded upstream-only registry wave is dossier-covered too, including the main [`reorder-globals`](../../binaryen/passes/reorder-globals/index.md) folder.

So this note is an explicit **tracker expansion** for another real local-registry pass name that still lacked its own dedicated living folder.

I picked `reorder-globals-always` because:

- it is still named in the local boundary-only registry at `src/passes/optimize.mbt`
- official Binaryen `version_129` registers it as a separate pass name in `src/passes/pass.cpp`
- it is not just a hidden boolean flag in the local repo docs; upstream gives it its own constructor and CLI surface
- the existing `reorder-globals` dossier mentions it repeatedly, but that sibling still had **no dedicated landing folder** of its own
- it is a good campaign fit because this campaign has recently been closing exactly this kind of public/test-oriented sibling gap (`simplify-locals-nonesting`, `monomorphize-always`)

I did **not** pick `reorder-globals` itself; that pass already has a dedicated dossier.
I picked the sibling because the local registry still exposes it separately and the upstream source/test surface makes the split real.

## Backlog status in this repo

`agent-todo.md` currently has **no dedicated `reorder-globals-always` slice**.
The nearest related backlog slice is `RG - Reorder Globals`, which tracks the production late-tail pass rather than this small-module/test/internal sibling.

That absence is worth recording explicitly so future port work does not assume there is already a dedicated local implementation plan for the variant.

## Main source set reviewed

Primary official Binaryen `version_129` sources reviewed for this note:

- `src/passes/ReorderGlobals.cpp`
- `src/passes/pass.cpp`
- `src/passes/passes.h`
- `src/pass.h`
- `src/wasm-traversal.h`
- `src/support/topological_sort.h`
- `src/wasm.h`
- `src/passes/GlobalStructInference.cpp`
- `test/lit/passes/reorder-globals.wast`
- `test/lit/passes/reorder-globals-real.wast`

Local repo context reviewed first, per repo rules:

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`
- `docs/wiki/raw/research/0125-2026-04-20-reorder-globals-binaryen-research.md`
- `docs/wiki/binaryen/passes/reorder-globals/*`
- `src/passes/optimize.mbt`

## Short answer

`reorder-globals-always` is **not** a different algorithm from `reorder-globals`.

It is the same `ReorderGlobals` engine instantiated with `always = true`, which changes two important policy surfaces:

1. it disables the ordinary public early return for modules with fewer than `128` globals
2. it scores candidate orders with a smooth synthetic cost function `1.0 + i / 128.0` instead of the real stepped ULEB-size model

That makes the sibling useful for:

- small hand-written tests where the public pass would intentionally do nothing
- internal fixup callers such as `GlobalStructInference`, which sometimes introduce fresh globals that must move earlier than their new users even in tiny modules

The pass still keeps the same deeper contract:

- same use-count scan
- same dependency graph from initializer `global.get`
- same four candidate sort families
- same imports-first ordering
- same original-order tie behavior
- same declaration-list rewrite plus `updateMaps()`

So the real split is **policy and purpose**, not implementation shape.

## Public identity versus implementation identity

## Separate pass name in upstream

`pass.cpp` registers both:

- `reorder-globals`
- `reorder-globals-always`

The descriptions distinguish them as:

- ordinary frequency-based sorting
- the same sorting even when there are few globals

`passes.h` also declares two constructors:

- `createReorderGlobalsPass()`
- `createReorderGlobalsAlwaysPass()`

That is enough to treat the sibling as real pass surface, not just an undocumented debug knob.

## Shared engine underneath

`ReorderGlobals.cpp` implements the logic once and exposes the two constructors by creating `ReorderGlobals` with:

- `always = false`
- `always = true`

So a faithful Starshine port should likely model this as:

- one shared implementation core
- two separate registry/CLI identities

That is the same style of split Binaryen uses for other sibling passes in this campaign.

## What the production pass does that the sibling overrides

The production pass has an important public fast-path:

- if there are fewer than `128` globals and `always` is false, it returns immediately

The source comment explains the reasoning:

- below `128`, global indices still fit in one-byte ULEB form, so there is no real encoded-size win under the true production size model

But the same source area also leaves a TODO noting that sorting is still needed sometimes to fix dependencies.

That tension is the key reason this sibling exists.

`reorder-globals-always` says:

- run the reorder logic anyway
- even for tiny modules
- using a smoother stand-in cost model so the effect is visible and deterministic

## The exact implementation structure that still matters

Everything below is shared with the main pass unless noted otherwise.

## Phase 1: count global traffic

The pass uses a tiny function-parallel `UseCountScanner` that only visits:

- `GlobalGet`
- `GlobalSet`

This is beginner-important because:

- writes count, not just reads
- the pass is not profiling-driven; it is static structure counting

The scanner also runs on **module code**, not only ordinary functions.
From `pass.h` and `wasm-traversal.h`, that means the scan sees expression-bearing module slots such as:

- defined global initializers
- element/data offsets
- element items and table init expressions

So the sibling is still a whole-module declaration-layout pass, not just a sort over function-body traffic.

## Phase 2: build name-to-index counts

The pass starts with atomic counts by `Name` so the parallel walk is safe.
Then it converts those counts into vectors indexed by original global position.
The vectors use `double` because later candidate heuristics use fractional weighting.

## Phase 3: build the initializer dependency DAG

For each non-imported global initializer, the pass finds embedded `GlobalGet`s.
If one global initializer reads another global, the dependency must be preserved in declaration order.

Important scope boundary:

- this is based on initializer `global.get` traffic
- not arbitrary function dataflow
- not export order
- not symbol names

So the dependency graph is about **module validity**, not whole-program dependence.

## Phase 4: generate candidate orders

The engine tries four dependency-safe candidate families:

1. zero-count / original-ish order
2. true-count greedy order
3. full dependent-sum order
4. discounted exponential dependent-sum order

This is the most important algorithmic teaching point.
The pass is not just “sort by use count.”
It is a small dependency-constrained search over several heuristic orderings.

## Phase 5: score and pick the winner

The winner is chosen by estimated size.
The implementation keeps the earliest strictly best candidate, so equal-size ties preserve the earlier candidate in the list.
That means ties lean toward lower churn.

## Phase 6: apply by reordering declarations

Once the best order is chosen, Binaryen rebuilds `module->globals` in that order and calls `module->updateMaps()`.
It does not patch every use site manually because `GlobalGet` and `GlobalSet` refer to globals by `Name` in Binaryen IR.

That representation fact matters for a future port.
If Starshine stores symbolic global identities, the reorder can be similarly cheap.
If Starshine stores dense indices more directly, it will need an explicit user remap.
That last sentence is an inference from local repo structure, not a direct Binaryen requirement.

## The exact sibling-only differences

## Difference 1: no public `< 128` cutoff

This is the most visible behavioral split.

- `reorder-globals` may intentionally no-op on tiny modules
- `reorder-globals-always` keeps going

That is why the sibling is the one most often used in tiny lit tests.

## Difference 2: smooth synthetic cost model

The public pass uses the true stepped ULEB-size model.
In other words, real cost only changes when an index crosses a byte-width boundary.

The `always` sibling instead uses:

- `1.0 + i / 128.0`

That model is intentionally unrealistic but smooth.
It creates visible differences in small modules where the real pass would otherwise see no code-size distinction.

This is not just a testing convenience.
It also makes the nested-fixup use in `GlobalStructInference` deterministic on small modules.

## Difference 3: real role as an internal repair tool

The strongest source-backed interaction is in `GlobalStructInference.cpp`.
When that pass creates fresh helper globals during un-nesting, it creates a nested `PassRunner`, adds `reorder-globals-always`, marks it nested, and runs it.

That proves a real practical role:

- after fresh-global insertion, Binaryen sometimes needs a reorder even on small modules
- the ordinary public pass does not promise to do that
- the sibling is the internal tool that does

That is the easiest point to lose if `reorder-globals-always` is taught only as “a test-only variant.”
It is test-oriented, but it also performs real internal validity repair work.

## What the official tests prove

## `reorder-globals.wast`

This file mostly uses `--reorder-globals-always`.
That means it is the best official teaching surface for the sibling.

From the reviewed file and the existing raw note, it proves all of these behaviors:

- hotter independent globals move earlier
- `global.set` counts just like `global.get`
- initializer dependencies override raw popularity
- imports still stay before defined globals
- equal-size situations prefer original order
- non-greedy candidate search matters
- the full-sum candidate can beat the raw-greedy candidate

Because the file uses the `always` variant heavily, these examples remain visible even on small hand-written modules.

## `reorder-globals-real.wast`

This file proves the other half of the sibling split:

- the production pass does real work once there are enough globals
- with one fewer global, it intentionally leaves the order unchanged

So the lit split is pedagogically clean:

- `reorder-globals.wast` = algorithm visibility on small modules via the sibling
- `reorder-globals-real.wast` = production cutoff and real-size behavior for the ordinary pass

## Important IR / WAT / module shapes to preserve

## Positive shapes

- tiny modules with independent globals where the public pass would no-op but the sibling reorders
- dependency chains where a prerequisite must stay before a hotter dependent
- mixed cases where an independent hot global can move ahead of a cooler chain, but the chain itself must remain valid
- fresh-global insertion after `GlobalStructInference` un-nesting

## Negative / bailout shapes

- public-mode tiny modules are a negative for `reorder-globals`, but **not** for the sibling
- imports still cannot move after defined globals
- dependency-breaking orders are always illegal
- symbol-name order is irrelevant
- the pass never becomes a generic global-value optimizer or dead-global remover

## Easy beginner misunderstandings

1. **"always" means a different algorithm.**
   - Wrong. The search, dependencies, and application logic are the same.
2. **"always" means it ignores safety or validity.**
   - Wrong. It still preserves imports-first ordering and initializer dependencies.
3. **It is only a test gimmick.**
   - Incomplete. The official tests use it heavily, but `GlobalStructInference` also uses it as a real nested fixup tool.
4. **It is the main production late-tail pass.**
   - Wrong. The ordinary no-DWARF late-tail pass is still `reorder-globals`.

## What a future Starshine port must preserve

- separate registry/CLI identity for `reorder-globals-always`
- one shared implementation core with ordinary `reorder-globals`
- the removed `< 128` early return in always mode
- the smooth synthetic scoring model in always mode
- the same dependency graph from initializer `global.get`
- the same imports-first comparator rule
- the same candidate families and earliest-best tie behavior
- the same cheap declaration reorder if the IR permits it
- the real nested-use story from `GlobalStructInference`

## Relationship to the existing `reorder-globals` dossier

The main `reorder-globals` folder already documented the sibling as a subtopic.
This note does **not** overturn that dossier.
Instead it separates out the sibling because the local registry names it separately and the upstream source/test surface supports teaching it as a distinct pass identity.

That means the best durable split now is:

- `reorder-globals` folder = production pass and shared engine overview
- `reorder-globals-always` folder = sibling identity, exact policy changes, test surface, and internal-fixup role

## Uncertainty and limits

- I did not find a shipped lit case that isolates an "exponential candidate is uniquely the winner" example for the sibling alone. The source clearly includes the candidate, so I treat it as implementation contract, but the test evidence for that exact win mode remains indirect.
- I found one explicit internal caller of `reorder-globals-always` in `GlobalStructInference.cpp`. I am describing that as “the explicit caller I confirmed,” not “the only possible caller anywhere upstream forever.”

## Sources

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`
- `src/passes/optimize.mbt`
- `docs/wiki/raw/research/0125-2026-04-20-reorder-globals-binaryen-research.md`
- Binaryen `version_129`:
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
