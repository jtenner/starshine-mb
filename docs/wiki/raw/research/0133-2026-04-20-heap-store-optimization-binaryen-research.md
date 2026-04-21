# 0133 - `heap-store-optimization` Binaryen research

## Status

- Date: 2026-04-20
- Type: One-off raw investigation
- Scope: deepen the currently shallow `heap-store-optimization` pass docs using official Binaryen `version_129` sources, the shipped dedicated lit test, the repo's canonical no-DWARF scheduler note, the updated pass tracker, the current Starshine HOT implementation and tests, the saved generated-artifact `-O4z` audit, and the narrow current-`main` freshness check.

## Why this pass

- `docs/wiki/binaryen/passes/tracker.md` had just promoted `heap-store-optimization` to the top suggested next target after the `precompute` dossier landed.
- The pass is already **implemented** in Starshine, but it only had a landing page.
- It matters to both of the scheduler stories this repo keeps using:
  - the canonical no-DWARF `-O` / `-Os` path runs it twice, both times under the GC feature gate
  - the saved generated-artifact `-O4z` audit observed the same two top-level slots at Binaryen slots `17` and `45`
- The name is easy to misunderstand.
  - It sounds like a general heap optimizer.
  - In Binaryen `version_129`, it is actually a much narrower pass centered on `struct.set` -> `struct.new` folding.
  - The file itself still opens with `TODO: Add dead store elimination / load forwarding here.`, which is strong evidence that those broader optimizations are not the current pass contract yet.
- The tracker explicitly called out one documentation gap worth fixing:
  - the repo needed a clearer explanation of what upstream Binaryen means by GC heap-store cleanup versus what the current Starshine pass implements.
- `agent-todo.md` currently has **no dedicated `HSO` slice**. The relevant local backlog surface is indirect:
  - the shared post-SSA hot cleanup prefix mention that already includes `optimize-instructions -> heap-store-optimization -> pick-load-signs`
  - the in-tree pass, cmd, perf, and artifact replay tests that already cover the implemented pass.

## Local source material

### Repo scheduler / backlog / audit sources

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/binaryen/passes/heap-store-optimization/index.md`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.json`
- `.artifacts/o4z-wasm-opt-debug.log`
- `agent-todo.md`
- `src/passes/optimize.mbt`
- `src/passes/registry_test.mbt`

### Local Starshine implementation files

- `src/passes/heap_store_optimization.mbt`
  - current summary: `Fold exact struct.set writes into nearby struct.new allocations when local and effect ordering stays safe.`
  - actual current shape: a HOT-region port of the same core constructor-folding idea, with custom effect masks, subtree/control-flow safety helpers, optional default-field materialization, descriptor handling, block-prefix peeling, and writeback-preserving cleanup helpers
- `src/passes/heap_store_optimization_test.mbt`
  - extensive reduced coverage for tee-wrapped folds, consecutive-set chains, default and descriptor constructors, pure/read-only prefix peeling, local/global/memory/table blockers, nested control flow, and non-folding safety cases
- `src/passes/perf_test.mbt`
  - explicit fast-path tests showing the current implementation can skip raw lifting when a function has no heap-store candidates
- `src/cmd/cmd_wbtest.mbt`
  - direct CLI regression coverage for many reduced shapes plus native debug-artifact replay

## Official Binaryen `version_129` sources

### Main implementation and scheduler

- `src/passes/HeapStoreOptimization.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/HeapStoreOptimization.cpp>
  - key sections from a direct line-numbered read:
    - pass shell, CFG action collection, and function walk: lines `34-80`
    - immediate tee-wrapped fold: lines `82-101`
    - block-local chain handling: lines `104-160`
    - `trySwap(...)`: lines `162-190`
    - `optimizeSubsequentStructSet(...)`: lines `192-300`
    - `canSkipLocalSet(...)`: lines `302-361`
- `src/passes/pass.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - registration: lines `228-230`
  - early default-function slot: lines `659-661`
  - late default-function slot: lines `734-736`
- `CHANGELOG.md` on current upstream `main`
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/refs/heads/main/CHANGELOG.md>
  - direct `2026-04-20` check: the changelog still records `Add a new --heap-store-optimization pass. (#6882)` under `v119`

### Helper headers the pass directly depends on

- `src/cfg/cfg-traversal.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/cfg/cfg-traversal.h>
  - important because the pass is a `CFGWalker<...>` pass, not a plain linear postwalk
- `src/ir/effects.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
  - important helpers and comments reviewed:
    - `transfersControlFlow()`
    - `hasUnremovableSideEffects()`
    - `orderedBefore(...)`
    - `invalidates(...)`
    - `ShallowEffectAnalyzer`
- `src/ir/local-graph.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h>
  - important comments reviewed:
    - eager vs lazy local graph distinction
    - `LazyLocalGraph::canMoveSet(...)`
    - the forward-movement / influenced-get assumption

### Shipped test surface reviewed for this note

- `test/lit/passes/heap-store-optimization.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/heap-store-optimization.wast>

This one file is the main shipped contract surface.

Representative test families in it include:

- immediate tee folds: `$tee`
- preserving old field side effects: `$side-effects-in-old-value`
- allowing safe new-value side effects: `$side-effects-in-new-value`
- multi-field ordering conflicts and non-conflicts: `$side-effect-conflict`, `$side-effect-ok`
- subsequent local-set chains: `$optimize-subsequent`, `$optimize-chain`, `$tee-and-subsequent`
- pattern breakers and swap limits: `$optimize-subsequent-bad-local`, `$pattern-breaker`, `$dont-swap-subsequent-struct-new`
- target-local read/write safety: `$ref-local-write`, `$ref-local-read`, `$other-local-write`, `$ref-other-read`
- default-constructor materialization: `$default`
- unreachable-code bailouts: `$unreachable`
- internal vs external control flow: `$control-flow-in-set-value`, `$control-flow-in-set-value-safe`, `$control-flow-in-set-value-safe-call`, `$control-flow-in-set-value-safe-return`, `$control-flow-in-set-value-unsafe-call`
- loop / if-arm / sequence control-flow hazards: `$loop`, `$loop-more-flow`, `$loop-in-value`, `$in-if-arm`, `$in-if-arm-yes`, `$control-flow-in-set-value-sequence*`

The test file also has an important scheduler hint right in the run line:

- `wasm-opt %s --remove-unused-names --heap-store-optimization ...`

The comment explains why:

- `remove-unused-names` lets the optimizer see blocks with no real breaks as having no nonlinear control flow.

So upstream's own dedicated HSO test surface already documents one non-obvious pass interaction.

## Freshness check

I did a narrow direct `version_129` vs current-`main` check for the owning source file and the dedicated lit test.

### What I checked directly

- current `main` `src/passes/HeapStoreOptimization.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/HeapStoreOptimization.cpp>
- current `main` `test/lit/passes/heap-store-optimization.wast`
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/heap-store-optimization.wast>

### Result

- `HeapStoreOptimization.cpp` on `main` is byte-for-byte identical to `version_129`
- the dedicated `heap-store-optimization.wast` test file on `main` is also identical to `version_129`

So the current durable freshness note is simple:

- unlike some other pass dossiers, I did **not** find post-`version_129` source drift here on `2026-04-20`
- `version_129` remains a strong current oracle for this pass

## Fast answer

Binaryen `heap-store-optimization` is **not** a general GC heap optimization pass.

A better beginner summary is:

- look for a `struct.set` that writes into a freshly created struct,
- check whether the value being stored can be moved earlier safely,
- if yes, fold that value into the relevant `struct.new` field,
- and delete or nop the now-redundant `struct.set`.

That can happen in two main surface shapes:

1. immediate tee form
   - `(struct.set (local.tee $x (struct.new ...)) VALUE)`
2. subsequent local-set form
   - `(local.set $x (struct.new ...))`
   - later `(struct.set (local.get $x) VALUE)`

Everything else in the pass is about proving those two rewrites safe.

## Public name and scheduler placement

## Registered public surface

`pass.cpp` registers:

- `heap-store-optimization`
  - description: `optimize heap (GC) stores`

The current upstream changelog still records this pass as a relatively new addition in Binaryen terms:

- `v119`: `Add a new --heap-store-optimization pass. (#6882)`

## Canonical no-DWARF placement

In `version_129` `pass.cpp`, Binaryen inserts `heap-store-optimization` twice in the default function pipeline, both under `wasm->features.hasGC()`:

1. early, right after `optimize-instructions`
2. late, right after the late `optimize-instructions`

That means it sits in the cleanup clusters:

- early `... -> optimize-instructions -> heap-store-optimization -> pick-load-signs -> precompute ...`
- late `... -> precompute(-propagate) -> optimize-instructions -> heap-store-optimization -> rse -> vacuum`

This exactly matches the repo's canonical no-DWARF path page.

## Saved generated-artifact `-O4z` evidence

The saved ordered `-O4z` audit records the same top-level slots:

- Binaryen slot `17`: `heap-store-optimization`
- Binaryen slot `45`: `heap-store-optimization`

The saved audit summary shows both those slot replays were green on the generated artifact:

- `wasmEqual = true`
- `normalizedWatEqual = true`
- `normalizedWatTextEqual = true`

The same summary also says `starshinePassSkippedRaw = true` for both slots, so that evidence is best read as:

- the current Starshine fast-skip path preserved exact artifact behavior there

not as:

- proof that every Binaryen rewrite family is already fully mirrored.

The saved Binaryen debug log shows the pass is also part of many nested cleanup reruns:

- direct count of `running pass: heap-store-optimization` lines: `36`

So the pass matters more than the two visible top-level slots might suggest.

## Actual implementation structure

## 1. Binaryen builds a CFG, then only records a tiny action set

The pass is not a generic AST sweep.

It is declared as:

- `WalkerPass<CFGWalker<HeapStoreOptimization, Visitor<...>, Info>>`

and each basic block stores only:

- `StructSet*` locations
- `Block*` locations

That is the first big scope clue.

The pass is **not** scanning every heap operation looking for broad alias opportunities.
It records just enough to reason about:

- direct `struct.set`
- block-local sequences that might hide a nearby `struct.new`

It also declares:

- `isFunctionParallel() = true`
- `requiresNonNullableLocalFixups() = false`

So it runs per function, and it does not change local types.

## 2. Immediate tee-wrapped rewrite

`optimizeStructSet(...)` handles the simplest and most famous form:

```wat
(struct.set
  (local.tee $x
    (struct.new ...))
  VALUE)
```

If the `ref` is a `LocalSet` used as a tee and its value is a `StructNew`, the pass calls `optimizeSubsequentStructSet(...)` on that pair.

On success:

- the `struct.set` disappears
- the tee is downgraded to a plain `local.set`

So the rewritten result becomes conceptually:

```wat
(local.set $x
  (struct.new ...VALUE...))
```

## 3. Block-local scan for later `struct.set`s

`optimizeBlock(...)` handles the second major family:

```wat
(local.set $x
  (struct.new ...))
(struct.set
  (local.get $x)
  VALUE)
```

It scans the `Block` list looking for:

- a `local.set` whose value is a `struct.new`
- followed by matching `struct.set`s on the same local

When a matching later `struct.set` optimizes successfully, Binaryen replaces that later set with `nop` and keeps scanning so it can absorb more stores into the same constructor.

That is why the shipped test file has chain cases like:

- `$optimize-chain`
- `$tee-and-subsequent`
- `$many-news`

## 4. `trySwap(...)` is the whole “push the constructor down” story

If the next instruction after a fresh `struct.new` is **not** a matching `struct.set`, Binaryen still has one more trick.

It tries to swap the `local.set(struct.new ...)` downward across the blocker so a later `struct.set` might become adjacent.

Important limits from the source:

- never swap with the last element in the list
  - there would be nothing left after it to optimize
- never swap across another `local.set` whose value is also a `struct.new`
  - avoids back-and-forth ping-pong
- only swap if the blocker's effects do not invalidate the constructor set's effects

This is a **simple local reorder**, not a whole-program motion engine.

## 5. `optimizeSubsequentStructSet(...)` is the real safety gate

This helper is the core of the pass.

It receives:

- the `StructNew*`
- the `StructSet*`
- the owning `LocalSet*`

and returns true only if every safety condition succeeds.

### a. Unreachable AST is left alone

The first bailout is:

- if the new or the set is already `unreachable`, do nothing

The source comment is explicit:

- leave unreachable code for DCE to avoid updating types here

So HSO is deliberately conservative around unreachable typing.

### b. The moved value must not depend on the target local

Binaryen computes `setValueEffects` and immediately refuses the rewrite if the value:

- reads the local holding the fresh struct
- writes that same local

This protects against cases where moving the stored value earlier would make it observe different local state.

### c. The moved value must commute past later struct operands

If the constructor is not a `with_default` form, then moving `VALUE` into field `index` also means moving it earlier than all later constructor operands.

So Binaryen checks every later operand with:

- `operandEffects.invalidates(setValueEffects)`

If any later field conflicts, optimization stops.

This is why upstream's test file distinguishes:

- `$side-effect-conflict`
- `$side-effect-ok`

### d. The moved value must also commute past a descriptor operand

If the allocation has a descriptor operand (`new_->desc`), Binaryen checks that too.

This is easy to miss because the public examples mostly show plain `struct.new`, but the source clearly handles the optional descriptor edge.

### e. The constructor itself may have shallow effects

Binaryen also runs `ShallowEffectAnalyzer` on the `struct.new` node itself.

Why only shallow effects?

- children are handled separately
- the pass now needs to know whether the allocation wrapper itself has effects, like descriptor-related behavior or trap timing

If the constructor's shallow effects invalidate the moved value, the rewrite is rejected.

That is the source-level reason the pass is careful about allocation trap timing.

### f. Control flow in the moved value may be dangerous

This is the hardest non-obvious check.

If the moved value can transfer control flow, the pass asks whether moving it earlier might let that control flow skip the `local.set` entirely.

That is exactly what `canSkipLocalSet(...)` is about.

### g. `with_default` constructors can be expanded

If the constructor uses `with_default`, Binaryen materializes explicit default field values before replacing the chosen field.

The source comment is honest:

- this can increase code size in some cases
- but the optimization is generally considered worthwhile

This is important for future ports: the pass values the structural cleanup enough to accept local size growth in that case.

### h. Old field side effects are preserved when necessary

If the old constructor field expression has unremovable side effects, Binaryen does **not** just drop it.

Instead it rewrites the field to a sequence like:

```wat
(block (result T)
  (drop OLD)
  NEW)
```

So the pass preserves old side effects while still making the final stored value come from `NEW`.

That is one of the best examples of what this pass actually is:

- not merely a constructor literal patch
- a semantics-preserving constructor rewrite

## 6. `canSkipLocalSet(...)` uses `LazyLocalGraph` only when needed

The pass only consults local-flow analysis when the value can transfer control flow.

Fast path:

- if `setValueEffects.transfersControlFlow()` is false, no control-flow-specific problem exists

Slow path:

- lazily build `LazyLocalGraph`
- call `canMoveSet(localSet, set)`

The `local-graph.h` comment matters here:

- `canMoveSet` assumes the new position is dominated by the old one, i.e. the set is being moved **forward**

That matches HSO exactly.

### The crucial subtle rule

If the graph says the moved set would influence no problematic gets, the rewrite is safe.

If it reports exactly one problematic get and that get is the `local.get` in the `struct.set`'s own `ref`, that is also safe, because the optimization deletes that get anyway.

But if there are multiple problematic gets, or the bad get is some other use, the rewrite is rejected.

That is the source reason the pass can accept:

- some internal control flow

while still rejecting:

- control flow that can bypass the `local.set` and later expose the wrong ref value

## 7. Function-external exits are mostly ignored on purpose

The pass sets:

- `ignoreBranchesOutsideOfFunc = true`

The comment is important.

Binaryen is only reasoning about local state **inside the function** for this pass.
So exits that leave the function entirely are generally safe for the current optimization goal.

That explains a subtle but important test split:

- a `return` in the moved value can still be safe
- a call that may throw *out of the function* can still be safe
- but a call that may throw to a `try` / `try_table` catch **inside the function** is not safe
- and a branch to an outer in-function block or loop can also be unsafe

## What the pass explicitly does not do

This is the most important beginner correction.

By direct source inspection, Binaryen `version_129` HSO does **not** currently do:

- generic dead store elimination
- load forwarding
- `array.set` optimization
- `memory.store` optimization
- `table.set` optimization
- whole-function alias analysis for arbitrary heap traffic

The file states that itself in the opening TODO.

And the visitor surface confirms it:

- it visits `StructSet`
- it visits `Block`
- nothing else is an action root

So the pass name is broader than the current implementation.

## Important WAT / IR shapes from the shipped tests

## Positive shapes

### Immediate tee fold

```wat
(struct.set
  (local.tee $x
    (struct.new $S ...))
  VALUE)
```

=> fold `VALUE` into the constructor and keep a plain `local.set`

### Subsequent local-set fold

```wat
(local.set $x
  (struct.new $S ...))
(struct.set $S FIELD
  (local.get $x)
  VALUE)
```

=> fold into the original constructor, later set becomes `nop`

### Chain of later sets

Several later `struct.set`s on the same local can be absorbed one by one until a blocker appears.

### `struct.new_default`

The pass can expand default fields and then absorb the later store.

### Safe internal control flow

Control flow inside the moved value can still be fine if it does not create a path that skips the needed `local.set` and then reaches an observable later local use.

Representative safe shapes from the test file:

- internal `if` that stays inside the moved subtree
- loop contained inside the moved value
- `return` that exits the function entirely
- call that may throw only outside the function

## Negative / bailout shapes

### Wrong local or wrong pattern

If the later `struct.set` uses another local, or if the adjacency pattern never lines up, nothing happens.

### Later-field effect conflict

If moving the new value earlier would cross conflicting effects from later constructor operands or the descriptor operand, the rewrite is rejected.

### Target-local read/write in moved value

If the moved value reads or writes the local holding the fresh struct ref, the rewrite is rejected.

### Unsafe in-function control flow

Representative bad shapes from the shipped tests:

- branch to an outer block while later code in the function reads the local
- call whose throw can be caught in a `try_table` inside the function
- loop backedge cases where an earlier local use may observe different state
- `if`-arm-localized rewrite where later code outside the arm can still read the ref

### Unreachable constructor or set

The pass leaves these alone for DCE rather than trying to repair types locally.

### Swap limits

The pass deliberately avoids swapping:

- with the last item in a block list
- across another `local.set(struct.new ...)`

## Starshine comparison: current repo state

By source inspection, current Starshine follows the same *core* optimization idea but is not a literal port of `HeapStoreOptimization.cpp`.

### What looks aligned

- same fundamental purpose: fold `struct.set` into nearby constructor creation
- same broad early/late scheduler placement in `src/passes/optimize.mbt`
- same focus on effect ordering and control-flow safety
- preserved artifact replay on the saved top-level `-O4z` slots `17` and `45`

### What is structurally different locally

- Starshine works on HOT regions, not a Binaryen CFGWalker over AST basic blocks
- Starshine includes explicit descriptor and default-descriptor constructor coverage in-tree
- Starshine has broader reduced tests for pure/read-only prefix peeling, nested wrappers, and writeback-preserving reshaping
- Starshine's artifact audit shows the debug artifact commonly fast-skips this pass rather than exercising the full rewrite surface there

So the durable comparison is:

- upstream Binaryen `version_129` gives the semantic oracle for the *core constructor-folding contract*
- current Starshine already implements a HOT-oriented generalization of that idea, but the shapes and helper structure are not identical enough to treat the local code as the reference for upstream behavior

## Main beginner-facing corrections

1. `heap-store-optimization` does **not** currently mean generic GC dead-store elimination.
2. The pass's real scope in `version_129` is mostly `struct.set` + nearby `struct.new` folding.
3. The hardest part of the implementation is not constructor rewriting itself; it is proving that moving the stored value earlier does not reorder effects or let control flow skip the `local.set`.
4. Function-external exits are usually safe for this pass's current goal; in-function exits and catches are the dangerous ones.
5. `struct.new_default` materialization can intentionally increase code size.
6. A future Starshine port or refactor must preserve old field side effects when replacing a constructor operand.

## Future-port invariants worth preserving

If Starshine ever rewrites or re-ports this pass again, the Binaryen-backed invariants to preserve are:

- keep the scope narrow unless a new alias analysis is introduced explicitly
- only fold when the stored value can move earlier safely with respect to:
  - the target local
  - later constructor operands
  - the optional descriptor operand
  - the constructor's own shallow effects
  - control flow that could skip the moved `local.set`
- keep `with_default` materialization explicit
- preserve old field side effects with a drop/sequence wrapper when needed
- keep the function-external-vs-internal control-flow distinction honest
- do not silently broaden the pass to arrays, memory stores, or load forwarding just because the name sounds broad enough

## Open questions / honest uncertainty

- The current upstream file clearly reasons about an optional `desc` operand on `StructNew`, but the dedicated shipped HSO lit test is still mostly centered on plain/default constructor spellings. I am treating descriptor participation as **source-backed** rather than as something separately proven by a broad official test matrix.
- I did not find a dedicated upstream release-note discussion beyond the changelog line that introduced the pass in `v119`.
- `agent-todo.md` currently has no dedicated `HSO` slice, so the local planning surface is inferred from shared hot-prefix references and the existing test corpus rather than from a pass-owned backlog section.

## Recommended living wiki pages from this note

- landing page rewrite at `docs/wiki/binaryen/passes/heap-store-optimization/index.md`
- `binaryen-strategy.md`
- `swap-safety-and-control-flow.md`
- `wat-shapes.md`
- `starshine-hot-ir-strategy.md`
