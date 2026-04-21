---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0173-2026-04-21-loop-invariant-code-motion-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LoopInvariantCodeMotion.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/find_all.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/parents.h
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/LoopInvariantCodeMotion.cpp
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./effects-loops-and-hoisting-rules.md
  - ./wat-shapes.md
---

# Binaryen strategy for `loop-invariant-code-motion`

## What the pass really is

Upstream Binaryen publishes this pass as `licm`.
The local Starshine registry still tracks it under the descriptive name `loop-invariant-code-motion`.

The reviewed implementation is a **whole-function fixed-point loop optimizer** whose real job is:

- collect loops,
- summarize what happens inside each loop,
- prove that some value-producing expressions are invariant and safe to evaluate before the loop,
- hoist those expressions into temp locals,
- and iterate until no new hoists appear.

That means the best mental model is:

- **conservative loop-header hoisting with helper locals**
- not generic code motion
- not constant folding
- not local CSE
- and not the inverse of `code-pushing` in any simplistic sense

## Scheduler placement

`src/passes/pass.cpp` registers the upstream public pass name `licm` as a normal public pass.

The local repo makes four scheduler facts explicit:

- it remains removed in `src/passes/optimize.mbt`
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md` still lists `loop-invariant-code-motion` as Batch 3 removed-until-hot-implementation work
- it is absent from `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- it is absent from the saved generated-artifact `-O4z` skipped-slot queue

So the scheduler truth is:

- real public pass: yes
- current local active pass: no
- default no-DWARF `-O` / `-Os` pass: no
- justified tracker-expansion dossier target: yes

## Implementation shape

Nearly everything important lives in `src/passes/LoopInvariantCodeMotion.cpp`.

The pass tracks per-function state for:

- discovered loops
- which expressions live inside which loops
- a per-loop conservative set of side-effecting expressions
- memoized hoistability results
- explicit moved and unmoved sets

Important consequences:

- this is loop-aware rather than just subtree-aware
- this is effect-aware rather than just purity-aware
- this is iterative rather than one-shot
- this is conservative by construction

## Core implementation phases

## Phase 1: discover loops and loop-contained expressions

The pass begins by finding loops and building parent information.
For each loop, it scans the loop body and records:

- which expressions are syntactically contained by that loop
- which of those expressions have effects that matter for motion safety

That is why `FindAll<Loop>` and `Parents` show up in the reviewed source surface.
Without them, LICM cannot answer “is this node really inside the loop?” or rewrite safely later.

## Phase 2: decide whether a node is even worth considering

Binaryen does not attempt to hoist every pure subtree.
The pass first filters to expressions that are interesting enough to move.

The practical meaning is:

- some trivial or non-reusable nodes are ignored
- structural control nodes are not the target
- clearly effectful nodes are not interesting hoist candidates
- the pass is aimed at reusable value expressions whose earlier computation could plausibly help

This is a major beginner correction:

- LICM is not “move every invariant thing”
- it is “consider only a restricted reusable-value subset, then prove safety”

## Phase 3: prove a candidate can move out of one loop

This is the heart of the pass.

A candidate expression is only movable out of a specific loop when all of these broad requirements line up:

- the expression is actually inside that loop
- its own effects are compatible with the loop's effects
- moving it earlier cannot change trap timing in an observable way
- every needed child value is either already outside the loop or also hoistable
- the expression is not one of the explicitly disallowed structural forms

That means the real legality test is:

- **loop-invariant + effect-safe + child-hoistable**

not merely:

- “the node looks pure”

## Phase 4: materialize the hoist with a helper local

When Binaryen decides to hoist, it does not duplicate the computation at each use.
Instead it:

1. creates a fresh temp local of the expression type
2. inserts `local.set temp, expr` before the loop
3. replaces the original in-loop expression with `local.get temp`

This is the central rewrite contract a future Starshine port must preserve.
A faithful LICM port is a temp-local hoister, not an expression duplicator.

## Phase 5: rerun to a fixed point

The pass repeats until nothing new moves.
This matters because hoisting one child can expose a new parent hoist in the next round.

A small teaching example:

- round 1 hoists an invariant child like `i32.add(x, 1)`
- round 2 can now hoist its parent `i32.mul(temp, y)` if `y` is invariant too

So the pass should be taught as a **fixed-point hoister**, not a single sweep.

## Effect and safety model

`EffectAnalyzer` is one of the main things that keeps Binaryen LICM honest.
The pass reasons about observable behavior, not just algebraic equivalence.

Practical consequences:

- loop-side memory writes can block hoisting loads
- calls and indirect calls are conservative barriers unless proven otherwise
- trap-capable nodes cannot move if that would make the trap happen earlier or on different executions
- allocation-heavy or observably effectful GC expressions are conservative blockers
- control-dependent structure is not treated as ordinary movable value computation

That is why the pass feels narrower than textbook LICM on paper.
It is tuned for Binaryen's real IR semantics and effect model.

## Positive rewrite families

## 1. Repeated arithmetic on loop-invariant locals

If a loop repeatedly recomputes an arithmetic value from locals that are defined outside the loop and not modified inside it, LICM can hoist that arithmetic into a temp local before the loop.

## 2. Nested value trees that become movable in stages

A parent may not move during the first round because one of its children still lives inside the loop.
After that child is hoisted, the parent may become movable in a later round.
This staged behavior is part of the real algorithm, not an incidental implementation detail.

## 3. Shared expensive invariant subexpressions

A value used multiple times inside the loop body is a natural positive family because the temp local makes the reuse explicit.

## Negative and bailout families

## 1. Loop-carried local traffic

If the candidate depends on a local that the loop writes, the value is not invariant for that loop.
That is a direct bailout.

## 2. Memory-sensitive loads

Even if a load's pointer expression is invariant, the loaded memory contents may not be.
Loop-side writes or unknown memory effects therefore block the hoist.

## 3. Trap-timing changes

A node that can trap may not move if evaluating it before the loop would make the trap happen at a different time or on a path that would not otherwise reach it.

## 4. Calls, allocations, and other observable side effects

These are conservative blockers in the general case.
A future port should assume that Binaryen's implementation is intentionally risk-averse here.

## 5. Structural control nodes

LICM is not a general block/branch/return mover.
It hoists reusable values, not arbitrary control structure.

## Helper dependencies

## `EffectAnalyzer`

This is the main semantic safety dependency.
It answers whether evaluating a node earlier could change memory, call, trap, or other observable behavior.

## `FindAll<Loop>`

This is how the pass gets its initial loop roster.
Without explicit loop discovery, there is no LICM.

## `Parents`

Used to understand structural placement and to repair the tree during rewrites.

## `Builder`

Used to create fresh locals and `local.set` / `local.get` rewrites.

## Current-main drift check

A current-main spot check found the same public registration name (`licm`) and materially the same main helper structure in `LoopInvariantCodeMotion.cpp` as in `version_129`.

That is a narrow but useful claim:

- it does not prove every helper header is identical today
- it does support keeping `version_129` as the main oracle for this dossier

## Pass interactions

A few nearby-pass contrasts matter a lot for teaching.

### Versus `code-pushing`

- `code-pushing` sinks code deeper into branch structure
- LICM hoists some loop-invariant values upward before a loop

They are both motion passes, but their directions and safety stories are different.

### Versus `precompute`

- `precompute` folds compile-time-known expressions
- LICM moves runtime expressions whose value is stable across loop iterations

### Versus `local-cse`

- `local-cse` reuses equivalent work in a small local window
- LICM changes placement across loop boundaries

### Versus `simplify-locals`

- `simplify-locals` may clean up the helper-local traffic afterward
- but LICM's own contract is the loop-safe hoist, not the later local cleanup

## What a future Starshine port must preserve

A faithful port should preserve:

- the upstream/local naming split (`licm` vs `loop-invariant-code-motion`)
- loop-scoped effect summaries
- child-hoistability as part of parent-hoistability
- temp-local materialization before the loop
- in-loop replacement with `local.get`
- fixed-point reruns
- conservative bailouts on loop-carried locals, memory-side effects, calls, traps, and structural control hazards

## Easy-to-miss teaching summary

If someone remembers only one sentence, it should be this:

> Binaryen `licm` is a conservative fixed-point loop-header hoister: it only moves expressions that stay invariant across the loop, remain effect-safe when evaluated earlier, and can be represented as temp-local preheader values.

## Sources

- [`../../../raw/research/0173-2026-04-21-loop-invariant-code-motion-binaryen-research.md`](../../../raw/research/0173-2026-04-21-loop-invariant-code-motion-binaryen-research.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LoopInvariantCodeMotion.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/find_all.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/parents.h>
- <https://github.com/WebAssembly/binaryen/blob/main/src/passes/LoopInvariantCodeMotion.cpp>
