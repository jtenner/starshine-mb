# 0119 - `local-cse` Binaryen research

## Status

- Date: 2026-04-20
- Type: One-off raw investigation
- Scope: document one currently unimplemented no-DWARF / `-O4z` Binaryen pass in Starshine, using Binaryen `version_129` plus the saved generated-artifact audit to explain how `local-cse` really works, which helpers it leans on, and which IR shapes a future Starshine port must preserve.

## Why this pass

- `local-cse` is still unimplemented in Starshine and remains listed under removed pass names in `src/passes/optimize.mbt`.
- The canonical no-DWARF `-O` / `-Os` path runs it once in the late local-cleanup cluster:
  - after `coalesce-locals`
  - before full `simplify-locals`
- The saved generated-artifact `-O4z` audit records two skipped top-level slots:
  - slot `11`
  - slot `31`
- The early `-O4z` slot is especially informative because it shows the exact upstream precondition Binaryen wants before the pass in aggressive optimize mode:
  - `flatten`
  - `simplify-locals-notee-nostructure`
  - `local-cse`
- The late slot matters for the ordinary no-DWARF optimize path because it sits inside the `coalesce-locals -> local-cse -> simplify-locals` neighborhood that future Starshine preset honesty will need to preserve.
- The CLI name is easy to overread. Binaryen is **not** doing general global value numbering or full CFG-wide common-subexpression elimination here. The real implementation is smaller and sharper:
  - repeated **whole expression trees** only
  - inside one linear execution window at a time
  - by saving the first result in a temp local and replacing later repeats with `local.get`
  - after filtering by effect, determinism, and profitability rules

## Saved local source material

### Local Starshine / audit sources

- `src/passes/optimize.mbt`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `agent-todo.md`
- `.artifacts/o4z-wasm-opt-debug.log`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.json`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json`
- `docs/wiki/raw/research/0117-2026-04-20-simplify-locals-nostructure-binaryen-research.md`
- `docs/wiki/raw/research/0118-2026-04-20-coalesce-locals-binaryen-research.md`

### Official Binaryen `version_129` sources

- `src/passes/LocalCSE.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LocalCSE.cpp>
- `src/passes/pass.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `src/passes/opt-utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- `src/ir/linear-execution.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/linear-execution.h>
- `src/ir/effects.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
- `src/ir/properties.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
- `src/ir/properties.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.cpp>
- `src/ir/intrinsics.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/intrinsics.h>
- `src/ir/cost.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/cost.h>
- `test/lit/passes/local-cse.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/local-cse.wast>

## Fast answer

Binaryen’s `local-cse` pass is a late, function-parallel pass that looks for repeated **entire expression trees** inside a single linear execution window, keeps the first occurrence, stores it in a fresh temp local with `local.tee`, and replaces later repeated occurrences with `local.get`.

The easiest accurate summary is:

1. **scan** for repeated candidate trees
2. **check** whether effects or nondeterminism invalidate those planned reuses
3. **apply** the surviving reuses with temp locals

Important durable facts:

- The pass is registered as `common subexpression elimination inside basic blocks`, and that description is broadly right.
- However, the implementation uses `LinearExecutionWalker` with `connectAdjacentBlocks = true`, so it also handles some cheap dominance-like adjacent-block cases, such as a value before an `if` feeding the `then` arm.
- It is **not** global CSE, **not** full CFG GVN, and **not** LICM.
- It only handles **whole trees**, not arbitrary common subtrees.
- It deliberately ignores metadata while checking expression equality, so semantically equal trees with different branch-hint metadata can still fold.
- It deliberately ignores constants and `local.get` / `local.set` roots, and it also skips tiny size-1 candidates like `global.get` for profitability reasons.
- Repeated loads may be reused even though loads can trap, because the first retained load would still trap first and later copies would never execute.
- Calls normally do **not** qualify as repeated roots, but arguments inside calls may still be optimized.
- There is a narrow source-level exception for calls to functions annotated idempotent.
- The pass adds new locals, so Binaryen marks it as DWARF-invalidating.

## Where it appears in the scheduler

## Pass registration surface

In `pass.cpp`, Binaryen registers:

- `local-cse`
  - summary: `common subexpression elimination inside basic blocks`

That summary already hints at the intended scope: this is not a whole-function dataflow pass.

## Top-level no-DWARF `-O` / `-Os`

In `addDefaultFunctionOptimizationPasses()`, the ordinary late slot is:

- `coalesce-locals`
- `local-cse`
- `simplify-locals`
- `vacuum`
- `reorder-locals`
- `coalesce-locals`
- `reorder-locals`
- `vacuum`

The gate for that late `local-cse` slot is:

- `options.optimizeLevel >= 3 || options.shrinkLevel >= 1`

That means the canonical no-DWARF `-O` / `-Os` path in this repo still includes it, because those modes use `optimizeLevel=2` and `shrinkLevel=1`.

## Extra aggressive `-O4` / `-O4z` slot

`pass.cpp` also adds an earlier `local-cse` slot when `options.optimizeLevel >= 4`:

- `flatten`
- `simplify-locals-notee-nostructure`
- `local-cse`

The source comment explains why that prelude exists:

- `flatten` exposes more whole-tree matches
- but flatten also creates many locals that make things look different
- so Binaryen first runs a little simplify-locals cleanup before trying `local-cse`

This is a very important scheduler lesson for Starshine. The pass meaning is partly encoded in its neighbors.

## Saved generated-artifact `-O4z` evidence

The committed `-O4z` skipped-slot audit matches the source-level story exactly:

- slot `11`: `local-cse`
- slot `31`: `local-cse`

The saved full debug log goes further. Repo-local counting over `.artifacts/o4z-wasm-opt-debug.log` finds `36` `local-cse` executions in that one full Binaryen run, not just the two top-level slots.

That means the pass is important both as:

- a visible top-level pipeline stage
- and a repeated nested cleanup tool inside optimizing passes

## Nested reruns

`opt-utils.h` shows that `optimizeAfterInlining(...)` creates a filtered nested pass runner and then:

1. prepends `precompute-propagate`
2. calls `addDefaultFunctionOptimizationPasses()` again

So `local-cse` definitely reruns inside the optimizing cleanup helper used by:

- `dae-optimizing`
- `inlining-optimizing`

The repo’s no-DWARF path page also says `simplify-globals-optimizing` reruns the default function pipeline on changed functions without the extra prepended `precompute-propagate`. I am treating that specific `simplify-globals-optimizing` part as a **local-repo inference** here, not something rederived directly from `LocalCSE.cpp`.

## Actual implementation structure

## 1. Pass shape and helper surface

`LocalCSE` is a `WalkerPass<PostWalker<LocalCSE>>` and reports:

- `isFunctionParallel() == true`
- `invalidatesDWARF() == true`

So Binaryen considers it:

- a **function pass**
- safe to parallelize across functions
- willing to mutate locals enough that current DWARF updating cannot preserve debug info

The central helper surface is:

- `LinearExecutionWalker`
  - defines the execution windows and the cheap adjacent-block connection model
- `ExpressionAnalyzer`
  - hashes and compares trees
- `ShallowEffectAnalyzer` / `EffectAnalyzer`
  - decide what is impossible up front and what gets invalidated later
- `Properties::isShallowlyGenerative(...)`
  - blocks roots that may produce fresh values each time
- `Intrinsics::getAnnotations(...)`
  - recognizes idempotent function annotations
- `Measurer` and `CostAnalyzer`
  - implement the size-vs-speed profitability threshold

## 2. The core data structures reveal the algorithm

### `HashedExpression`

This is just:

- an `Expression*`
- plus a cached digest

The digest is only a fast bucket key. Equality still does a real structural check.

### `HEComparer`

If two digests match, Binaryen still calls `ExpressionAnalyzer::equal(...)`.

One important comment here: the comparer deliberately ignores metadata differences.

That means two structurally equal trees may fold even if metadata such as branch hints differs. The source comment’s reasoning is that `local-cse` only removes later executions, so it is not introducing a new execution of invalid metadata.

### `HashedExprs`

This maps one hashed-expression bucket to a vector of matching active expressions.

The first element in the vector is the chosen original. Later equal elements request reuse of that first one.

### `RequestInfo`

Each interesting expression can be in exactly one of two states:

- `requests > 0`
  - this expression is the original value that later repeats want to reuse
- `original != nullptr`
  - this expression is a repeat that wants to reuse an earlier original

The `validate()` method explicitly asserts that an expression cannot be both an original and a repeat.

That matters because if a tree appears three times, the second and third both point back to the **first**, not to each other.

## 3. Phase one: `Scanner`

`Scanner` inherits from `LinearExecutionWalker` and sets:

- `connectAdjacentBlocks = true`

It keeps two main pieces of state:

- `activeExprs`
  - the candidate repeated trees visible in the current linear window
- `activeIncrementalInfo`
  - a stack of `(hash, possible)` information used to compute parent hashes from already-computed child hashes in linear time

### Window resets

`doNoteNonLinear(...)` clears:

- `activeExprs`
- `activeIncrementalInfo`

but deliberately does **not** clear `requestInfos`.

So scanning links candidates only inside one current window, but already-recorded reuse plans survive until later phases.

### Hashing is bottom-up and linear-time

For each expression:

1. start with `ExpressionAnalyzer::shallowHash(curr)`
2. pop cached child hashes from `activeIncrementalInfo`
3. combine them into the parent hash
4. combine child `possible` flags as well

If a child came from another window, the stack will be empty and the parent is abandoned as a cross-window candidate.

### `isRelevant(...)`: what is even worth trying

The scanner skips roots that are:

- not concrete-typed
- `local.get`
- `local.set`
- constant expressions

The source comment gives the main intuition: this pass reuses computed values by storing them in locals, so it only wants roots that are worth materializing that way.

Profitability is then split by mode.

#### Shrink mode

If `shrinkLevel > 0`, Binaryen requires:

- measured size `>= 3`

The source comment says size `2` is intentionally left for future investigation.

#### Speed mode

If `shrinkLevel == 0`, Binaryen requires:

- `CostAnalyzer(curr).cost > 0`
- measured size `>= 2`

The reasoning is explicit:

- a `local.get` is basically free
- but VMs already do some CSE/GVN internally
- so tiny size-1 wins are not worth the extra temp local

That is why the shipped test leaves repeated `global.get` alone.

### `isPossible(...)`: what is semantically safe in principle

This early filter is different from profitability.

It rejects roots that could never be made safe later, because the scanner is greedy and does not backtrack.

#### Positive exception: idempotent calls

If the root is a `call` whose target function annotations say `idempotent`, the scanner immediately allows it.

The source comment is careful here:

- it checks the called function annotation
- not a call-site annotation
- because tracking a first call and hoping the later one is idempotent would complicate the pass

#### Negative rule: shallow non-trap side effects

Binaryen computes `ShallowEffectAnalyzer(...).hasNonTrapSideEffects()`.

If that is true, the root is impossible.

The source comment explains why this is done **early**, before we even know whether the root repeats:

- otherwise a side-effectful parent might greedily hide a useful pure child
- and by the time the parent fails later, the child opportunity would be gone

#### Negative rule: shallow generativity / nondeterminism

Binaryen also rejects roots where `Properties::isShallowlyGenerative(...)` is true.

From `properties.cpp`, the shallowly generative set includes roots like:

- ordinary non-idempotent `call`
- `call_indirect`
- `call_ref`
- `struct.new`
- `array.new*`
- `cont.new`

This is a very important GC-era rule: even if such an instruction has no side effects visible to the earlier shallow filter, it may still yield a **fresh** or otherwise different value each time.

### Repeats point back to the first original

When a repeated relevant+possible tree is seen:

- the repeat gets `info.original = vec[0]`
- the first original gets `requests++`

So the pass is intentionally first-occurrence-biased.

### Parent repeats cancel child requests

This is one of the most important implementation details.

When a parent tree repeats, the scanner walks the parent’s **direct children** and removes child-level requests that had been recorded already.

That gives Binaryen the behavior described in the file header:

- if the repeated `eqz(A)` can be reused as a whole
- then we do **not** also need a temp for `A`

This is why the pass feels bigger than a flat “replace every repeated node” rule. It tries to reuse the largest repeated tree that actually survives later safety checks.

## 4. Phase two: `Checker`

The scanner only records desired reuse. It does **not** yet know whether effects in between original and repeat make that reuse invalid.

`Checker` performs that validation.

It stores `activeOriginals`, mapping each currently-valid original to:

- `requestsLeft`
  - how many future repeats of that original remain in the current window
- `effects`
  - a full `EffectAnalyzer` result for the original expression

### In-between expressions invalidate active originals

For each visited expression `curr`, the checker first computes shallow effects for `curr` and asks whether `curr` invalidates any active original’s saved effects.

The exact call is:

- `effects.invalidates(originalInfo.effects)`

If an active original is invalidated:

- Binaryen subtracts all still-unseen future requests for that original
- erases the original completely if no requests remain
- removes it from `activeOriginals`

So invalidation is aggressive: once an intervening effect makes the future repeats unsafe, those future repeats are abandoned.

### Traps are deliberately ignored here too

Before invalidation testing, the checker sets:

- `effects.trap = false`

The source comment gives the reasoning in plain English:

- if the original expression traps, the first retained occurrence traps first
- later repeated copies are never reached
- so trap differences alone are not a reason to reject reuse

That is the direct reason repeated `load` can optimize in the shipped test.

### Idempotent current expressions do not invalidate their own kind

If `curr` is idempotent and shallowly equal to an active original, the checker skips invalidating that original.

This is a second narrow idempotent special-case, now on the invalidation side.

### Only originals that really have future requests pay for full effect analysis

If `curr` is an original with `requests > 0`, the checker computes a full `EffectAnalyzer` for `curr` and activates it.

If `curr` never attracted future repeats, it never pays that analysis cost.

That is an important performance detail.

### Repeats vanish if their original was invalidated earlier

If `curr` is a repeat but its original is no longer in `activeOriginals`, the checker just erases the repeat’s `RequestInfo`.

That means the later applier never even sees it as a valid optimization.

## 5. Phase three: `Applier`

`Applier` receives the surviving `RequestInfoMap` and mutates the IR.

It keeps:

- `originalLocalMap`
  - original expression -> fresh temp local index

and again sets:

- `connectAdjacentBlocks = true`

### Originals become `local.tee`

If a surviving original still has pending requests:

1. `Builder::addVar(getFunction(), curr->type)` adds a fresh temp local
2. the original expression is replaced with `local.tee temp, curr`

### Repeats become `local.get`

If a surviving repeat points to an original whose request count is still positive:

- the repeat is replaced by `local.get temp`
- the original’s remaining request count is decremented

### Temp-local state is cleared between windows

`doNoteNonLinear(...)` clears `originalLocalMap`.

This is a subtle but important point:

- the newly added locals are function locals in declaration scope
- but their intended logical lifetime is still only one linear window at a time

That is part of why the pass can add temps without turning into a whole-function register-pressure problem.

## 6. What counts as a “basic block” window here

The pass registration text says `inside basic blocks`, but `LinearExecutionWalker` makes the real picture slightly more subtle.

Because `connectAdjacentBlocks = true`, the window model is:

- pure straight-line block code stays connected
- some adjacent dominated code also stays connected
- but many control boundaries still force resets

### Positive adjacent case: before-`if` into the `then` arm

The shipped `dominance` test shows this directly.

A value computed before an `if` can feed a repeated use inside the `then` arm.

But the `else` arm is not connected to that same earlier window.

### Negative adjacent case: code after the `if`

The shipped `basics` test also shows that code after an `if` is **not** treated as still in the same window as before the `if`.

So the connection is not “all obvious dominance.” It is the cheap limited adjacency model from `LinearExecutionWalker`.

### Calls stay in the same cheap window

With `connectAdjacentBlocks = true`, the walker does not force a window reset on calls the way it normally would.

That is why a pure local-fed arithmetic tree can be reused after a call in the `basics` test.

Safety then comes from the checker:

- if the call’s effects would invalidate that original, the request is removed
- if the original only depends on locals and the call does not write those locals, the request survives

### Hard reset families

The walker still resets at boundaries like:

- named blocks
- between `then` and `else`
- loops
- unconditional branches
- switches
- returns
- tries / throws / rethrows / unreachable

So a future Starshine port that only says “within a block” is not quite enough, and a future port that says “full CFG dominance” is too much.

## 7. Important test-backed and source-backed shape lessons

## `basics`: same-block arithmetic is the easy positive

Two identical `i32.add` trees in one window become:

- one `local.tee`
- one `local.get`

Three identical trees become one `local.tee` and two `local.get`s.

## `basics`: after-`if` is a real barrier

The same add repeated after an `if` does **not** reuse the earlier one.

## `basics`: calls do not necessarily invalidate pure local-fed originals

A call between two repeated `(i32.add (local.get $x) (local.get $y))` roots still allows reuse, because the add itself is pure and the call does not mutate those locals.

## `basics`: `local.set` of a used local is a barrier

After `local.set $x`, the later `(i32.add (local.get $x) (local.get $y))` no longer reuses the old add.

## `recursive1`, `recursive2`, `self`: whole-tree matching plus child cancellation

These tests together show the real scan behavior:

- if a bigger parent repeats, child requests can be cancelled
- but a child-only repeated subtree can still survive if the bigger parent pattern does not fully subsume it in the right way

This is a very good place to teach beginners that the pass is not just “match identical nodes by text.”

## `loads`: implicit traps are not a blocker

Repeated `i32.load` from the same address is reused.

That proves the trap-ignoring part of the checker is real behavior, not just a comment.

## `calls`: ordinary repeated call roots are not candidates

Two identical direct calls remain two calls.

That is consistent with both:

- shallow non-trap side effects
- shallow generativity for non-idempotent calls

## `in-calls`: nested arguments can still optimize

Two calls with identical repeated arithmetic arguments become:

- the arithmetic tree computed once
- then fed into both calls via temp-local reuse

So the pass is not “call-blind.” It is only root-selective.

## `nested-calls`: parents with nested effects are ignored

A repeated `i32.add(call(), call())` parent is not reused.

This is the main whole-tree negative example for nested-effect children.

## `many-sets`: surrounding sets do not automatically block pure repeated values

Even when repeated arithmetic appears as the value of multiple `local.set`s, the arithmetic itself can still be reused.

That is a nice reminder that the pass cares about the repeated expression tree, not the syntactic statement form around it.

## `switch-children`: child ordering matters and is handled deliberately

The test verifies that repeated `br_table` / switch children can optimize and that Binaryen handles child ordering correctly.

This is a source of easy off-by-one or wrong-child-order bugs in a future port.

## `global`: repeated `global.get` stays unfused mainly for profitability

The test comment explains that repeated `global.get` is size `1`, so Binaryen skips it because the extra temp-local traffic is not a compelling win.

This is easy to misunderstand as “global gets are never safe.” That is not what the test is teaching.

## Additional source-backed shapes that the shipped lit test does not isolate

The following claims come from reading `LocalCSE.cpp` plus helper files directly. I did **not** find separate dedicated shipped `local-cse` lit cases for them in this thread.

### Idempotent direct calls can be reused

If the called function annotations say `idempotent`, the root call is allowed by `isPossible(...)`, and a shallowly equal idempotent call also does not invalidate an earlier same call in the checker.

### GC allocation roots are rejected as generative

From `properties.cpp`, shallow generativity includes:

- `struct.new`
- `array.new`
- `array.new_data`
- `array.new_elem`
- `array.new_fixed`
- `cont.new`

So repeated fresh-allocation roots are not eligible local-cse candidates.

### Metadata differences are ignored

Two structurally equal trees with different metadata still compare equal for the pass.

That is not a separate WAT shape, but it is a real semantic boundary.

## 8. What this pass does **not** do

Binaryen `version_129` `local-cse` is not:

- full CFG-wide GVN
- inter-block value numbering across arbitrary joins
- loop-invariant code motion
- subtree extraction for non-identical parents
- a replacement for `flatten`
- a replacement for `coalesce-locals`
- a replacement for `simplify-locals`
- a pass that intentionally optimizes every safe size-1 repeated value

The file header even says that a more global optimization might exist later, but the current pass intentionally keeps temp-local lifetimes short by staying local.

## 9. What a future Starshine port must preserve

## Algorithm shape

- Keep the three-stage `scan -> check -> apply` structure or an equivalent design.
- Preserve the “first occurrence is the original” rule.
- Preserve parent-over-child request cancellation.

## Window shape

- Preserve the limited `LinearExecutionWalker` window model, not just raw block lists and not a stronger full-CFG model.
- Specifically preserve the shipped dominance behavior:
  - before-`if` to `then` is allowed
  - after-`if` is not part of the same window

## Safety shape

- Keep the early shallow impossibility filter.
- Keep the later invalidation pass with real effect information.
- Keep trap-ignoring reasoning for repeated roots.
- Keep the shallow-generativity rejection rule.
- Keep the idempotent-call carveout.

## Profitability shape

- Keep the mode-dependent size threshold split:
  - shrink mode: size `>= 3`
  - speed mode: size `>= 2` and positive cost
- Keep constants and `local.get` / `local.set` roots out of the candidate set.

## Scheduler shape

- Preserve the early aggressive slot after `flatten` + `simplify-locals-notee-nostructure`.
- Preserve the ordinary late slot after `coalesce-locals` and before full `simplify-locals`.
- Preserve the nested rerun story under optimizing passes.

## Validation / metadata shape

- Expect local additions, so debug-info preservation needs extra work.
- Preserve the current “ignore metadata in equality” semantics unless there is a deliberate project decision to differ.

## Uncertainty and explicit inferences

1. The `simplify-globals-optimizing` nested-rerun note in this document is inherited from the repo’s maintained no-DWARF path page, not rederived directly from `LocalCSE.cpp` in this thread.
2. The idempotent-call and GC-generativity claims are direct source-derived conclusions from `LocalCSE.cpp`, `intrinsics.h`, and `properties.cpp`, but the shipped `local-cse.wast` file I read does not currently isolate them as dedicated lit fixtures.
3. I did not do a separate current-trunk drift audit for `main` in this thread. The pinned oracle here is Binaryen `version_129`.

## Bottom line

A good beginner-to-intermediate summary is:

- `local-cse` is a **small, local, temp-localizing tree-reuse pass**
- it runs in carefully chosen windows, not across an arbitrary CFG
- it uses a cheap greedy scan plus a later correctness filter
- it is safe because it respects effects, determinism, and trap ordering
- it becomes much more valuable after other passes expose cleaner repeated whole trees
- and its exact scheduler neighborhood is part of the real implementation contract, not just pipeline trivia
