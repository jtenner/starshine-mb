# 0113 - `optimize-casts` Binaryen research

## Status

- Date: 2026-04-20
- Type: One-off raw investigation
- Scope: document one currently unimplemented no-DWARF / `-O4z` Binaryen pass in Starshine, using Binaryen `version_129` plus the saved generated-artifact audit to explain how `optimize-casts` really works, which helpers it depends on, which GC and local-flow shapes it rewrites, and what a future Starshine port must preserve.

## Why this pass

- `optimize-casts` is still unimplemented in Starshine and remains listed among removed upstream pass names in `src/passes/optimize.mbt`.
- The canonical Binaryen no-DWARF `-O` / `-Os` path runs it in the middle GC/local cleanup cluster, after `heap2local` and before `local-subtyping` and `coalesce-locals`.
- The saved generated-artifact `-O4z` audit records it as a real skipped top-level upstream slot at slot `28`.
- The saved Binaryen debug log also shows many more `optimize-casts` executions later in the same optimization run, which matches the nested rerun story from `opt-utils.h` and the repo’s no-DWARF pathway page.
- This pass is especially easy to overstate. The name sounds like “optimize all cast-like operations,” but the actual `version_129` implementation is much narrower:
  - it only handles `ref.cast`
  - and `ref.as_non_null`
  - on local-based value flows that Binaryen can reason about with a very cheap linear-execution walk
- That narrowness is useful. `heap2local` is already implemented in Starshine, and `local-subtyping` is an obvious next-neighbor. A good dossier here should make the entire GC-local cluster easier to port honestly.

## Saved local source material

### Local Starshine / audit sources

- `src/passes/optimize.mbt`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `.artifacts/o4z-wasm-opt-debug.log`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json`
- `agent-todo.md`

### Official Binaryen `version_129` sources

- `src/passes/OptimizeCasts.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/OptimizeCasts.cpp>
- `src/passes/pass.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `src/passes/opt-utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- `src/ir/linear-execution.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/linear-execution.h>
- `src/ir/properties.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
- `src/ir/effects.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
- `src/ir/utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/utils.h>
- `test/lit/passes/optimize-casts.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-casts.wast>

## Fast answer

Binaryen’s `optimize-casts` pass is a GC-aware, function-parallel local-flow cleanup pass.

It is not a generic cast simplifier.

For `version_129`, the implementation is a deliberately narrow two-phase algorithm:

1. **move the best cast earlier** when doing so is safe inside a strict straight-line execution window
2. **reuse the best already-computed cast later** by storing it in a new local and redirecting less-refined `local.get`s to that new local

Important durable facts:

- The pass is **GC-gated**: if the module does not have GC enabled, the pass returns immediately.
- The pass handles only:
  - `ref.cast`
  - `ref.as_non_null`
- It does **not** currently optimize:
  - `ref.test`
  - `br_on_cast` / `br_on_cast_fail`
  - extern-conversion `ref.as` forms like `any.convert_extern` / `extern.convert_any`
- The pass uses `LinearExecutionWalker`, not a full CFG or dominance tree.
- It intentionally uses **two different safety models**:
  - moving a cast earlier is stricter because it may make a trap happen earlier
  - reusing a cast later is looser because the trap already happened at the original site
- The pass is willing to add new locals and new `local.tee`s.
- It relies on `ReFinalize` after each rewrite phase because the rewritten IR has more refined local/get types.
- The implementation comment explicitly says the pass lives near, but is not the same as, work in `SimplifyLocals`, `RedundantSetElimination`, and `LocalCSE`.

## Where it appears in the scheduler

## Top-level no-DWARF path

Binaryen `version_129` `pass.cpp` schedules `optimize-casts` in the default function pipeline only when GC is enabled and `optimizeLevel > 1`.

In the canonical no-DWARF `-O` / `-Os` path recorded in this repo, the relevant neighborhood is:

- `heap2local`
- `optimize-casts`
- `local-subtyping`
- `coalesce-locals`
- `local-cse`
- `simplify-locals`

That is an important semantic clue:

- `heap2local` tends to make more GC values local-based and therefore easier for this pass to see
- `optimize-casts` then sharpens the local users of those GC values
- `local-subtyping` comes before `coalesce-locals` because `pass.cpp` explicitly comments that coalescing can block later subtyping opportunities

For the saved generated-artifact `-O4z` replay, the skipped-unimplemented slot list shows:

- slot `28`: `optimize-casts`

That higher-aggression run also places `merge-locals` immediately before it, which matches the `pass.cpp` rule that `merge-locals` is inserted only at higher optimize/shrink settings.

## Nested reruns

`opt-utils.h` shows that `optimizeAfterInlining(...)` prepends `precompute-propagate` and then reruns `addDefaultFunctionOptimizationPasses()` on the touched functions.

That means `optimize-casts` definitely reruns under optimizing passes like:

- `dae-optimizing`
- `inlining-optimizing`

The saved `.artifacts/o4z-wasm-opt-debug.log` matches that expectation. Repo-local grep over the saved debug log finds `18` `optimize-casts` executions in the same full run, not just the one top-level slot.

I am treating the combination of:

- `pass.cpp`
- `opt-utils.h`
- the repo’s no-DWARF pathway page
- the saved debug log

as the durable scheduler story.

## What the implementation is actually trying to do

The top comment in `OptimizeCasts.cpp` says the pass wants to refine uses of locals where possible.

The motivating example is not “delete a cast.” It is more like:

- one use of a local has already been cast to a narrower ref type
- nearby later uses still read the wide local
- use the already-refined value instead

That can unlock later optimizations. The comment gives an itable / vtable example where refining one use of `this` can help refine later field reads and eventually assist devirtualization.

The comment also explains why this is its own pass even though nearby passes seem related:

- `SimplifyLocals` already swaps uses to better locals when they exist
- `RedundantSetElimination` can do a related thing across basic blocks
- `LocalCSE` can also materialize reusable expressions in locals

But `OptimizeCasts` keeps cast-specific logic in one place and is intended to grow additional cast-specific cleanups later.

That is a useful “what it sounds like vs what it is” takeaway:

- the pass is really a **cast-aware local-use refinement pass**
- not a general cast simplifier over all GC/control-flow constructs

## Actual implementation structure

## 1. Pass shape

`OptimizeCasts` is a `WalkerPass<PostWalker<OptimizeCasts>>` and reports:

- `isFunctionParallel() == true`
- `create() -> std::make_unique<OptimizeCasts>()`

And `doWalkFunction(...)` immediately bails out if the module lacks GC:

- `if (!getModule()->features.hasGC()) return;`

So this is a per-function pass, parallelizable across functions, but inactive on non-GC modules.

## 2. Two passes inside one pass

The most important implementation fact is the internal split:

### Phase A: `EarlyCastFinder` + `EarlyCastApplier`

Goal:

- find a later `ref.cast` or `ref.as_non_null`
- duplicate it to an earlier `local.get`
- but only if moving it earlier is safe

Why separate:

- moving a trapping cast earlier can change behavior if something in between had side effects or could branch away first

### Phase B: `BestCastFinder` + `FindingApplier`

Goal:

- find the best already-computed casted version of a local value
- save it in a fresh local
- redirect later less-refined `local.get`s to that fresh local

Why separate:

- here the cast stays at its original execution point
- the pass is only reusing it later
- so the trap-timing risk is much smaller

A future Starshine port should not collapse those two phases into one vague “find better casts” pass unless it preserves the safety asymmetry.

## 3. Phase A: moving casts earlier

## Core walker choice

`EarlyCastFinder` is a `LinearExecutionWalker` using the default conservative behavior:

- `connectAdjacentBlocks = false`

That means as soon as execution is not obviously straight-line, the walker calls `noteNonLinear`, which in this implementation flushes all pending state.

This is the strict phase because it can make casts trap earlier than before.

## Per-local state

For each local index, the pass tracks:

- the earliest `LocalGet` target it could move a cast to
- the best `RefCast` seen so far for that local
- the best `RefAsNonNull` seen so far for that local

Those are stored in:

- `currRefCastMove`
- `currRefAsMove`

Each entry is basically “if we had to commit now, where should we duplicate the best cast we have seen for this local?”

## Barrier model

This phase does not special-case every instruction by hand.

Instead, the constructor builds two generic effect templates:

- one dummy `RefCast`
- one dummy `RefAsNonNull`

Then `visitExpression(...)` analyzes each real expression shallowly with `ShallowEffectAnalyzer` and asks whether moving a cast past that expression would be invalid.

Concretely:

- if the current expression invalidates a `ref.cast`, flush all pending `ref.cast` moves
- if it invalidates a `ref.as_non_null`, flush all pending `ref.as_non_null` moves

That is why global side effects, calls, control transfer, traps, and local/global conflicts matter here.

This is also where the crucial call asymmetry begins:

- **moving** a cast earlier past a call can be unsafe
- because the call might branch away or perform visible work before the cast traps

## Local-set barrier

`visitLocalSet(...)` first runs the generic barrier logic, then explicitly flushes the tracked state for the local index being written.

So the pass does not move a cast for local `x` across `local.set x`.

That matches the tests and is one of the most important beginner-facing bailout rules.

## Candidate detection via `Properties::getFallthrough`

`visitRefCast(...)` and `visitRefAs(...)` both use `Properties::getFallthrough(...)` to look through simple value-preserving carriers.

That means a cast can still be recognized when it is wrapped in things like:

- unnamed blocks whose last value falls through
- `local.tee`
- other simple fallthrough-preserving carriers that `Properties` understands

But `Properties` explicitly does **not** treat extern conversions as casts/fallthroughs here:

- `AnyConvertExtern`
- `ExternConvertAny`

So those forms are intentionally ignored by `optimize-casts`.

## `ref.as_non_null` handling

Only `RefAsNonNull` is considered.

Important details:

- if the target `local.get` is already non-nullable, the pass does not bother duplicating `ref.as_non_null` there
- because it would be semantically useless

That is locked in by both the code and the tests.

## `ref.cast` handling

The `ref.cast` logic is more subtle.

A candidate cast is usable only if:

- a target `local.get` for that local index exists in the current linear window
- the cast type is a subtype of the target get’s current type
- and the target get’s type is not already exactly that refined type

So the pass refuses moves that would break typing by trying to store an unrelated or wider type into the earlier location.

If several candidate casts exist, it keeps the **most refined** one.

The source comment explains the intended cases using a subtype chain like `$A -> $B -> $C` plus an unrelated `$D`:

- if a later cast is more refined than the current best, replace the current best
- if it is less refined, ignore it
- if it is the same refinement, ignore the duplicate
- if it is unrelated, upstream assumes this would already trap and have been optimized away earlier, so the special case is not modeled deeply here

That is an important source-level honesty point: current Binaryen is pragmatic here, not formally solving every incompatible-nested-cast pattern.

## Flushing and why it exists

When Phase A hits a barrier or the end of a linear window, it flushes per-local pending work into final application maps:

- `refCastToApply`
- `refAsToApply`

The idea is:

- once a barrier is reached, nothing later can legally move across it
- so the best cast seen so far is the final answer for that earlier `local.get`

But the flush has one more guard:

- if the best cast is already sitting on the exact target `local.get`, do not schedule a duplicate copy there

So the finder is allowed to keep tracking an already-optimal cast at the target in case an even better cast appears later, but it avoids pointless duplication.

## Applying earlier moves

`EarlyCastApplier` is a separate `PostWalker` over `LocalGet`s.

For each target get:

- apply a `ref.cast` first if needed
- then apply a `ref.as_non_null` if needed

If both apply, they are nested.

The original later cast is left in place for later optimizations to clean up. The pass comment and tests are explicit about this.

## Why `ReFinalize` runs here

After Phase A, Binaryen runs `ReFinalize` over the function.

That is not optional cleanup. It is required because:

- the newly inserted earlier casts refine expression and local types
- later IR nodes may now have more precise types than before
- some existing cast nodes may now refinalize into narrower or non-nullable forms

Several shipped tests intentionally rely on this behavior. For example, moving a later `ref.cast (ref $B)` earlier can cause another older cast to refinalize into a `ref.cast (ref $B)` as well.

## 4. Phase B: reusing the best already-computed cast

## Core walker choice

`BestCastFinder` is also a `LinearExecutionWalker`, but this phase deliberately sets:

- `connectAdjacentBlocks = true`

The source comment explains why this is safe here and not in Phase A:

- this phase does **not** move a trap earlier
- it only reuses a cast value later
- so adjacent dominated blocks can be treated together cheaply without building a full CFG

This is the most important algorithmic asymmetry in the whole pass.

## State model

Phase B tracks two maps:

- `mostCastedGets`
  - for each local index, the most refined casted version seen in the current linear / adjacent-block window
- `lessCastedGets`
  - for each best cast expression, all the later `LocalGet`s that should be redirected to that best cast

`mostCastedGets` is temporary state for the current region.
`lessCastedGets` is the final “rewrite plan” for the whole function.

## Nonlinear boundaries

When the walk hits non-linear control flow, `mostCastedGets` is cleared.

So this phase still does **not** do arbitrary whole-function dominance.

It just tolerates the trivial adjacent-block dominance cases that `LinearExecutionWalker` can represent cheaply.

## Local-set barrier

As in Phase A, a `local.set` to index `x` clears the current best-cast fact for `x`.

So later gets of `x` are not rewritten to use a refined value computed before the write.

## How it finds refinements

`BestCastFinder` visits both:

- `RefCast`
- `RefAs`

and funnels them into `handleRefinement(...)`.

That helper uses `Properties::getFallthrough(...)` in two steps:

1. first with `FallthroughBehavior::NoTeeBrIf`
   - this lets the pass see whether the cast is directly feeding a `local.tee`
   - so the tee itself can be treated as the carrier of a refined local value
2. then with normal fallthrough behavior
   - this lets the pass keep looking through value-preserving wrappers to an eventual `LocalGet`

That two-step handling is why the pass understands patterns like:

- `ref.cast(... (local.tee $y (local.get $x)))`

instead of only the simplest naked `local.get` shape.

## Choosing the best cast

When several casted versions of the same local exist, `updateBestCast(...)` keeps the most refined subtype.

If a later `local.get` of that same local still has a wider type, `visitLocalGet(...)` records that it should be redirected to the best casted value.

So the pass is essentially building a tiny per-local “best current refinement” fact and exploiting it until a barrier resets that fact.

## Applying later reuse

`FindingApplier` walks the function after the finder has finished.

For every cast expression that has consumers in `lessCastedGets`, it:

1. adds a fresh local with `Builder::addVar(...)` using the cast’s refined type
2. rewrites each later consumer get to load from that new local and updates the get’s type too
3. replaces the original cast expression with a `local.tee` into that fresh local

This is a very concrete important fact for a future port:

- the pass does not magically retag existing locals
- it materializes a new refined local and uses that as the carrier

And then Binaryen runs `ReFinalize` again, because the `local.get` types were changed.

## 5. Helper utilities and analyses that actually matter

## `LinearExecutionWalker`

This is the structural backbone of the pass.

It gives Binaryen a cheap “execution order, until control flow stops being linear” walk without building a full CFG.

That explains several visible behavior choices:

- strict same-window reasoning in Phase A
- adjacent-block reuse in Phase B
- no arbitrary join/dominator reasoning

## `Properties::getFallthrough`

This is how the pass sees through wrappers like:

- unnamed blocks
- `local.tee`
- fallthrough-preserving casts

It is also why extern conversions are ignored: `properties.h` explicitly says those `RefAs` forms are not treated as casts/fallthroughs here because doing so would misoptimize later casts.

## `EffectAnalyzer` and `ShallowEffectAnalyzer`

These are the safety wall for Phase A.

They are the reason the pass:

- does not move traps earlier across visible side effects
- does not move casts earlier across control-transfer hazards
- flushes pending cast motion at safe boundaries instead of guessing

This is also what makes the pass safe around things like `global.set`, calls, and same-local writes.

## `Builder` / `Builder::addVar`

The pass is not purely a substitution pass.

It materializes new locals and tees. `Builder::addVar(...)` is therefore part of the algorithm, not just a convenience.

## `ReFinalize`

Mandatory after both rewrite phases.

Without it, refined local/get types and rewritten cast nests would be stale or inconsistent.

## 6. Important WAT / IR shape families

## Positive family 1: use the already-casted value later

Core shape:

- compute `ref.cast (ref $A) (local.get $x)`
- later still read `local.get $x`
- pass inserts a fresh `(ref $A)` local and redirects the later get to it

This is the simplest “reuse, not remove” family.

## Positive family 2: duplicate the best later cast to the earliest safe get

Core shape:

- first `local.get $x`
- later `ref.cast (ref $B) (local.get $x)`
- no earlier barrier in the same strict linear window
- pass duplicates the better cast at the first safe get site

This is the easiest place to misunderstand the pass as overaggressive. It is only allowed because Phase A’s barrier logic proves the move is safe.

## Positive family 3: choose the most refined subtype

If both of these exist in the same usable window:

- `ref.cast (ref $A) ...`
- `ref.cast (ref $B) ...` where `$B <: $A`

then Binaryen prefers `$B` for later reuse/motion.

This is a major reason the pass matters before `local-subtyping` and `coalesce-locals`.

## Positive family 4: nullable to non-null via `ref.as_non_null`

For a nullable local, the pass can:

- move or reuse `ref.as_non_null`
- create a non-nullable carrier local
- redirect later gets to that non-nullable local

But it refuses to do pointless work when the target get is already non-nullable.

## Positive family 5: look through `local.tee` and unnamed blocks

The pass is not limited to naked `local.get`s.

Because it relies on fallthrough analysis, it can see useful shapes through:

- unnamed result blocks
- `local.tee`

That is why several tests use carrier shapes instead of only direct gets.

## Negative family 1: same-index `local.set` blocks reuse and motion

If a local’s value changes, the pass clears that index’s tracked cast information.

So a future port must not accidentally reuse a refined value across:

- `local.set $x ...`

when the refined fact was learned before that write.

## Negative family 2: non-linear control-flow boundaries reset the window

The pass deliberately stops at boundaries like:

- `if`
- loops
- named blocks
- other nonlinear structures seen by `LinearExecutionWalker`

except for the limited adjacent-block reuse that Phase B enables.

So it does not currently solve “the cast is in the condition and the use is inside one arm” unless that falls into a trivial adjacent-block case. The source comment even has a TODO about possibly looking past basic blocks later.

## Negative family 3: moving earlier is stricter than reusing later

This is one of the most important beginner-facing corner cases.

Examples from the tests show:

- a call or global side effect may block **backward** movement of a cast
- but a later get may still reuse an already-computed cast **after** a call

Reason:

- moving a cast earlier can make a trap happen before code that previously ran first
- reusing the cast later does not change when the cast itself executes

## Negative family 4: already-refined or incompatible target types do not move

The pass does not move a cast to an earlier get if:

- the earlier get is already equally refined or better
- or the cast type is not in the required subtype relation with that target get’s type

This is important for soundness. The `avoid-erroneous-cast-move` test exists exactly to lock that in.

## Negative family 5: extern conversions are not casts here

`ref.as` extern-conversion forms are deliberately excluded by `Properties::getFallthrough`.

So a future Starshine port should not broaden the pass by treating those as ordinary fallthrough-preserving casts unless it first matches newer upstream behavior with evidence.

## Negative family 6: unrelated nested cast special cases are mostly assumed away

The Phase A source comment explicitly says that if the same local is cast to unrelated types in one window, an inevitable trap should already have been optimized away earlier.

That means current Binaryen behavior here is intentionally narrow and pragmatic rather than a full formal solver for every impossible nested-cast combination.

## What this pass does not do

`optimize-casts` is not:

- a generic GC cast optimizer for all cast-like instructions
- `ref.test` optimization
- `br_on_cast` optimization
- a whole-CFG dominance pass
- a module-wide analysis pass
- a pass that immediately deletes all now-redundant old casts
- a replacement for `local-subtyping`, `coalesce-locals`, `simplify-locals`, or `local-cse`

A good beginner summary is:

- find the best nearby refined local value
- sometimes move that cast earlier safely
- otherwise save it and reuse it later
- leave broader cleanup to neighboring passes

## What a future Starshine port must preserve first

If Starshine ports `optimize-casts`, the implementation should preserve these upstream facts before trying to be cleverer:

1. GC gate: do nothing on non-GC modules.
2. Two-phase structure:
   - strict earlier-motion phase
   - looser later-reuse phase
3. `ref.cast` plus `ref.as_non_null` only, at least for `version_129` parity.
4. No extern-conversion `RefAs` handling.
5. Per-local tracking with same-index `local.set` invalidation.
6. `LinearExecutionWalker`-style linear window limits.
7. The `connectAdjacentBlocks` asymmetry between the two phases.
8. Effect-based motion barriers for the earlier-motion phase.
9. `Builder::addVar(...)` / `local.tee` materialization for reuse.
10. `ReFinalize` after each rewrite phase.
11. Scheduler placement after `heap2local` and before `local-subtyping` / `coalesce-locals`.

A port that merely “reuses narrower locals” but ignores those details will not be an honest Binaryen port.

## Easy misunderstandings

1. **“This optimizes all reference cast/test forms.”**
   - False for `version_129`. The actual code only handles `ref.cast` and `ref.as_non_null`.
2. **“This is one local-value propagation pass.”**
   - Not quite. It is two different dataflow ideas with different safety rules.
3. **“If a later cast exists, Binaryen can always move it earlier.”**
   - False. Effect and control-flow barriers often stop the move.
4. **“If a call is in between, the pass must stop entirely.”**
   - False. That is true for moving earlier, but not always for reusing later.
5. **“The pass just removes casts.”**
   - Not directly. It often adds locals and leaves later cleanup to other passes.
6. **“This must use a full CFG because it reasons about later uses.”**
   - False. It deliberately uses `LinearExecutionWalker` and only handles cheap local-flow windows.

## Open questions / uncertainty

1. The source comment explicitly says it may be worth looking past individual basic blocks later, especially for casts in an `if` condition used in an arm. That is future-looking design intent, not current `version_129` behavior.
2. The saved `-O4z` debug log clearly shows repeated `optimize-casts` executions, but I did not re-open every optimizing caller in this thread. I am treating `opt-utils.h`, the repo’s no-DWARF page, and the saved log as the durable source for the nested-rerun story.
3. The current implementation only handles `RefAsNonNull` among `RefAs` forms. If newer upstream versions expand this, that should be documented as drift rather than silently backported into this `version_129` dossier.

## Durable conclusions

- `optimize-casts` in Binaryen `version_129` is a narrow, GC-only, function-parallel pass for improving how local-based casted values are reused.
- The pass has two asymmetrical internal algorithms: one safely duplicates better casts earlier, and the other stores and reuses the best already-computed cast later.
- The most important correctness boundary is not “can I see a cast nearby?” but “am I still inside the cheap linear-execution model where this rewrite is sound?”
- `EffectAnalyzer`, `LinearExecutionWalker`, `Properties::getFallthrough`, and `ReFinalize` are not incidental helpers; they are the core of the algorithm.
- The pass sits in exactly the GC/local-cleanup neighborhood where Starshine’s next missing-pass work is likely to happen, which makes a precise dossier here especially valuable.
- The biggest beginner trap is the name: `optimize-casts` sounds broad, but the real `version_129` contract is small, local, and deliberately conservative.