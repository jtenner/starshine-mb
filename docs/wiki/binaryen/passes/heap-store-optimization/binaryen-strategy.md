---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-heap-store-optimization-current-main-code-map.md
  - ../../../raw/binaryen/2026-04-22-heap-store-optimization-primary-sources.md
  - ../../../raw/research/0356-2026-04-25-heap-store-optimization-current-main-code-map.md
  - ../../../raw/research/0133-2026-04-20-heap-store-optimization-binaryen-research.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./swap-safety-and-control-flow.md
  - ./wat-shapes.md
  - ./starshine-hot-ir-strategy.md
  - ../../no-dwarf-default-optimize-path.md
---

# Binaryen `heap-store-optimization` strategy

## Upstream source rule

Use Binaryen `version_129` as the current source oracle for this pass.

Primary files:

- `src/passes/HeapStoreOptimization.cpp`
- `src/passes/pass.cpp`

Most important helper dependencies:

- `src/cfg/cfg-traversal.h`
- `src/ir/effects.h`
- `src/ir/local-graph.h`

The shipped dedicated lit test is also part of the contract here:

- `test/lit/passes/heap-store-optimization.wast`

For owner-file and proof-surface details, see [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md).

## High-level intent

Binaryen uses `heap-store-optimization` to clean up one very specific GC pattern:

- a `struct.set` that writes into a struct that was just created

The point is to change this:

```wat
(local.set $x
  (struct.new $S ...OLD...))
(struct.set $S FIELD
  (local.get $x)
  NEW)
```

into this:

```wat
(local.set $x
  (struct.new $S ...NEW...))
(nop)
```

or, in the tee form, into a plain `local.set` that already contains the updated constructor.

So the real strategy is:

- **fold later field stores into a fresh constructor, but only after proving value movement and local visibility stay safe**

## Where the pass runs

`pass.cpp` registers:

- `heap-store-optimization`
  - description: `optimize heap (GC) stores`

In the default no-DWARF function pipeline, Binaryen inserts it twice, both under `wasm->features.hasGC()`:

1. early after `optimize-instructions`
2. late after the late `optimize-instructions`

That gives the two top-level cleanup neighborhoods:

- `optimize-instructions -> heap-store-optimization -> pick-load-signs -> precompute(-propagate)`
- `precompute(-propagate) -> optimize-instructions -> heap-store-optimization -> rse -> vacuum`

The saved generated-artifact `-O4z` audit observed those same top-level slots at `17` and `45`, while the debug log shows `36` total executions because nested reruns also include the pass.

## The biggest beginner correction

Despite the name, this pass is **not** a generic heap optimizer.

The strongest evidence is right at the top of the file:

- `TODO: Add dead store elimination / load forwarding here.`

And the visitor surface matches that narrow scope.
It only records action sites for:

- `StructSet`
- `Block`

Not:

- `ArraySet`
- `Store`
- `TableSet`
- generic reads or writes

So what the pass calls “heap store optimization” in `version_129` is really:

- **struct-constructor store folding**

## Phase 1: build a CFG and record only relevant action sites

The pass is declared as:

- `WalkerPass<CFGWalker<HeapStoreOptimization, Visitor<...>, Info>>`

Important immediate consequences:

- it is function-parallel
- it uses CFG basic blocks as the unit of local reasoning
- it can attach custom action lists to each basic block via `Info { actions }`

During traversal it stores only pointers to:

- `StructSet*`
- `Block*`

That is a deliberate design choice.
The pass is not trying to optimize arbitrary heap operations everywhere.
It is preparing just enough metadata to revisit:

- immediate constructor/store sites
- block-local lists that may hide constructor/store chains

## Phase 2: optimize the immediate tee-wrapped form

`optimizeStructSet(...)` handles the direct pattern:

```wat
(struct.set $S FIELD
  (local.tee $x
    (struct.new $S ...))
  VALUE)
```

If the `ref` is a `LocalSet` used as a tee and the tee value is a `StructNew`, the pass calls `optimizeSubsequentStructSet(...)`.

On success it does two small but important rewrites:

- the field value is folded into the `struct.new`
- the tee is converted to a plain `local.set`

So the original `struct.set` node disappears entirely.

## Phase 3: optimize block-local subsequent sets

`optimizeBlock(...)` handles the second main family:

```wat
(local.set $x
  (struct.new $S ...))
(struct.set $S FIELD
  (local.get $x)
  VALUE)
```

The algorithm is intentionally simple:

1. scan block roots looking for `local.set` of `struct.new`
2. look forward for later `struct.set`s on the same local
3. when one optimizes successfully, replace that later set with `nop`
4. keep scanning so more later stores can also fold into the same constructor

This is why the test file has chain cases like:

- `$optimize-chain`
- `$tee-and-subsequent`
- `$many-news`

## Phase 4: `trySwap(...)` pushes the fresh constructor closer to a later store

If the next instruction after the `local.set(struct.new ...)` is not a matching `struct.set`, Binaryen still tries one local motion trick.

It swaps the `local.set(struct.new ...)` downward across a blocker if that is safe, so that a later matching `struct.set` may become adjacent.

Important source-level limits:

- do not swap with the last element in the list
  - there would be nothing after it to optimize
- do not swap across another `local.set` of `struct.new`
  - avoids constructor ping-pong
- only swap when the blocker's effects do not invalidate the constructor set's effects

This is a very local reordering rule.
It is not trying to be a whole-program motion pass.

## Phase 5: `optimizeSubsequentStructSet(...)` does the real proof work

This helper is the heart of the pass.

It only succeeds if every safety condition below passes.

### 1. Reject unreachable constructor/set pairs

If either the `struct.new` or the `struct.set` is already `unreachable`, the pass refuses the optimization.

The source comment explains why:

- leave unreachable code for DCE, to avoid updating types here

That means HSO intentionally leaves some obvious cleanup for later passes.

### 2. Reject values that touch the target local

Binaryen computes `setValueEffects` for the moved value and rejects it if the value:

- reads the ref local
- writes the ref local

This protects against the classic reordering hazard where moving the value earlier would make it see different local state.

### 3. Reject reordering conflicts with later constructor operands

If the constructor is not a `with_default` form, moving the stored value into field `index` also means moving it before all later constructor operands.

So for each later operand, Binaryen checks:

- `operandEffects.invalidates(setValueEffects)`

If any later field conflicts, optimization stops.

That is the core reason some multi-field cases fold and others do not.

### 4. Reject conflicts with the descriptor operand

If `StructNew` has an optional descriptor operand, Binaryen checks that too.

That matters because the constructor wrapper may carry extra effect ordering constraints beyond the ordinary field operands.

### 5. Reject conflicts with the constructor's own shallow effects

Binaryen runs `ShallowEffectAnalyzer` on the `struct.new` itself.

Why shallow?

- children were already checked separately
- now the pass needs to know whether the constructor wrapper itself has effects whose order relative to the moved value matters

This is the source-level reason the pass is careful about allocation trap timing.

### 6. Reject dangerous control flow with `canSkipLocalSet(...)`

This is the most non-obvious part of the pass.

If the moved value can transfer control flow, Binaryen asks:

- if I move this value into the constructor, can that control flow skip the `local.set` that made the fresh ref visible?

If yes, the rewrite is rejected.

### 7. Expand `with_default` constructors when needed

If the constructor uses `with_default`, Binaryen materializes explicit zero/null defaults for all fields and then patches the chosen field.

The source comment is very honest:

- this can increase code size in some cases
- but the optimization is usually still worth it

That is part of the real contract.

### 8. Preserve old field side effects when replacing a field

If the old field expression has unremovable side effects, Binaryen does not simply erase it.

Instead it rewrites the field to a sequence equivalent to:

```wat
(block (result T)
  (drop OLD)
  NEW)
```

So the old field's side effects still happen, but the final field value comes from `NEW`.

That is the clearest proof that this pass is semantics-aware, not just syntax-aware.

## Phase 6: `LazyLocalGraph` is used only on the hard control-flow cases

`canSkipLocalSet(...)` has a very important fast path.

If the moved value does **not** transfer control flow, the pass does not need LocalGraph reasoning at all.

Only when control flow is present does Binaryen:

- lazily construct `LazyLocalGraph`
- call `canMoveSet(localSet, set)`

The `local-graph.h` comments matter here:

- `canMoveSet` assumes the set is being moved **forward** into a dominated position

That is exactly HSO's use case.

### The subtle rule about “bad gets”

If `canMoveSet(...)` reports:

- no bad gets: safe
- exactly one bad get, and it is the `struct.set`'s own `ref`: still safe, because that get disappears in the optimization
- more than one bad get, or some other bad get: unsafe

That is why some branchy values are accepted while others are rejected.

## Important nuance: exits outside the function are mostly safe

The pass sets:

- `ignoreBranchesOutsideOfFunc = true`

That is a strong design statement.

HSO is only protecting local-state observations **inside the current function**.
So exits that leave the function entirely are usually acceptable for the current optimization goal.

That explains a few otherwise surprising test results:

- a `return` inside the moved value can still be safe
- a call that may throw out of the function can still be safe
- but a call that may throw to an in-function `try` or `try_table` catch is unsafe
- and a branch to an outer block or loop that leaves later in-function local uses reachable is unsafe

## Pass interactions that are easy to miss

## `remove-unused-names` can unlock HSO reasoning

The dedicated upstream lit test runs:

- `--remove-unused-names`
- then `--heap-store-optimization`

The test comment explains why:

- once unused block names are removed, the optimizer can see those blocks as having no nonlinear control flow

So the practical rule is:

- HSO's profitability and safety surface is slightly better after useless labels are gone

## Later cleanup passes are expected to erase residue

In block-local chains, Binaryen replaces optimized later `struct.set`s with:

- `nop`

not immediate structural deletion.

So later cleanup passes like `vacuum` and related neighbors are expected to tidy that residue.

That is normal pass-pipeline cooperation here, not an unfinished optimization.

## What a future port must preserve

A future Starshine rewrite or refactor must keep these Binaryen-backed invariants honest:

- do not silently broaden the pass from `struct.set` folding to generic heap DSE/load forwarding
- keep the effect-order checks against:
  - later constructor operands
  - descriptor operands
  - the constructor's own shallow effects
- keep the target-local read/write bailout
- keep the `LazyLocalGraph` control-flow safety gate
- keep the distinction between exits outside the function and dangerous in-function exits
- keep default materialization explicit for `with_default`
- preserve old field side effects when overwriting the constructor operand

## Current freshness note

A 2026-04-25 focused current-main source bridge found no teaching-relevant drift from the `version_129` contract:

- `main` still keeps the generic heap dead-store / load-forwarding work as a TODO;
- `main` still records only `StructSet` and `Block` action sites;
- immediate tee folds and later local-set chains remain the central positive families;
- `trySwap(...)` remains a narrow local motion helper;
- `LazyLocalGraph::canMoveSet(...)` remains the hard control-flow safety proof for moved values.

So unlike some other pass dossiers, there is still no current-trunk contract drift to document here yet. The recheck is captured in [`../../../raw/binaryen/2026-04-25-heap-store-optimization-current-main-code-map.md`](../../../raw/binaryen/2026-04-25-heap-store-optimization-current-main-code-map.md).
