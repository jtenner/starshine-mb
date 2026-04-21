---
kind: concept
status: supported
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0113-2026-04-20-optimize-casts-binaryen-research.md
related:
  - ./index.md
  - ./two-phase-dataflow.md
  - ./wat-shapes.md
  - ../heap2local/index.md
  - ../../no-dwarf-default-optimize-path.md
---

# Binaryen `optimize-casts` Strategy

## Upstream source rule

- Use Binaryen `version_129` as the current source oracle for this pass.
- The core implementation is `src/passes/OptimizeCasts.cpp`.
- Scheduler placement comes from `src/passes/pass.cpp` and the after-inlining helper in `src/passes/opt-utils.h`.
- The key helper contracts come from:
  - `src/ir/linear-execution.h`
  - `src/ir/properties.h`
  - `src/ir/effects.h`
  - `src/ir/utils.h`
- The shipped behavior examples come from `test/lit/passes/optimize-casts.wast`.

Primary source URLs:

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/OptimizeCasts.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/linear-execution.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-casts.wast>

## High-level intent

Binaryen uses `optimize-casts` to make local uses take advantage of already-known narrower reference types.

That sentence is true but incomplete.

The actual pass comment says three more important things:

1. the motivating examples are local-flow patterns where one use has already been cast and later uses still read the wider local
2. nearby passes like `simplify-locals`, `rse`, and `local-cse` already do related work, but not this exact cast-specific work
3. the pass is expected to grow more cast-specific optimizations later, which is why Binaryen keeps it separate

That makes the pass easier to describe honestly:

- it is a **cast-aware local-flow refinement pass**
- not a generic optimizer for every cast-like GC instruction

## The pass in one table

| Phase | What Binaryen does | Why it exists |
| --- | --- | --- |
| GC gate | Skip the pass entirely if GC is disabled | Non-GC modules have nothing relevant here |
| Earlier-motion phase | Find a later `ref.cast` / `ref.as_non_null` and duplicate it to an earlier `local.get` if safe | Expose narrower values earlier in the window |
| Refinalize | Recompute types after adding earlier casts | Rewrites refine local and expression types |
| Later-reuse phase | Save the best already-computed cast in a fresh local and retarget later less-refined gets | Reuse a narrow value without moving the cast earlier |
| Refinalize again | Recompute types after changing local/get types | New locals and redirected gets need correct final types |

## Phase 0: the pass is function-parallel and GC-gated

`OptimizeCasts` reports `isFunctionParallel() == true`, so Binaryen runs it as a per-function pass that can parallelize across functions.

Inside `doWalkFunction(...)`, the very first check is:

- if the module lacks GC features, return immediately

So a faithful Starshine port should not even try to run this logic on non-GC modules.

## Phase 1: `EarlyCastFinder` is the strict, trap-sensitive half

## Why this phase is stricter

This phase may duplicate a cast **earlier** than before.

That matters because `ref.cast` and `ref.as_non_null` can trap.

If moving a cast earlier would make the trap happen before some side effect or before a branch that used to skip the cast entirely, the transform would be unsound.

That is why `EarlyCastFinder` uses the stricter linear-execution model.

## Core walker choice

`EarlyCastFinder` inherits from `LinearExecutionWalker` with the default setting:

- `connectAdjacentBlocks = false`

That means:

- once execution is no longer obviously straight-line,
- `noteNonLinear()` fires,
- and this implementation flushes all pending movement state.

So this phase is limited to a strict “single linear window” model.

## The tracked state

For each local index, Binaryen tracks two parallel pieces of pending work:

- `currRefCastMove[index]`
  - earliest target `LocalGet`
  - best `RefCast` seen so far for that local
- `currRefAsMove[index]`
  - earliest target `LocalGet`
  - best `RefAs` seen so far for that local

The target is the earliest safe get in the current window.
The best cast is the most refined cast Binaryen would like to duplicate there if the window ends now.

## The barrier model comes from effects, not ad hoc if-statements

The constructor builds two effect templates:

- a dummy `RefCast`
- a dummy `RefAsNonNull`

Then `visitExpression(...)` analyzes each visited expression shallowly using `ShallowEffectAnalyzer` and asks:

- would moving a `ref.cast` past this be invalid?
- would moving a `ref.as_non_null` past this be invalid?

If yes, Binaryen flushes the pending work for that cast family.

That means the earlier-motion phase is governed by real effect and control-flow rules from `EffectAnalyzer`, not by a tiny handwritten whitelist.

## Why this matters in practice

This is why tests like these behave the way they do:

- `global.set` blocks moving a cast earlier
- a same-index `local.set` blocks moving a cast earlier
- a call blocks moving a cast earlier

The source comments explain the call case in beginner-friendly terms:

- perhaps the call branches away or traps first
- then the later cast would never have happened
- so moving the cast earlier would be wrong

## `visitLocalSet` is an extra per-index barrier

After generic barrier handling, `visitLocalSet(...)` flushes the tracked state for the local index being written.

So the pass refuses to move a cast for `x` across:

- `local.set $x ...`

That rule is easy to state and very important to preserve.

## `visitLocalGet` sets the earliest target

When Binaryen sees a `local.get`, it records that as the earliest candidate target for that local index if one is not already set.

For `ref.as_non_null`, there is one more guard:

- only nullable gets are tracked as useful targets

If the target local is already non-nullable, duplicating `ref.as_non_null` there would be pointless.

## `visitRefAs`: only `RefAsNonNull` is handled

`visitRefAs(...)` immediately ignores every `RefAs` except:

- `RefAsNonNull`

Then it uses `Properties::getFallthrough(...)` to see whether the cast ultimately falls through to a `LocalGet`.

If yes, and an earlier target exists for that local, Binaryen remembers the `RefAsNonNull` as the best candidate to move.

Important non-feature:

- extern conversions are not treated as casts here
- that comes from `Properties::getFallthrough(...)`, which explicitly excludes them

## `visitRefCast`: subtype-driven selection

`visitRefCast(...)` also uses `Properties::getFallthrough(...)` and looks for a final `LocalGet`.

A candidate cast is only considered usable if:

- an earlier target get exists for that local
- the cast’s result type is a subtype of the target get’s current type
- the target get is not already exactly that refined type

Then Binaryen keeps the **most refined** candidate cast seen so far.

This means:

- if a later cast is narrower than the current best, replace the best
- if it is wider, ignore it
- if it is equally refined, ignore the duplicate

The source comment is explicit that unrelated-cast special cases are not deeply modeled here; upstream assumes those would generally be optimized away already because they imply an inevitable trap.

## Flushing is where “candidate” becomes “scheduled rewrite”

When a barrier is hit, or the function/window ends, Binaryen flushes the best pending cast for each local into:

- `refCastToApply`
- `refAsToApply`

One more guard happens here:

- if the chosen cast is already located at the target get, do not schedule a duplicate there

That lets the finder keep tracking an already-optimal cast while still avoiding pointless rewrites.

## `EarlyCastApplier`: apply cast first, then `ref.as`

`EarlyCastApplier` is a separate `PostWalker` over `LocalGet`s.

For each target get, it:

1. wraps the get in a `ref.cast` if requested
2. then wraps that in a `ref.as_non_null` if requested

So if both are applied, the nested order is:

- `ref.as_non_null(ref.cast(local.get ...))`

The original later cast node is intentionally left behind for other later passes to clean up.

## Why `ReFinalize` runs immediately afterwards

After Phase 1, Binaryen runs `ReFinalize` on the function.

That is required because:

- the inserted earlier casts refine the surrounding types
- existing cast nodes may now refinalize differently
- later walkers need the updated types to be true

Several lit tests are built around exactly this: moving a more refined cast earlier can change the printed type of a related later cast after refinalization.

## Phase 2: `BestCastFinder` is the looser reuse half

## Why this phase can be looser

This phase does **not** move a cast earlier.

Instead, it asks:

- now that this cast already exists and executes here,
- which later gets can safely reuse the refined value?

That does not create the same “trap happens sooner” hazard as Phase 1.

## Core walker choice

`BestCastFinder` therefore sets:

- `connectAdjacentBlocks = true`

The `LinearExecutionWalker` comment explains that this lets Binaryen cheaply treat a dominator block and a trivially adjacent dominated block together without building a full CFG.

That is why this phase can look a little farther than the earlier-motion phase.

## The tracked state

Phase 2 uses two maps:

- `mostCastedGets`
  - current best casted value per local index in the active window
- `lessCastedGets`
  - final plan: for each best cast expression, which later `LocalGet`s should use it instead

`mostCastedGets` is reset whenever linear execution is interrupted.
`lessCastedGets` accumulates requests for the final rewrite.

## `visitLocalSet` still invalidates one index

A write to local `x` erases the best-cast fact for `x`.

So later gets of `x` are not allowed to reuse a casted value computed before that write.

## `visitLocalGet` records consumers of a better cast

When Binaryen visits a `local.get`, it checks whether a better casted version of the same local is currently known.

If so, and if the best cast’s type is a subtype of the get’s current type, it records that the current get should later be redirected to the best cast.

## `handleRefinement` sees through tees carefully

The refinement finder for `RefAs` and `RefCast` is subtle.

It first calls:

- `Properties::getFallthrough(..., NoTeeBrIf)`

This lets the pass detect a `local.tee` carrier without immediately looking through it.

If it sees a `local.tee`, it can update the best-cast fact for the tee’s local index.

Then it calls normal `getFallthrough(...)` to keep following the actual underlying local value.

That two-step design is the reason the pass can understand patterns like:

- `ref.cast(... (local.tee $y (local.get $x)))`

without losing the fact that `$y` now also carries the refined value.

## `updateBestCast` again prefers the most refined subtype

If several casts of the same local are present, Binaryen keeps the most refined one.

So later gets always point to the narrowest known value that is still type-compatible.

## `FindingApplier`: materialize the refined local

Once the finder is done, `FindingApplier` walks the function.

For every cast expression that has later consumers, it:

1. adds a fresh local of the cast expression’s refined type using `Builder::addVar(...)`
2. rewrites each consumer get to use that new local index and refined type
3. replaces the cast expression itself with a `local.tee` into that new local

This is a very concrete porting requirement:

- Binaryen does not rewrite the original local’s declared type here
- it creates a new carrier local for the refined value

## And then `ReFinalize` runs again

The second `ReFinalize` is required because:

- the redirected `LocalGet`s now have more refined types
- the new tee/local carrier becomes part of normal type propagation

## Helper dependencies are doing real work

## `LinearExecutionWalker`

This is the core shape restriction behind the whole pass.

It explains both:

- why Binaryen does not need a CFG here
- and why there are visible “it stops at `if` / loop / named block” bailout families

## `Properties::getFallthrough`

This is why the pass can look through:

- unnamed blocks
- `local.tee`
- other simple fallthrough-preserving wrappers

It is also why extern conversions are ignored.

## `EffectAnalyzer` / `ShallowEffectAnalyzer`

These are the correctness barrier for Phase 1.

They are the reason the pass is careful around:

- side effects
- control transfer
- local writes
- trap timing

## `Builder`

Not just convenience code.

The pass fundamentally depends on builder support to:

- allocate fresh locals
- create new `local.tee`
- wrap earlier gets in duplicated casts

## `ReFinalize`

This is part of the algorithm, not cleanup garnish.

Without it, the pass would leave stale local/get/cast types behind.

## Scheduler placement is part of the meaning

In `pass.cpp`, Binaryen places `optimize-casts` in the default function pipeline only when:

- GC is enabled
- `optimizeLevel > 1`

The important neighborhood is:

- `heap2local`
- `optimize-casts`
- `local-subtyping`
- `coalesce-locals`
- maybe `local-cse` depending on optimization level
- later `simplify-locals`

And `pass.cpp` includes a very explicit ordering note:

- coalescing may prevent subtyping
- so subtype first
- TODO: maybe reverse that when optimizing for size

That means scheduler placement is not accidental.

`optimize-casts` is supposed to sharpen values before later local-type cleanup and coalescing pressure blur those distinctions.

For higher optimize/shrink modes, `merge-locals` may appear immediately before it.

`opt-utils.h` also shows the whole default function pipeline is rerun on touched functions after inlining-oriented optimizing passes, so `optimize-casts` also matters inside those nested cleanups, not just in one top-level slot.

## What the pass does **not** do

A future Starshine port should avoid broadening the pass beyond upstream behavior.

`optimize-casts` does **not**:

- optimize `ref.test`
- optimize `br_on_cast` / `br_on_cast_fail`
- treat extern conversions as cast-like fallthroughs here
- build a full CFG or dominance tree
- reason across arbitrary joins
- immediately delete every old cast it makes redundant
- replace `local-subtyping`, `coalesce-locals`, `simplify-locals`, or `local-cse`

The real `version_129` contract is smaller and more local than the pass name suggests.

## The most important porting lessons

If Starshine ports `optimize-casts`, preserve these facts first:

1. two separate internal phases, not one blended algorithm
2. earlier movement is stricter than later reuse
3. only `ref.cast` and `ref.as_non_null` are in scope for `version_129`
4. per-local tracking with same-index write invalidation
5. `LinearExecutionWalker` windows, not arbitrary dominance
6. Phase 1 uses effect barriers; Phase 2 uses adjacent-block reuse
7. fresh refined locals plus `local.tee` are part of the rewrite contract
8. `ReFinalize` after both rewrite phases is mandatory
9. scheduler placement after `heap2local` and before `local-subtyping` / `coalesce-locals` is meaningful

Those are the durable upstream-level truths.

## Sources

- [`../../../raw/research/0113-2026-04-20-optimize-casts-binaryen-research.md`](../../../raw/research/0113-2026-04-20-optimize-casts-binaryen-research.md)
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/OptimizeCasts.cpp>
- Binaryen `version_129` scheduler source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Binaryen `version_129` after-inlining helper: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- Binaryen `version_129` linear-execution helper: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/linear-execution.h>
- Binaryen `version_129` fallthrough helper: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
- Binaryen `version_129` effects helper: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
- Binaryen `version_129` refinalization helper: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/utils.h>
- Binaryen `version_129` lit tests: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-casts.wast>