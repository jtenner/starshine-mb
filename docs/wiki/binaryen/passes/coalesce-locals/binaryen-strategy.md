---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-coalesce-locals-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-22-coalesce-locals-primary-sources.md
  - ../../../raw/research/0352-2026-04-25-coalesce-locals-current-main-and-test-map.md
  - ../../../raw/research/0264-2026-04-22-coalesce-locals-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0118-2026-04-20-coalesce-locals-binaryen-research.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./interference-and-ordering.md
  - ./wat-shapes.md
  - ../local-subtyping/index.md
  - ../reorder-locals/parity.md
---

# Binaryen `coalesce-locals` Strategy

## Upstream source rule

- Use Binaryen `version_129` as the current source oracle for this pass.
- The core implementation is `src/passes/CoalesceLocals.cpp`.
- Treat [`../../../raw/binaryen/2026-04-22-coalesce-locals-primary-sources.md`](../../../raw/binaryen/2026-04-22-coalesce-locals-primary-sources.md) as the immutable provenance anchor for the official release, source, helper, and test URLs reviewed on 2026-04-22.
- Treat [`../../../raw/binaryen/2026-04-25-coalesce-locals-current-main-recheck.md`](../../../raw/binaryen/2026-04-25-coalesce-locals-current-main-recheck.md) as the focused current-`main` freshness bridge. It found no teaching-relevant drift on the checked owner, scheduler, helper, and dedicated-test surfaces.
- Scheduler placement comes from `src/passes/pass.cpp` and the after-inlining helper in `src/passes/opt-utils.h`.
- The key helper contracts come from:
  - `src/cfg/liveness-traversal.h`
  - `src/ir/numbering.h`
  - `src/ir/utils.h`
- The shipped behavior examples come from `test/lit/passes/coalesce-locals.wast`.
- For the owner-file and test-region map, see [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md).

Primary source URLs:

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/CoalesceLocals.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/cfg/liveness-traversal.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/numbering.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/coalesce-locals.wast>
- Narrow freshness-check surface:
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/CoalesceLocals.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/opt-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/coalesce-locals.wast>

## High-level intent

Binaryen uses `coalesce-locals` to reduce the number of local storage slots in a function.

That sentence is true but incomplete.

The actual implementation is closer to a small, late, no-spilling register allocator that is tuned for WebAssembly locals.

The core question is not:

- “are these locals both unused a lot?”

It is:

- “can these locals share the same index without ever being simultaneously live with different values, and would doing so delete useful copies?”

That extra “different values” clause is the real pass.

## The pass in one table

| Phase | What Binaryen does | Why it exists |
| --- | --- | --- |
| Build CFG/liveness state | `LivenessWalker` records get/set actions, liveness, copy counts, loop tops, and rewrites unreachable local traffic into safe placeholders | Later renumbering needs real CFG facts and must not be confused by dead code |
| Weight backedge copies | `increaseBackEdgePriorities()` adds extra copy cost for unconditional loop-backedge copies | Loop-phi-style copies are especially profitable to remove |
| Compute interference | `calculateInterferences()` combines liveness with tiny current-value numbering | Two locals conflict only when they overlap with different values |
| Pick new indices | `pickIndicesFromOrder()` greedily colors exact-typed locals and prefers choices that remove more copies | Cut local count and also cut copy code |
| Rewrite and clean up | `applyIndices()` renumbers locals, deletes now-redundant copies, removes dead sets, may refinalize, and shrinks the var list | The visible benefit is not just fewer declarations but also less local traffic |

## Phase 1: this is a late, function-parallel pass on purpose

`CoalesceLocals` reports `isFunctionParallel() == true`, so Binaryen treats it as a per-function pass that can run across functions in parallel.

The file header also carries a very important warning:

- the pass is nonlinear in the number of locals
- it is best to run after other passes have reduced the local set

That is why `pass.cpp` places it after a large amount of earlier local cleanup instead of near the top of the function pipeline.

## Phase 2: `LivenessWalker` does the heavy setup work

`CoalesceLocals` inherits from `LivenessWalker`, which is more than a boring helper.

## It records exact mutation sites

Each basic block stores `LivenessAction`s containing:

- whether the site is a get, set, or other marker
- which local index it touches
- the original `Expression**` site

That is what later lets `applyIndices()` mutate the actual IR in place.

## It tracks live blocks and unlinks dead ones

The helper computes live blocks and then unlinks dead ones from the CFG before liveness flow.

That matters because dead blocks should not create bogus interference.

## It notes copy opportunities early

When the helper sees a `local.set`, it calls `getCopy(...)`.

That helper accepts:

- direct `local.get` copies
- some `if (result ...)` copies where one arm is a `local.get`

So copy-removal profitability is already being tracked before the actual coloring stage.

## It rewrites unreachable local traffic before coalescing starts

This is one of the easiest details to overlook.

In unreachable code:

- `local.get` is replaced with an equal-typed placeholder or a forced-type unreachable block
- dead `local.set` / `local.tee` is replaced with a `drop` or a plain value-preserving shape

That means unreachable local nodes do not survive to confuse later index rewriting.

A future Starshine port should preserve that defensive cleanup boundary somehow, even if the exact IR machinery differs.

## Phase 3: backedge copies are deliberately more important

`increaseBackEdgePriorities()` inspects loop tops and their incoming edges.

The algorithm:

1. skip the first incoming edge because that is the initial loop entry
2. inspect later incoming edges, which are the real backedges
3. consider only predecessors with one outgoing edge, i.e. unconditional branches back to the loop top
4. if that block contains a copy set, add extra copy weight

The source comment explains the intent directly:

- copies on backedges can be especially costly because they may force a branch just to perform the copy

This is not a correctness check. It is a profitability bias. But it is important enough that the official test suite gives it a dedicated `loop-backedge` case.

## Phase 4: interference is value-aware, not just lifetime-aware

`calculateInterferences()` is the core of the pass.

## Step 4A: backward scan finds live-range ends and effective sets

For each live block, Binaryen scans actions from the end backward.

It computes two things:

- whether a particular get ends that local’s live range
- whether a particular set is effective, meaning some later get may actually read the value

Ineffective sets are remembered because they matter later during cleanup, but they do not start meaningful live ranges for interference.

## Step 4B: each local gets a current value number

The pass uses `ValueNumbering` to track which value each local currently holds.

At function entry:

- params each get a unique value number
- body locals get the value number of their implicit zero initialization when that type has a zero
- otherwise they get unique synthetic value numbers

In non-entry blocks:

- live-in locals get fresh unique value numbers
- Binaryen explicitly avoids richer cross-block value propagation because that would be nonlinear

This is a deliberately local precision level.

## Step 4C: forward scan marks conflicts only for different live values

Walking forward through the block:

- a get may end a live range
- a set computes the new stored value number
- if the set is a copy, it reuses the copied value number
- if the set is ineffective, it is ignored for interference
- otherwise it interferes with every currently-live local whose current value number is different

This “different current values” rule is the main reason the pass is easy to misdescribe.

Binaryen is not simply asking whether two locals are simultaneously live.
It is asking whether they are simultaneously live **with different contents**.

That is why test families like `zero-init`, `equal-constants`, and `equal-constants-nonzero` are true positives.

## Step 4D: wasm default values simplify merge reasoning

The long source comment about block merges is worth preserving in plain English.

Binaryen’s reasoning is:

- WebAssembly locals are never truly uninitialized
- so if a local is live at a block start, it must also have been live at every predecessor end reaching that block
- therefore a merge-only conflict will already appear somewhere in a predecessor block’s own range

So unlike a more general dataflow setting, Binaryen does not need a separate “phi-merge conflict” stage here.

That simplification is specific to wasm locals having default values.

## Step 4E: entry-state manual fixes for params and zero-init locals

After scanning all blocks, Binaryen applies two manual fixes:

- all params are forced to interfere with each other
- each live-at-entry body local is forced to interfere with each param

The second rule exists because the body local’s zero initialization is implicit, not an actual `local.set` node that the normal logic could have observed.

## Phase 5: index picking is greedy coloring with exact-type gates

The next stage is `pickIndicesFromOrder(...)`.

## Params are frozen

Parameters stay fixed in order and are never coalesced.

This is not a side effect of the algorithm. The code asserts that the chosen order leaves params in place.

## Exact type equality is mandatory

When Binaryen considers merging a local into an existing index, it requires:

- no interference with that merged index’s aggregate state
- exact type equality

So `coalesce-locals` does not try to widen or narrow types to make a merge possible.
That is exactly why `local-subtyping` must run first.

## Copy elimination is part of the choice function

If multiple existing indices are legal, Binaryen picks the one that would eliminate the most copies.

That means the optimization goal is really two-dimensional:

1. reduce the number of local slots
2. remove local-copy traffic

The second goal is strong enough that `pickIndices()` compares candidate solutions first by removed copies and only then by maximum resulting index.

## Phase 6: the default pass tries two local orders, not one

`pickIndices()` does not trust a single greedy order.

It tries:

- a natural / identity-based order, adjusted by copy priorities
- a reverse / opposite order, also adjusted by copy priorities

Then it keeps the better result.

This is still heuristic, not optimal graph coloring. But it is a deliberate attempt to avoid obvious order pathologies.

The official tests `greedy-can-be-happy` and `greedy-can-be-sad` exist because the order really does matter.

## The separate learning variant

`CoalesceLocalsWithLearning` replaces the ordering strategy with a small genetic learner.

That variant is useful to know about because it explains the public `coalesce-locals-learning` pass name, but it is **not** the canonical behavior of the default optimize pipeline.

A future Starshine port should match ordinary `coalesce-locals` first.

## Phase 7: rewriting is also where real cleanup happens

After indices are chosen, `applyIndices()` performs the rewrite.

## Renumber gets and sets

All reachable local gets and sets are rewritten to the chosen indices.

## Delete now-redundant copies

If a rewritten set now copies a local into itself:

- `local.set x (local.get x)` becomes a `nop`
- `local.tee x (local.get x)` becomes just `local.get x`

That is why the pass can reduce visible code size even when the local declaration count is not the only win.

## Delete ineffective sets

Sets marked ineffective during the liveness phase are removed:

- plain sets become `drop(value)`
- tees become the raw value expression

The source comment explicitly notes a subtle non-nullable-local tradeoff:

- some dead sets are still useful for validation or for avoiding later `ref.as_non_null`
- Binaryen chooses the simple policy and removes them anyway

That is a real upstream choice, not an omission in the documentation.

## Re-finalize when dead tee cleanup changes outward type precision

If a dead tee is replaced by its child value and the tee had a more refined outward type than the child expression type, the function is marked for `ReFinalize()`.

So the pass is not purely about local indices.
It also has a genuine post-rewrite typing obligation.

## Shrink locals and discard names

Finally the function’s var list is compacted to the maximum used new index, and local-name metadata is cleared.

A future port must decide whether to match that metadata policy exactly or to add a deliberate local-name repair layer.

## Phase 8: scheduler placement is part of the meaning

In `pass.cpp`, Binaryen schedules `coalesce-locals` in a very informative neighborhood:

- after `simplify-locals-nostructure`, `vacuum`, and `reorder-locals`
- after GC-local work like `heap2local`, `optimize-casts`, and `local-subtyping`
- before `local-cse`
- before full `simplify-locals`
- then later again after another `reorder-locals`
- before late `remove-unused-brs`, `remove-unused-names`, `rse`, and final `vacuum`

That placement tells us what Binaryen expects from the pass:

- earlier passes reduce local clutter before the nonlinear coloring stage
- `local-subtyping` must happen before coalescing freezes exact types
- `local-cse` and later cleanups profit from the simpler shared-local traffic
- branch and set cleanups later see fewer or simpler locals

## What the pass does **not** do

A future Starshine port should avoid broadening the pass beyond upstream behavior.

## Freshness note

A focused 2026-04-25 current-`main` spot check on `CoalesceLocals.cpp`, `pass.cpp`, `opt-utils.h`, helper surfaces, and `coalesce-locals.wast` did **not** surface a teaching-relevant drift beyond the `version_129` contract summarized here.
So the durable rule is:

- treat Binaryen `version_129` as the released semantic oracle for this dossier
- use the 2026-04-22 raw primary-source manifest when future work needs exact tagged release/source/test provenance
- use the 2026-04-25 current-`main` recheck as a narrow freshness bridge
- mention current-main drift only when it rises above the current "no teaching-relevant change found" status

`coalesce-locals` does **not**:

- merge subtype-compatible but unequal local types
- solve optimal graph coloring
- run a full global value numbering analysis
- preserve local names or DWARF data
- replace `local-subtyping`, `local-cse`, `merge-locals`, `reorder-locals`, or `simplify-locals`
- act like a generic effects/trap motion pass

The real Binaryen contract is narrower and more structural than the name alone suggests.

## The most important porting lessons

If Starshine ports `coalesce-locals`, preserve these facts first:

1. exact-type-only coalescing
2. value-aware interference, not just lifetime overlap
3. wasm zero-init and param-entry rules are part of correctness
4. unreachable local cleanup must happen before renumbering
5. loop backedge copies deserve extra weight
6. copy removal is part of the objective, not just local-count reduction
7. greedy order matters, so at least the natural/reverse comparison matters
8. dead-set cleanup may require refinalization
9. local-name metadata handling is part of the visible contract
10. the late two-slot scheduler placement is meaningful, not accidental

Those are the durable upstream truths.

## Sources

- [`../../../raw/binaryen/2026-04-25-coalesce-locals-current-main-recheck.md`](../../../raw/binaryen/2026-04-25-coalesce-locals-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-22-coalesce-locals-primary-sources.md`](../../../raw/binaryen/2026-04-22-coalesce-locals-primary-sources.md)
- [`../../../raw/research/0352-2026-04-25-coalesce-locals-current-main-and-test-map.md`](../../../raw/research/0352-2026-04-25-coalesce-locals-current-main-and-test-map.md)
- [`../../../raw/research/0264-2026-04-22-coalesce-locals-primary-sources-and-starshine-followup.md`](../../../raw/research/0264-2026-04-22-coalesce-locals-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0118-2026-04-20-coalesce-locals-binaryen-research.md`](../../../raw/research/0118-2026-04-20-coalesce-locals-binaryen-research.md)
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/CoalesceLocals.cpp>
- Binaryen `version_129` scheduler source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Binaryen `version_129` after-inlining helper: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- Binaryen `version_129` liveness helper: <https://github.com/WebAssembly/binaryen/blob/version_129/src/cfg/liveness-traversal.h>
- Binaryen `version_129` value-numbering helper: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/numbering.h>
- Binaryen `version_129` IR utilities: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/utils.h>
- Binaryen `version_129` lit tests: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/coalesce-locals.wast>
