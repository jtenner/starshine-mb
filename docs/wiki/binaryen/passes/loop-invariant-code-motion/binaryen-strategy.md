---
kind: concept
status: supported
last_reviewed: 2026-06-01
sources:
  - ../../../raw/binaryen/2026-04-25-loop-invariant-code-motion-current-main-port-readiness.md
  - ../../../raw/binaryen/2026-04-24-loop-invariant-code-motion-primary-sources.md
  - ../../../raw/research/0282-2026-04-24-loop-invariant-code-motion-primary-sources-and-source-correction-followup.md
  - ../../../raw/research/0173-2026-04-21-loop-invariant-code-motion-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LoopInvariantCodeMotion.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/find_all.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/licm.wast
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/LoopInvariantCodeMotion.cpp
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./effects-loops-and-hoisting-rules.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
---

# Binaryen strategy for `loop-invariant-code-motion`

## What the pass really is

Upstream Binaryen publishes this pass as `licm`.
The local Starshine registry still tracks it under the descriptive name `loop-invariant-code-motion`.

The reviewed `version_129` implementation is a **conservative loop-preheader statement mover**.
Its real job is:

- find loops in each function,
- compute conservative loop-body effect and local-write summaries,
- scan the loop body's unconditional entry statements,
- move eligible none-typed statements before the loop,
- leave `nop`s in the old loop-body slots,
- and rebuild the local tree as a block of moved statements followed by the loop.

That means the best mental model is:

- **whole-statement motion out of loop entrances**,
- not arbitrary expression hoisting,
- not fixed-point temp-local value caching,
- not local CSE,
- and not the inverse of `code-pushing`.

## Important 2026-04-24 correction and 2026-04-25 recheck

Earlier living wording described LICM as if it created fresh temp locals for arbitrary invariant value expressions and replaced in-loop uses with `local.get`s.
That is not what reviewed Binaryen `version_129` does.

The source-backed correction is:

- `interestingToMove(...)` only considers expressions whose type is `none`.
- The main rewrite pushes the original none-typed expression pointer into a moved list.
- The old loop-body slot becomes `nop`.
- At the end, Binaryen builds a new block containing moved statements followed by the original loop.
- No fresh helper-local cache is synthesized by LICM for a value expression.

This is a major porting constraint: a future Starshine implementation should start from none-result statement motion, not a generic value-preheader cache.

The 2026-04-25 current-main / port-readiness bridge in [`../../../raw/binaryen/2026-04-25-loop-invariant-code-motion-current-main-port-readiness.md`](../../../raw/binaryen/2026-04-25-loop-invariant-code-motion-current-main-port-readiness.md) found no teaching-relevant drift from this corrected contract.

## Scheduler placement

`src/passes/pass.cpp` registers the upstream public pass name `licm` as a normal public Binaryen pass.

The local repo makes four scheduler facts explicit:

- it remains removed in `src/passes/optimize.mbt`,
- `../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md` now lists `loop-invariant-code-motion` in the current removed-name migration gap,
- `../../../raw/research/0065-2026-03-24-ir2-execution-plan.md` treats the old batch labels as historical and keeps removed-pass revival behind explicit source reconciliation plus first-slice work,
- it is absent from `docs/wiki/binaryen/no-dwarf-default-optimize-path.md` and the saved generated-artifact `-O4z` skipped-slot queue.

So the scheduler truth is:

- real public upstream pass: yes,
- current local active pass: no,
- default no-DWARF `-O` / `-Os` pass: no,
- justified living dossier target: yes, because Starshine still preserves the removed name and the old pass-port maps still mention it.

## Implementation shape

Nearly everything important lives in `src/passes/LoopInvariantCodeMotion.cpp`.

The main state and helpers are:

- `LazyLocalGraph`, created per function, for local dependency checks,
- `FindAll<Loop>` for loop discovery,
- `EffectAnalyzer` for side-effect and trap-safety reasoning,
- `FindAll<LocalSet>` for loop-local set counts,
- `Builder` for the final block/nop construction,
- `interestingToMove(...)` for candidate filtering,
- `hasGetDependingOnLoopSet(...)` for local dependency rejection.

This file layout says the pass is loop-aware and effect-aware, but the rewrite target is narrower than a textbook LICM pass: Binaryen moves eligible none-result statements from the loop entrance.

## Core implementation phases

## Phase 1: prepare per-function local dependency analysis

`doWalkFunction(...)` creates a `LazyLocalGraph` for the function before walking.
That local graph is used later to ask whether a `local.get` depends on a `local.set` that remains in the loop.

This is the first difference from a naive syntactic-invariance pass: a local read is only safe if its reaching local sets do not come from inside the loop being exited.

## Phase 2: discover loops and summarize loop body hazards

For each loop, `visitLoop(...)` obtains all nested loops and expressions in the loop body.
It summarizes broad hazards, including:

- global-state effects,
- exception effects,
- control-flow transfer,
- local gets and sets,
- and generic mutable-state effects.

It also counts local sets in the loop body.
That count matters because moving one `local.set` out is unsafe if another `local.set` to the same index still remains in the loop.

## Phase 3: scan only unconditional loop-entry statements

Binaryen walks the immediate loop body statements in order.
It stops when it reaches an expression with control-transfer effects.

That gives the real placement rule:

- the pass does not search every statement anywhere in the loop,
- it starts from statements that always execute on loop entry,
- and it avoids moving work across a branch, return, throw, or other control-transfer boundary.

Flattening can help because it can turn nested structure into more explicit statements at this entrance surface, but LICM itself is not a flattening pass.

## Phase 4: filter candidates with `interestingToMove(...)`

A candidate must first be none-typed.
Then Binaryen rejects several shapes, including:

- `nop`,
- `unreachable`,
- control-flow and scope-shaping expressions,
- `local.get` / `global.get`,
- calls,
- stores,
- and other forms that are trivial, structural, or not intended as movement targets.

The practical beginner rule is:

- LICM moves useful **statements**,
- not arbitrary value subtrees.

## Phase 5: prove motion safety

For a candidate entrance statement, the pass rejects motion when the statement:

- conflicts with loop global-state effects,
- may throw while the loop has exception effects,
- has control-flow transfer,
- reads a local whose dependency comes from a loop-local set,
- sets a local while another set to that local remains in the loop,
- may trap while the loop has mutable-state effects,
- or has mutable-state effects of its own.

The exact effect model is conservative.
If the pass cannot prove that earlier evaluation is behavior-preserving, the statement stays in the loop.

## Phase 6: emit moved statements and `nop` placeholders

When a statement moves:

1. Binaryen remembers the original statement in a moved list.
2. It replaces the original loop-body statement with `nop`.
3. After the entrance scan, it builds a block containing all moved statements followed by the original loop.
4. The new block is set as the replacement for the loop.

This is not a temp-local rewrite.
It is a tree-restructuring rewrite that makes a pre-loop prelude explicit.

## Pass interactions

### Versus `flatten`

The source comment says flattening can help by breaking code into separately movable pieces.
That is a data-shape interaction, not a requirement that LICM itself constructs flat IR.

### Versus `code-pushing`

- `code-pushing` sinks work deeper into control-flow arms.
- LICM lifts safe loop-entry statements outward before the loop.

Both are motion passes, but their direction, placement proof, and rewrite shapes differ.

### Versus `precompute`

- `precompute` folds values when compile-time semantics are known.
- LICM does not fold; it changes when a runtime statement executes.

### Versus `local-cse` and `simplify-locals`

- `local-cse` reuses equivalent local work.
- `simplify-locals` cleans local traffic.
- LICM's own contract is the loop-safe statement move and `nop` replacement.

## Positive rewrite families

### 1. Pure dropped computation at loop entry

A `drop` whose child is safe, loop-invariant, and none-result as a full statement can move before the loop.
The original slot becomes `nop`.

### 2. Invariant `local.set` at loop entry

A `local.set` may move before the loop when its RHS does not depend on loop-local sets and no other set to that local remains in the loop.

### 3. Nested-loop exposure

If a statement first moves out of an inner loop, it may become visible to an outer loop traversal.
The source notes this nested-loop behavior explicitly; it is not the same as a fixed-point temp-local hoist over arbitrary child expressions.

### 4. Flattening-enabled motion

After a separate flattening-style pass separates statements, LICM may have more eligible none-typed entrance statements to move.

## Negative and bailout families

### 1. Non-entrance statements

If a statement is not on the unconditional loop-entry surface, LICM does not move it.

### 2. Control-transfer boundaries

The entrance scan stops at control transfer.
Statements after a branch/return/throw-like boundary are not moved by this pass.

### 3. Local dependency hazards

If a candidate reads a local whose reaching set is inside the loop, it stays.
If a candidate sets a local that still has another in-loop set, it stays.

### 4. Global / exception / mutable-state hazards

Global-state effects, exception effects, mutable-state effects, and trap timing can all block motion.

### 5. Stores, calls, and structural nodes

The interesting-candidate filter excludes these from the normal movement surface.

## Current-main drift check

A focused 2026-04-25 current-`main` / port-readiness bridge on `LoopInvariantCodeMotion.cpp`, `pass.cpp`, `pass.h`, `effects.h`, `find_all.h`, `local-graph.h`, `wasm-builder.h`, and `licm.wast` did not surface teaching-relevant drift from the refreshed `version_129` contract.

That is a narrow claim:

- it does not prove every Binaryen history point after `version_129`,
- it does support keeping `version_129` as the main oracle for this dossier's behavior claims,
- and it supports using the same corrected contract as the first Starshine slice's acceptance bar.

## What a future Starshine port must preserve

A faithful port should preserve:

- the upstream/local naming split (`licm` vs `loop-invariant-code-motion`),
- loop discovery and loop-body effect summaries,
- unconditional-entry-only movement,
- none-typed statement candidate filtering,
- local dependency checks equivalent to Binaryen's `LazyLocalGraph` use,
- local-set count checks for moved `local.set`s,
- conservative rejection of global, exception, control-transfer, trap, and mutable-state hazards,
- pre-loop statement emission,
- and `nop` / cleanup-safe handling of the original loop-body slots.

## Easy-to-miss teaching summary

If someone remembers only one sentence, it should be this:

> Binaryen `licm` moves eligible none-typed loop-entry statements before the loop; it is not a generic temp-local hoister for arbitrary invariant value expressions.

## Sources

- [`../../../raw/binaryen/2026-04-25-loop-invariant-code-motion-current-main-port-readiness.md`](../../../raw/binaryen/2026-04-25-loop-invariant-code-motion-current-main-port-readiness.md)
- [`../../../raw/binaryen/2026-04-24-loop-invariant-code-motion-primary-sources.md`](../../../raw/binaryen/2026-04-24-loop-invariant-code-motion-primary-sources.md)
- [`../../../raw/research/0282-2026-04-24-loop-invariant-code-motion-primary-sources-and-source-correction-followup.md`](../../../raw/research/0282-2026-04-24-loop-invariant-code-motion-primary-sources-and-source-correction-followup.md)
- [`../../../raw/research/0173-2026-04-21-loop-invariant-code-motion-binaryen-research.md`](../../../raw/research/0173-2026-04-21-loop-invariant-code-motion-binaryen-research.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LoopInvariantCodeMotion.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/find_all.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/licm.wast>
- <https://github.com/WebAssembly/binaryen/blob/main/src/passes/LoopInvariantCodeMotion.cpp>
