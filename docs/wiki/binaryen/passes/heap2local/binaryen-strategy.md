---
kind: concept
status: supported
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0135-2026-04-20-heap2local-binaryen-research.md
related:
  - ./index.md
  - ./validation-fixups-and-special-cases.md
  - ./wat-shapes.md
  - ./parity.md
  - ./starshine-hot-ir-strategy.md
  - ../../no-dwarf-default-optimize-path.md
---

# Binaryen `heap2local` strategy

## Upstream source rule

Use Binaryen `version_129` as the primary source oracle for this pass.

Primary files:

- `src/passes/Heap2Local.cpp`
- `src/passes/pass.cpp`
- `src/passes/opt-utils.h`
- `src/pass.h`
- `src/ir/type-updating.h`

Most important helper dependencies visible in the source:

- `src/ir/local-graph.h`
- `src/ir/parents.h`
- `src/ir/branch-utils.h`
- `src/ir/eh-utils.h`
- `src/ir/bits.h`
- `src/ir/properties.h`
- `src/wasm-builder.h`

The shipped dedicated lit surface is also part of the contract:

- `test/lit/passes/heap2local.wast`

## High-level intent

Binaryen uses `heap2local` to remove some GC allocations entirely.
But it only does that when it can prove two things:

1. the allocation never escapes the current function
2. every reachable use is exclusive to that exact allocation

If those proofs succeed, Binaryen turns the object's data into locals.
If those proofs fail, it gives up.

That conservative contract is the real meaning of the pass.

## Where the pass runs

`pass.cpp` registers:

- `heap2local`
  - description: `replace GC allocations with locals`

In the default no-DWARF function pipeline, Binaryen inserts it in the mid-function GC/local cleanup cluster:

- `... -> remove-unused-brs -> heap2local -> optimize-casts -> local-subtyping -> coalesce-locals -> local-cse -> simplify-locals -> ...`

That placement is meaningful.

- the earlier cleanup passes reduce obvious junk first
- `heap2local` then exposes scalar local traffic
- the later GC/local passes can exploit that newly scalarized traffic

At higher optimize/shrink levels, `merge-locals` may also appear immediately after `heap2local` and before `optimize-casts`.

## Nested reruns matter

The helper in `opt-utils.h` named `optimizeAfterInlining(...)` reuses the default function optimization stack after inlining-related rewrites.
That means `heap2local` can run again inside later optimizing reruns.

The local saved `-O4z` debug log confirms that practical story:

- the saved run contains `18` `heap2local` executions in total

So a future scheduler model must not treat this pass as “one top-level slot only.”

## Phase 0: per-function reusable analysis state

The `Heap2Local` helper struct owns the reusable per-function state:

- `LazyLocalGraph localGraph`
- `ScratchInfo scratchInfo`
- `Parents parents`
- `BranchUtils::BranchTargets branchTargets`

Those are built once per function and then reused across many candidate analyses.
That is important because `heap2local` may inspect multiple allocations in the same function.

The file also runs an `AllocationFinder` walker first to collect:

- reachable `StructNew`
- reachable `ArrayNew`
- reachable `ArrayNewFixed`
- whether the function contains any `pop`

The pass then processes:

1. arrays first
2. structs second
3. EH nested-pop fixup afterward if needed

## Phase 1: `EscapeAnalyzer` proves the candidate is safe

This is the real semantic gate.

The critical enum is `ParentChildInteraction`:

- `Escapes`
- `FullyConsumes`
- `Flows`
- `Mixes`
- `None`

That enum answers the question:

- what happens when the optimized allocation reaches this parent expression?

Examples from the source logic:

- **Escapes**
  - no parent (the allocation becomes the function body result)
  - calls / other unhandled outward uses
- **FullyConsumes**
  - `drop`
  - `struct.get`
  - `struct.set` when the allocation is the `ref`
  - `ref.is_null`
  - `ref.eq`
  - `ref.test`
  - `ref.get_desc`
- **Flows**
  - `block` and `loop` when the allocation is the sole value flowing onward
  - some branch-to-block cases where the branch is the only sent value and there is no competing fallthrough value
- **Mixes**
  - if/else-like value mixing
  - block/branch families where some other value may reach the same result position

The analyzer runs a queue of `(child, parent)` flows.
It starts from the allocation and keeps following:

- the parent chain via `Parents`
- local-set/local-get flow via `LazyLocalGraph`
- branch-sent values via `BranchUtils`

If the walk ever encounters `Escapes` or `Mixes`, the candidate is rejected.

## Phase 1b: exclusivity is a separate proof from non-escape

Even if the allocation never escapes, Binaryen still insists that every use be exclusive.
This is the `getsAreExclusiveToSets()` check.

The idea is:

- collect all relevant sets of the allocation
- collect every get influenced by those sets
- reject the candidate if any such get might also read from some other set family

This is what rules out mixed local provenance such as:

- parameter/local mixtures
- ambiguous loop-carried ownership
- `select` / if-else merge traffic

That is one of the most important beginner-facing corrections in the entire pass.

## Phase 2: arrays are lowered to synthetic structs first

This is one of the pass's easiest-to-miss design choices.
Binaryen does **not** directly scalarize arrays the same way it scalarizes structs.

Instead it first runs `Array2Struct` on eligible arrays.

### Array eligibility

From `AllocationFinder` and related helpers, the important rules are:

- allocation must be `ArrayNew`, `ArrayNewDefault`, or `ArrayNewFixed`
- size must be constant
- size must be `< 20`
- the array must be reachable (not already `unreachable`)
- later indexed accesses must be analyzable in the relevant cases

The size cap is deliberate.
The source comment explains that Binaryen wants to be conservative when replacing a heap allocation with a stack/local expansion, and valid wasm can contain huge array sizes that would be unreasonable to scalarize.

### What `Array2Struct` does

`Array2Struct`:

- builds a synthetic struct type with one field per array slot
- preserves sharedness
- rewrites the array allocation into a `StructNew`
- rewrites array uses into struct uses where possible
- updates reached flowing ref types so later passes see the synthetic struct shape consistently
- then hands the new `StructNew` to `Struct2Local`

This is why the pass can reuse almost all of the harder scalarization logic in one place.

## Phase 3: `Struct2Local` performs the scalarization

Once the allocation is known safe, `Struct2Local` does the actual rewrite.

### Local creation

It allocates:

- one fresh local per struct field
- one extra local for the descriptor if the allocation has one
- scratch locals for initializer ordering when needed

### Why scratch locals matter

The source comment is explicit here.
If you are allocating inside a loop, later initializer expressions might depend on old field values.
So Binaryen first computes nontrivial initializer expressions into temporary locals, then copies them into the canonical field locals.

That avoids accidentally letting a later initializer read the already-updated value of an earlier field.

### Placeholder `ref.null` values are intentional

When the allocation itself disappears, Binaryen often replaces it with `ref.null` rather than erasing it outright.
That lets surrounding expressions keep a valid shape while later rewrites remove or widen the remaining ref traffic.

Beginner lesson:

- the pass is not trying to emit the final prettiest tree immediately
- it is trying to emit a valid transitional tree that later cleanup can simplify further

## Phase 4: direct ref operation folding is part of the pass

`Struct2Local` handles more than just `struct.get` and `struct.set`.

It also uses exact knowledge of the allocation to simplify:

- `ref.is_null`
  - result is known statically
- `ref.eq`
  - compare-to-self is `1`; compare-to-anything-else is `0` because the allocation never escapes
- `ref.as_non_null`
  - safe to remove because the optimized allocation is known non-null
- `ref.test`
  - outcome is known from subtype relations
- `ref.cast`
  - either disappears or becomes explicit `unreachable`
- `ref.get_desc`
  - replaced by the saved descriptor local
- descriptor-based cast families
  - source-visible even when the dedicated lit file does not visibly cover all of them

This is one of the biggest reasons the pass is more than a simple field-localization transform.

## Phase 5: packed, atomic, and RMW families are handled specially

### Packed field gets

When a struct or synthetic-struct field is packed, Binaryen reconstructs the right signed/unsigned semantics using `Bits::makePackedFieldGet(...)`.
So scalarization still preserves the original field behavior.

### Atomic / RMW / cmpxchg families

The source also handles:

- `struct.atomic.get`
- `struct.atomic.set`
- `struct.rmw`
- `struct.cmpxchg`
- array atomic and cmpxchg variants through the array->struct pathway and dedicated special handling

The key source insight is:

- if the object never escapes, these operations cannot synchronize with other threads through that object identity

So the pass can lower them to local traffic while preserving the observable result behavior.

This is a non-obvious part of the pass contract and very easy to miss if you only look at small summary pages.

## Phase 6: validation repair is mandatory

The pass has several repair layers.

### In-pass `ReFinalize`

Both `Struct2Local` and `Array2Struct` may set `refinalize = true` and call `ReFinalize()` after their walk.
That is needed when the rewrite changes:

- nullability
- flowing ref type precision
- cast shapes
- OOB array accesses into `unreachable`

### EH nested-pop fixup

After all candidate processing, `Heap2Local` checks:

- did the function contain `pop`?
- did anything get optimized?

If both are true, it runs:

- `EHUtils::handleBlockNestedPops(func, wasm)`

That is part of the real pass boundary.

### Generic nondefaultable-local fixup from the pass framework

This is the easiest part to overlook.
`Heap2LocalPass` does not override `requiresNonNullableLocalFixups()`, and `Pass::requiresNonNullableLocalFixups()` defaults to `true` in `pass.h`.

That means after the pass modifies Binaryen IR, `PassRunner::handleAfterEffects(...)` automatically runs:

- `TypeUpdating::handleNonDefaultableLocals(func, wasm)`

So nondefaultable-local repair is part of the actual Binaryen contract even though it lives outside `Heap2Local.cpp` itself.

## Why the pass is single-iteration

The file comment near `Heap2LocalPass::doWalkFunction(...)` makes the design tradeoff explicit.

In theory, after optimizing one allocation into locals, references written into those locals might become newly visible nonescaping allocations too.
But the pass does not iterate to a fixpoint in one invocation.

Why not?

- it does not fully remove the old detached allocation tree by itself
- it depends on other cleanup, especially `vacuum`, to erase the dead remnants first
- then a later rerun of `heap2local` can see the newly exposed candidate cleanly

That is why nested reruns and neighbor passes matter so much here.

## What a future port must preserve

A future Starshine port or refactor must keep these Binaryen-backed rules honest:

- proving **non-escape** is not enough; prove **exclusivity** too
- arrays are only optimized in a small fixed-size, constant-index, struct-like subset
- the upstream algorithm really does arrays first, then structs
- placeholder `ref.null` values are intentional validation-preserving scaffolding
- direct ref operations (`ref.eq`, `ref.test`, `ref.cast`, etc.) are part of the real pass surface
- packed access semantics must survive scalarization
- atomic/RMW/cmpxchg corner cases are part of the contract, even if a first local port omits some of them
- `ReFinalize`, EH pop fixups, and nondefaultable-local repair are real pass-boundary work, not optional cleanup
- single-iteration behavior is intentional and depends on later passes and reruns

## Current freshness note

A narrow 2026-04-20 check found small but real source drift on current `main` around:

- array interaction precision
- `array.cmpxchg` / `struct.cmpxchg` handling
- unreachable `ref.test`

The dedicated lit surface still only shows a typo fix there, so `version_129` remains the best released oracle for this dossier.
