# 0118 - `coalesce-locals` Binaryen research

## Status

- Date: 2026-04-20
- Type: One-off raw investigation
- Scope: document one currently unimplemented no-DWARF / `-O4z` Binaryen pass in Starshine, using Binaryen `version_129` plus the saved generated-artifact audit to explain how `coalesce-locals` really works, which helpers it leans on, and which IR shapes a future Starshine port must preserve.

## Why this pass

- `coalesce-locals` is still unimplemented in Starshine and remains listed under removed pass names in `src/passes/optimize.mbt`.
- The canonical no-DWARF `-O` / `-Os` path runs it **twice** in the function pipeline:
  - first after `optimize-casts` / `local-subtyping`
  - then again after `simplify-locals` / `vacuum` / `reorder-locals`
- The saved generated-artifact `-O4z` audit records both top-level skipped slots:
  - slot `30`
  - slot `35`
- The pass sits in exactly the same neighborhood as several already-documented or already-implemented neighbors:
  - `reorder-locals`
  - `heap2local`
  - `optimize-casts`
  - `local-subtyping`
  - `local-cse`
  - `simplify-locals`
- That makes it high-value documentation work: future Starshine preset honesty around the local-cleanup cluster depends on understanding what this pass actually does, not what the CLI name suggests.
- The CLI name sounds like a simple “merge dead locals” cleanup. The real Binaryen implementation is narrower and more interesting:
  - it is register-allocation-like, but with no spilling
  - it reasons about **liveness**, **copies**, **equal current values**, and **loop backedges**
  - it only coalesces locals whose types match **exactly**
  - it does post-renumber cleanup of redundant copies and dead stores

## Saved local source material

### Local Starshine / audit sources

- `src/passes/optimize.mbt`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md`
- `.artifacts/o4z-wasm-opt-debug.log`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.json`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json`
- `agent-todo.md`
- `docs/wiki/raw/research/0073-2026-04-02-reorder-locals-binaryen-comparison.md`
- `docs/wiki/raw/research/0116-2026-04-20-local-subtyping-binaryen-research.md`

### Official Binaryen `version_129` sources

- `src/passes/CoalesceLocals.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/CoalesceLocals.cpp>
- `src/passes/pass.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `src/passes/opt-utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- `src/cfg/liveness-traversal.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/cfg/liveness-traversal.h>
- `src/ir/numbering.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/numbering.h>
- `src/ir/utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/utils.h>
- `test/lit/passes/coalesce-locals.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/coalesce-locals.wast>

## Fast answer

Binaryen’s `coalesce-locals` pass is a late, function-parallel local-slot minimizer that tries to make multiple locals reuse the same storage slot when they are never simultaneously live with **different** values and already have the **same exact type**.

The implementation is best understood as four phases:

1. **collect CFG, liveness, and copy hints**
   - `LivenessWalker` builds per-block get/set action lists, tracks live-in/live-out locals, notes copy edges, unlinks dead blocks, and rewrites unreachable local traffic into safer placeholder shapes so later renumbering stays valid
2. **compute interference**
   - `CoalesceLocals::calculateInterferences()` walks each live block backward and forward, tracks live ranges and current value numbers, and marks two locals as conflicting only when their live ranges overlap with different values
3. **pick new local indices**
   - `pickIndicesFromOrder()` runs a greedy coloring-like algorithm that preserves param order, requires exact type equality, and prefers choices that eliminate the most copies
4. **rewrite and clean up**
   - `applyIndices()` renumbers gets/sets, deletes newly redundant copies, deletes dead sets, may request `ReFinalize()` when a dead tee carried a more refined result type, shrinks the local list, and drops local-name metadata

Important durable facts:

- The pass header explicitly says it is **nonlinear in the number of locals**, so Binaryen wants to run it only after earlier passes have already reduced the local set.
- It is **not** subtype-aware. Exact type equality is mandatory during coloring.
- Equal live values may share a slot even when their live ranges overlap. That is the pass’s biggest beginner trap.
- Implicit local zero-initialization is part of the correctness proof. Binaryen uses it to avoid a heavier merge-point analysis.
- Parameters are intentionally fixed in place and deliberately made to interfere with each other.
- Loop backedge copies get extra weight so the coloring prefers eliminating those.
- Binaryen tries two greedy orders by default (natural-ish and reverse-ish) and picks the better result; there is also a separate `coalesce-locals-learning` pass that uses a genetic learner, but that variant is not in the default pipeline.

## Where it appears in the scheduler

## Top-level no-DWARF path

`pass.cpp` registers the public pass names:

- `coalesce-locals`
- `coalesce-locals-learning`

and gives the main one the summary:

- `reduce # of locals by coalescing`

In the default function pipeline, `pass.cpp` schedules `coalesce-locals` twice:

1. after `heap2local` and the GC-local cleanup pair `optimize-casts -> local-subtyping`
2. after `local-cse -> simplify-locals -> vacuum -> reorder-locals`

The nearby source comments are especially important:

- `local-subtyping` must come before `coalesce-locals` because coalescing can force a combined supertype and erase subtyping opportunities
- `coalesce-locals` is intentionally late because earlier `simplify-locals` / `reorder-locals` work reduces the local set it has to color
- late `remove-unused-brs` is commented as more effective because `coalesce-locals` opened opportunities
- late `rse` is commented as running after all `coalesce-locals`

That means scheduler placement is not just bookkeeping. It is part of the pass’s meaning.

## Saved generated-artifact `-O4z` evidence

The committed saved audit confirms the same top-level story on the large generated artifact:

- slot `30`: `coalesce-locals`
- slot `35`: `coalesce-locals`

The saved `o4z-wasm-opt-debug.log` also shows many later `coalesce-locals` runs inside nested cleanup clusters, which is exactly what we would expect once optimizing passes start rerunning the default function pipeline on touched functions.

## Nested reruns

`opt-utils.h` shows that `optimizeAfterInlining(...)` does this:

1. prepend `precompute-propagate`
2. call `addDefaultFunctionOptimizationPasses()` again on the touched-function subset

So `coalesce-locals` definitely reruns inside the nested cleanup helper used by optimizing passes such as:

- `dae-optimizing`
- `inlining-optimizing`

The repo’s no-DWARF page also says `simplify-globals-optimizing` reruns the default function pipeline on changed functions without the extra prepended `precompute-propagate`. I am treating that as the current local durable summary of the wider nested-rerun story. That specific `simplify-globals-optimizing` claim is therefore a **local-repo inference**, not something I rederived directly from `CoalesceLocals.cpp` itself.

## Actual implementation structure

## 1. Pass shape and helper surface

`CoalesceLocals` is declared as

- `WalkerPass<LivenessWalker<CoalesceLocals, Visitor<CoalesceLocals>>>`

and reports:

- `isFunctionParallel() == true`
- `invalidatesDWARF() == true`

It also sets:

- `ignoreBranchesOutsideOfFunc = true`

Important consequences:

- this is a **function pass**, not a module pass
- Binaryen expects to parallelize it across functions
- the pass is willing to renumber locals aggressively enough that current DWARF support is invalidated
- branches that leave the function do not matter for liveness because locals cease to exist there

The main helper dependencies are not incidental. They reveal the actual algorithm:

- `cfg/liveness-traversal.h`
  - CFG creation, dead-block unlinking, liveness sets, copy counting, loop-top discovery, unreachable local cleanup helpers
- `ir/numbering.h`
  - the tiny `ValueNumbering` helper that says when two live locals provably hold the same value
- `ir/utils.h`
  - `LiteralUtils::canMakeZero`, `Literal::makeZeros`, `ExpressionManipulator`, and `ReFinalize`
- `support/sparse_square_matrix.h`
  - compact storage for pairwise interference and copy counts
- `support/learning.h` / `support/permutations.h`
  - only for the optional learning variant, not the default pass

## 2. `LivenessWalker` does more than ordinary liveness bookkeeping

The inherited `LivenessWalker` performs several jobs before `CoalesceLocals` even starts its own logic:

### It records local actions by block

Each reachable basic block stores a vector of actions:

- `Get`
- `Set`
- `Other`

Those actions point back to the original `Expression**` sites, which later lets `applyIndices()` mutate the actual IR in place.

### It records copy opportunities early

When `doVisitLocalSet(...)` sees a copy-like set, it increments copy counters.

The helper `getCopy(...)` is broader than a plain `local.set x (local.get y)` case:

- direct `local.get`
- an `if` value where one arm is a `local.get`

So Binaryen already treats some `if (result ...)`-shaped sets as copy candidates before the actual coalescing phase begins.

### It tracks total copy counts per local pair

`addCopy(i, j)` updates both the pairwise matrix and each local’s `totalCopies`. That later becomes the main priority signal for ordering locals before greedy coloring.

### It cleans unreachable local traffic proactively

This is easy to miss but very important.

If the CFG walker is in unreachable code, local gets and sets are rewritten immediately:

- unreachable `local.get` is replaced with a same-typed placeholder or, if needed, a forced-type `(block (result X) (unreachable))`
- unreachable `local.set` becomes a `drop(value)` or a plain value/block preserving the tee result type

Why this matters:

- the pass will later renumber locals everywhere it still sees
- unreachable local traffic would otherwise become a source of stale indices or type-invalid leftovers
- the tests `in-unreachable` and `nop-in-unreachable` exist precisely because this helper behavior is part of the real contract

## 3. `increaseBackEdgePriorities()` biases the pass toward loop-phi cleanup

Before computing interferences, `CoalesceLocals::doWalkFunction()` calls `increaseBackEdgePriorities()`.

That helper:

- iterates loop tops
- ignores the first incoming edge because that is the initial loop entry, not a backedge
- looks only at predecessor blocks with a single outgoing edge, i.e. unconditional backedges to the loop top
- scans the arriving block’s actions for copy sets
- if it finds a copy on that backedge, it adds extra copy weight

The source comment explains the reason directly:

- a copy on a backedge can be especially costly because it may force a branch just to perform the copy

This is not a correctness rule. It is a profitability tie-breaker. But it is an important one, and the `loop-backedge` test locks it in.

## 4. `calculateInterferences()` is the heart of the pass

The pass stores interferences in a sparse upper-triangular matrix. But the interesting part is how those conflicts are discovered.

### Step 4A: find where live ranges end and which sets are effective

For each live block, the pass first scans actions from the end backward.

It computes:

- `endsLiveRange[i]`
  - whether a particular get ends the local’s live range because the local is not live after that point
- `action.effective`
  - whether a set is actually read later by some get

A set that is never read is marked ineffective and later becomes removable dead code.

### Step 4B: seed current value numbers

The pass keeps an array `values[localIndex] = valueNumber`.

At function entry:

- each parameter gets a unique value number
- each body local gets the value number of its implicit zero initialization if that type has a materializable zero
- otherwise the local gets a unique synthetic value number

In non-entry blocks:

- each live-in local gets a fresh unique value number
- Binaryen explicitly declines to propagate value numbers across blocks because that would become nonlinear

This gives the pass a deliberately local, block-by-block precision level.

### Step 4C: walk forward through each block and mark conflicts only on different values

Now the pass walks the block’s actions from front to back.

On a `Get`:

- if that get was marked as the end of a live range, the local is removed from the `live` set

On a `Set`:

- it computes the newly stored value number
- if the set is a direct copy or a tee immediately preceded by the copied site, it reuses the source local’s current value number
- otherwise it asks `ValueNumbering` for a value number

Then comes the key rule:

- if the set is ineffective, it does **not** start a meaningful live range and cannot cause interference
- if it is effective, it interferes only with currently-live locals whose current value number is **different**

That “different value” condition is the source of many surprising positives in the tests.

Two locals can overlap in liveness and still be merged if Binaryen can prove they hold the same value.

### Step 4D: why block merges do not need a separate phi-style conflict pass

The large explanatory comment in `calculateInterferences()` is one of the most valuable pieces of source text.

Binaryen’s argument is:

- WebAssembly locals always have a default value
- therefore if a local is live at the beginning of a block, it must be live at the end of **all** predecessor blocks reaching it
- the conflict that would appear “at the merge” must already appear somewhere inside those predecessor blocks’ own ranges

So unlike a more general SSA or register-allocation setting, Binaryen does **not** need a separate merge-point-only interference algorithm here.

The important exception is function entry, because the zero initialization is implicit rather than represented by actual `local.set` nodes.

### Step 4E: params and zero-init locals need manual entry fixes

After the main block walk, the pass explicitly:

- marks every pair of params as interfering
- marks each live-at-entry body local as interfering with each param

Why the second rule exists:

- an implicit zero-init is logically a set
- but because it is not explicit IR, no normal set action would have recorded the conflict with params

This little manual patch is how the pass keeps entry-state reasoning sound.

## 5. `ValueNumbering` is tiny but semantically important

`ir/numbering.h` does not implement a global value numbering pass.

It only guarantees:

- identical literal bundles get the same number
- the same expression pointer gets the same number
- otherwise a fresh unique number is used

That means `coalesce-locals` is not doing heroic algebraic equivalence.

It is using a modest but useful rule:

- if two locals definitely contain the same literal or exact copied value in this block, do not mark them as conflicting merely because both are live

That is why the test families `zero-init`, `equal-constants`, and `equal-constants-nonzero` are important. They lock in that “equal value means no conflict” rule.

## 6. `pickIndicesFromOrder()` is a greedy coloring-like allocator

Once the interference matrix is known, Binaryen chooses new local indices.

The core routine `pickIndicesFromOrder(order, indices, removedCopies)` works like this:

1. keep params fixed in order
2. visit the remaining locals in some chosen order
3. for each local, search existing indices for one that:
   - does not interfere with the already-merged contents of that index
   - has the **same exact local type**
4. if multiple existing indices are legal, pick the one that would eliminate the most copies
5. if none is legal, allocate a new index
6. merge the new local’s interference and copy information into the chosen index’s aggregate state

Important durable facts:

- exact type equality is mandatory here
- this is **not** subtype-compatible coloring
- copy elimination is a first-class profitability goal, not just a tie-break after minimizing the count of locals

The type check is why `local-subtyping` must run first. If several locals could have shared after narrowing to the same type, that narrowing must happen before `coalesce-locals` sees them.

## 7. Default ordering is heuristic, not optimal

`pickIndices()` uses heuristics rather than an exact graph-coloring solver.

It tries two orders:

### Order 1: natural order, adjusted by copy priorities

- start with the identity order
- then stable-sort by `totalCopies`, with params given maximum priority so they stay fixed

### Order 2: reverse-ish order, adjusted by the same priorities

- reverse only the non-param locals
- stable-sort again by `totalCopies`

Binaryen then compares the two solutions and prefers:

1. the one that removes more copies
2. if tied, the one with the smaller maximum index

This is a very practical policy:

- copy removal matters for code size and throughput
- local-count reduction still matters, but secondarily when copy counts differ

The test pair `greedy-can-be-happy` and `greedy-can-be-sad` exists because greedy coloring really can depend on order.

## 8. The learning variant is real, but not the one in the default pipeline

`CoalesceLocalsWithLearning` overrides only the index-picking strategy.

Instead of using the simple two-order heuristic, it runs a small genetic learner over candidate orders and scores them by:

- primarily reducing the number of locals
- secondarily keeping locals in their original places
- then also rewarding removed copies

This is useful context for future research, but the important practical point is:

- the canonical Binaryen optimize pipeline uses `coalesce-locals`, not `coalesce-locals-learning`

So a future Starshine parity port should match the normal greedy variant first.

## 9. `applyIndices()` is both rewrite and cleanup

After coloring, `applyIndices()` does more than renumber declarations.

### Renumber gets and sets

Every recorded reachable local get/set action has its index replaced with the chosen new index.

### Delete newly redundant copies

If a `local.set` or `local.tee` now copies from the same index back into itself, `action.removeCopy()` rewrites it away:

- tee copy -> plain get
- set copy -> `nop`

### Simplify nested same-index tee patterns

If a set’s value is itself a `LocalSet`/tee to the same index and the inner value type matches the tee type exactly, Binaryen strips the inner tee wrapper.

The source comment explicitly refuses to do this when the inner type is more refined.

### Remove ineffective sets

If a set was marked ineffective during liveness analysis:

- plain `local.set` becomes `drop(value)`
- dead `local.tee` becomes just the value expression

This is where the source comment raises a subtle non-nullable-local concern:

- sometimes a dead set is still useful for validation or for keeping a local non-nullable
- Binaryen chooses the simple policy anyway and removes all dead sets

That is an important “sounds obvious, but is actually a tradeoff” detail.

### Re-finalize if a dead tee had a more refined outward type

If a dead tee is replaced by its child value and the original tee result type was more refined than the child expression type, the pass sets `refinalize = true` and later runs `ReFinalize()` on the function.

This is the main GC/type-repair obligation of the pass.

### Shrink the declared local list and discard local-name metadata

Finally the pass:

- computes the new number of locals from the chosen indices
- rewrites `Function::vars`
- clears `localNames` and `localIndices`

That means local-name metadata is intentionally lost. A future Starshine port must not silently assume local names survive.

## Important test-backed shape families

The official `coalesce-locals` lit test is large, but the most useful shape families are these:

### Basic positive / negative families

- `merge`
  - two unused same-typed locals collapse to one slot
- `leave-type`
  - different types do not coalesce
- `leave-interfere`
  - overlapping live ranges with different values do not coalesce
- `almost-interfere`
  - non-overlapping live ranges can coalesce even if both locals are used

### Copy-elimination families

- `redundant-copy`
  - coalescing can turn a copy into a no-op and erase it
- `prefer-remove-copies1` / `prefer-remove-copies2`
  - order selection explicitly cares about copy removal
- `loop-backedge`
  - extra backedge weight can decide a tie in favor of removing the loop-phi-style copy

### Equal-value non-interference families

- `zero-init`
  - separate locals with the same implicit zero value can coalesce
- `equal-constants`
  - overlapping live locals can share when one is written the same value the other already has
- `equal-constants-nonzero`
  - the same rule applies to nonzero literals too
- `different-constants` / `different-constants-nonzero`
  - different values force interference

### Structured control-flow families

- `if-else`, `if-else-parallel`, `if-else-after`, `if-through*`, `if2`-`if5`
  - the pass understands lifetimes through structured conditionals, and small order changes can turn a positive into a bailout (`if5` vs `if5-flip`)
- `loop`
  - loop bodies keep separate locals when the live ranges and values require it
- `switch`
  - `br_table`/switch-shaped structured CFG still participates in the same liveness reasoning
- `this-is-effective-i-tell-you`
  - a set inside nested control can still be effective and therefore must remain part of interference reasoning

### Dead / unreachable-code families

- `see-br-and-ignore-dead`, `interfere-in-dead*`, `in-unreachable`, `nop-in-unreachable`
  - dead regions should not create bogus interference, and unreachable local traffic must be rewritten into safer placeholder forms

### Param and tee/value-shape families

- `params`
  - params stay fixed; only body locals coalesce among themselves
- `if-copy1`-`if-copy4`, `if-copy-tee`
  - copy detection includes small valued-`if` / tee patterns
- `tee_br`, `unused-tee-with-child-if-no-else`, `tee_if_with_unreachable_else`, `tee_if_with_unreachable_true`
  - dead tee cleanup still has to preserve validation and result types

## What the pass does **not** do

A future Starshine port should avoid accidentally broadening the pass beyond upstream behavior.

`coalesce-locals` does **not**:

- merge locals of different types, even if one is a subtype of the other
- solve general optimal graph coloring
- perform full cross-block value numbering
- use ordinary effect/trap motion analysis to move computation around
- replace `local-subtyping`, `local-cse`, `merge-locals`, `reorder-locals`, or `simplify-locals`
- preserve local-name metadata
- handle DWARF updates yet

The real Binaryen contract is narrower and more scheduler-dependent than the name suggests.

## Why the surrounding passes matter

The order in `pass.cpp` is a concise statement of intended role.

### Before `coalesce-locals`

- `simplify-locals-nostructure`, `vacuum`, and `reorder-locals` reduce obvious local clutter first
- `heap2local` may create more local traffic
- `optimize-casts` and `local-subtyping` can expose or preserve narrower precise types before coalescing freezes exact local types
- optional `merge-locals` runs earlier at higher optimize levels to do extra copy work before coloring

### After the first `coalesce-locals`

- `local-cse` can exploit the cleaner, more unified local traffic
- full `simplify-locals` and `vacuum` then remove additional garbage

### Around the second `coalesce-locals`

- `reorder-locals` compacts and renumbers after the first round of cleanup
- the second `coalesce-locals` gets another chance on the smaller post-cleanup local set
- another `reorder-locals` and `vacuum` clean up the result again

### Later passes that profit

- `remove-unused-brs` explicitly has a source comment noting that `coalesce-locals` opens opportunities
- late `rse` is deliberately scheduled after all `coalesce-locals`

## Easy-to-misunderstand truths

If you only remember a few things from this note, remember these:

1. Binaryen coalesces **storage slots**, not abstract values
2. exact type equality is mandatory
3. equal current values can prevent interference even when lifetimes overlap
4. implicit zero initialization is part of the analysis model
5. params are fixed and specially protected
6. backedge copies get extra priority
7. the pass is greedy and order-sensitive by design
8. dead-set cleanup and possible refinalization are part of the real rewrite contract
9. the pass is intentionally late because it is nonlinear in local count

## Porting lessons for Starshine

A future Starshine port should preserve these properties first:

1. function-parallel late placement, not an early always-on cleanup
2. exact-type-only coalescing
3. liveness + current-value interference, not mere lifetime overlap
4. implicit zero-init modeling and the manual param-entry fix
5. unreachable local rewrite handling before renumbering
6. backedge-copy prioritization
7. greedy order comparison between at least the natural and reverse shapes
8. copy-elimination during rewrite, not only declaration compaction
9. dead tee / refined-type refinalization behavior
10. local-name metadata invalidation/repair policy

## Open questions / uncertainty

- I did not find a dedicated upstream prose doc that explains why the genetic `coalesce-locals-learning` variant is kept public but out of the default pipeline. My working assumption is simply that the normal heuristic is the canonical default and the learning variant is experimental.
- The local repo documentation says `simplify-globals-optimizing` reruns the default function pipeline on changed functions without prepended `precompute-propagate`. I am reusing that local scheduler summary, not claiming a new direct upstream proof here.
- The current `version_129` test file is broad on scalar/control-flow coverage but does not appear to add separate GC-type test cases. The dead-tee refined-type logic in the source is therefore more informative than the test surface for that particular corner.

## Sources

- Local repo scheduler and backlog sources:
  - `src/passes/optimize.mbt`
  - `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
  - `docs/wiki/binaryen/passes/tracker.md`
  - `agent-todo.md`
  - `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json`
  - `.artifacts/o4z-wasm-opt-debug.log`
- Official Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/CoalesceLocals.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/cfg/liveness-traversal.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/numbering.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/coalesce-locals.wast>
