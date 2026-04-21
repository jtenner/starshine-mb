---
kind: concept
status: supported
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0116-2026-04-20-local-subtyping-binaryen-research.md
related:
  - ./index.md
  - ./lubs-and-dominance.md
  - ./wat-shapes.md
  - ../optimize-casts/index.md
  - ../tracker.md
---

# Binaryen `local-subtyping` Strategy

## Upstream source rule

- Use Binaryen `version_129` as the current source oracle for this pass.
- The core implementation is `src/passes/LocalSubtyping.cpp`.
- Scheduler placement comes from `src/passes/pass.cpp` and the after-inlining helper in `src/passes/opt-utils.h`.
- The key helper contracts come from:
  - `src/ir/lubs.h`
  - `src/ir/type-updating.h`
  - `src/ir/local-structural-dominance.h`
- The shipped behavior examples come from `test/lit/passes/local-subtyping.wast`.

Primary source URLs:

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LocalSubtyping.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/lubs.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-structural-dominance.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/local-subtyping.wast>

## High-level intent

Binaryen uses `local-subtyping` to make eligible local declarations more specific when the actual local traffic is already more specific than the declaration.

That sentence is true but incomplete.

The actual implementation is deliberately narrow.

It is not:

- generic local type inference
- generic cast propagation
- generic branch-based type refinement
- parameter narrowing
- tuple-local narrowing
- a large CFG dataflow pass

Instead, the real `version_129` contract is:

- look only at non-parameter locals
- gather concrete subtype demands from a tiny set of syntactic sites
- compute one least upper bound per local
- let the type-updating helper decide how to apply that change safely
- refinalize after mutation

## The pass in one table

| Phase | What Binaryen does | Why it exists |
| --- | --- | --- |
| GC-gated scheduling | Run the pass only in the GC local-cleanup cluster | This pass is about reference subtyping, not general numeric locals |
| Seed local facts | Create one `LUBFinder` per local and seed non-param locals with their current type | Keep the current declaration as the baseline and avoid inventing types from nothing |
| Collect observed types | Visit `local.get`, `local.set` / `local.tee`, and `ref.as_non_null(local.get)` | Learn which narrower local types the function already uses concretely |
| Compute one LUB | Ask each `LUBFinder` for one common safe type | Narrow conservatively across all observed facts |
| Check helper support | Require `TypeUpdating::canHandleAsLocal(...)` for both old and new types | Avoid unsupported locals such as tuples |
| Rewrite through helper | Call `LocalUpdater(...).changeType(...)` with structural dominance | Apply the type change safely, even when a copy local is needed |
| Repair | Run `ReFinalize` | Restore correct outer expression types after mutation |

## Phase 1: scheduler placement and gating

In `pass.cpp`, Binaryen places `local-subtyping` inside the GC-only local cleanup cluster.

The canonical no-DWARF neighborhood is:

- `heap2local`
- `optimize-casts`
- `local-subtyping`
- `coalesce-locals`
- `local-cse`
- `simplify-locals`

That placement is meaningful.

- `optimize-casts` may expose or create narrower local traffic.
- `local-subtyping` then tightens local declarations to match that traffic.
- `coalesce-locals` comes later because it can widen locals into a common supertype and erase opportunities.

`pass.cpp` says this explicitly: `LocalSubtyping` must run before `CoalesceLocals`, or coalescing can make local-subtyping miss opportunities.

That comment is part of the pass meaning, not just scheduler trivia.

## Phase 2: one `LUBFinder` per original local

At function entry, `LocalSubtyping.cpp` creates a `LUBFinder` for each original local index.

Then it seeds only the non-parameter locals with their current declared type.

That seed step matters because it means:

- every candidate narrowing starts from the actual current declaration
- if the pass learns nothing more specific, the declaration stays unchanged
- the computed answer is always compatible with the previous local type baseline

The pass also snapshots the original local count before mutation, so helper-added copy locals are rewrite artifacts, not new analysis targets inside the same run.

## Phase 3: parameters are intentionally out of scope

The source comment is unusually revealing here.

It says, in essence:

- optimize vars, not params
- TODO optimize params too
- but params need something like structural dominance
- and note that structural dominance is not true of named blocks

That is a major durable takeaway.

Binaryen is explicitly telling us that parameter narrowing is a harder problem than the current pass is willing to solve.

A faithful Starshine port should preserve that conservatism.

## Phase 4: only three visitor methods collect facts

This is the easiest place to overestimate the pass.

The implementation body is tiny, and only three visitor methods add subtype information.

### `visitLocalGet`

For non-parameter locals, Binaryen notes the local.get type when that type is concrete.

This means the pass can learn that some local users already operate on a narrower type than the declaration.

It also means non-concrete types, especially `unreachable`, do not widen the result.

### `visitLocalSet`

For non-parameter locals, Binaryen notes:

- the tee result type for `local.tee`
- otherwise the value type for `local.set`

This is a small detail with real meaning.

`local.tee` participates through the type later users observe at the tee itself, not only the right-hand-side expression.

### `visitRefAs`

The pass has one specialized refinement hook.

If it sees `ref.as_non_null(local.get $x)` on a non-parameter local, it records the non-null version of that heap type for `$x`.

That is the only direct ref-refinement instruction the pass handles itself.

This is the big “what the pass sounds like vs what it really does” correction.

The real `version_129` pass does **not** have direct logic for:

- `ref.cast`
- `br_on_null`
- `br_on_cast`
- `br_on_cast_fail`
- `ref.test`
- global or table traffic

So a future port should resist broadening the pass beyond those explicit source hooks until there is a deliberate reason to do so.

## Phase 5: narrowing uses a least upper bound, not the narrowest leaf type

After collection, Binaryen asks each `LUBFinder` for its `getLUB()`.

That means the pass is searching for:

- one type that satisfies all the observed subtype facts
- while still being as specific as possible

This is not the same as:

- picking the smallest leaf subtype that appeared anywhere
- picking the last type seen
- picking one branch-local subtype and hoping later cleanup handles the mismatch

A good beginner rule is:

- Binaryen narrows to the best **common** type, not the most aggressive individual type.

That explains why sibling subtype cases only narrow to a common parent, not to either sibling leaf.

## Phase 6: helper support decides whether a local can change at all

Before changing a local, `LocalSubtyping.cpp` checks both the current type and the candidate type with:

- `TypeUpdating::canHandleAsLocal(...)`

`type-updating.h` makes the important rule explicit:

- tuple types are not supported here

So even if a tuple local looked narrowable in theory, the pass intentionally declines it today.

That is an important contract for this repo's multivalue / tuple neighborhood.

## Phase 7: `LocalUpdater` does the dangerous work

If the current type and the computed LUB differ, Binaryen builds:

- `LocalStructuralDominance dominance(func, wasm);`
- then calls `TypeUpdating::LocalUpdater(func, wasm).changeType(i, lub, &dominance);`

That split is the heart of the pass.

`LocalSubtyping.cpp` does not try to edit every local use itself.
It hands the job to the dedicated helper that knows how to update a local type safely.

## Phase 8: structural dominance is part of the algorithm, not an implementation accident

`local-structural-dominance.h` explains the dominance model that the updater uses.

Important source-level facts:

- dominance is defined over Binaryen's structured tree
- unnamed blocks do not matter because branches cannot target them
- named blocks and loops do matter
- catch bodies are treated as separate nested CFGs in the default mode used here

This explains two otherwise odd-looking things:

1. the LocalSubtyping source comment warns about named blocks when discussing params
2. the shipped lit tests include `try_table`-flavored shapes

A port that treats rewrite safety as simple textual order will miss the real upstream contract.

## Phase 9: `LocalUpdater` may add a copy local

The comments in `type-updating.h` explain that changing a local type is not always a uniform one-local edit.

If some uses are safely dominated by assignments of the new type but other uses are not, Binaryen may:

- keep the old local
- add a new copy local of the requested type
- assign into that copy local where the narrower type is valid
- rewrite dominated users to the copy local

This is one of the biggest beginner surprises in the whole pass.

The pass is not just “rewrite the local declaration header.”
Sometimes it is a small structured refactoring around the helper-added copy local.

## Phase 10: `ReFinalize` is mandatory

After successful updates, Binaryen runs `ReFinalize().walkFunctionInModule(func, wasm);`.

That is necessary because the rewrite can change:

- local get/set/tee types
- reference nullability
- surrounding expression types
- outer node result types

A faithful Starshine port must preserve this refinalization step.

## Helper dependency map

## `LUBFinder`

- collects type constraints incrementally
- computes a least upper bound over the noted types
- makes the pass conservative across multiple subtype facts

## `TypeUpdating::canHandleAsLocal(...)`

- decides whether both the old and new local types are supported by the helper layer
- currently excludes tuple locals

## `TypeUpdating::LocalUpdater`

- performs the actual local type update
- may add a copy local when uniform mutation is unsafe
- needs dominance information to decide which uses can move to the new type

## `LocalStructuralDominance`

- defines the structured-control dominance relation the updater relies on
- makes named blocks, loops, and catches part of the safety story

## `ReFinalize`

- repairs result types after mutation

## `opt-utils.h`

- explains why the pass reappears in nested reruns after optimizing passes touch functions

## What the pass does **not** do

A future Starshine port should avoid accidentally broadening this pass beyond upstream behavior.

`local-subtyping` does **not**:

- narrow params in `version_129`
- handle tuple locals
- directly optimize `ref.cast` traffic
- directly inspect `br_on_cast*` or `ref.test`
- reason about globals or tables
- run as a whole-program or module pass
- skip the helper layer and mutate declarations blindly
- skip refinalization

The real Binaryen contract is smaller and more helper-driven than the CLI name suggests.

## Why the shipped test matters

`test/lit/passes/local-subtyping.wast` is a great guide to the real scope.

It covers exactly the places where a naïve port would go wrong:

- ordinary narrowing from a wide ref local to a more specific ref local
- non-null refinement via `ref.as_non_null`
- sibling-subtype / common-parent cases
- dead-code and trapping-path cases where `unreachable` should not force widening
- named-block and `try_table` control shapes that stress the dominance-aware updater
- `call_ref` and throwing examples that keep the helper rewrite honest

That test focus strongly supports the smaller reading of the pass.

## The most important porting lessons

If Starshine ports `local-subtyping`, preserve these facts first:

1. GC-gated scheduler placement after `optimize-casts` and before `coalesce-locals`
2. non-parameter-local-only scope
3. tuple-local exclusion unless the helper layer grows first
4. fact collection only from `local.get`, `local.set` / `local.tee`, and `ref.as_non_null(local.get)`
5. least-upper-bound narrowing instead of “pick the narrowest leaf type seen”
6. helper-driven mutation through `LocalUpdater`
7. ability to introduce a copy local when necessary
8. structural dominance semantics for named blocks, loops, and catches
9. mandatory `ReFinalize`
10. tests for non-null, dead-code, named-block, and `try_table` families

Those are the durable upstream-level truths.

## Sources

- [`../../../raw/research/0116-2026-04-20-local-subtyping-binaryen-research.md`](../../../raw/research/0116-2026-04-20-local-subtyping-binaryen-research.md)
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LocalSubtyping.cpp>
- Binaryen `version_129` scheduler source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Binaryen `version_129` after-inlining helper: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- Binaryen `version_129` helper sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/lubs.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-structural-dominance.h>
- Binaryen `version_129` lit tests: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/local-subtyping.wast>
