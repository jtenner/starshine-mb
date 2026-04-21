# 0173 - Binaryen `loop-invariant-code-motion` / `licm` research

Date: 2026-04-21
Status: supported

## Why this note exists

The original no-DWARF and saved generated-artifact `-O4z` parity queues are already dossier-covered, and the first tracker-expansion wave is covered too.
That means this campaign thread needed to either justify a major already-deep fallback or add another source-backed upstream-only registry pass.

I chose `loop-invariant-code-motion` because:

- it is still named in the local removed registry in `src/passes/optimize.mbt`
- it is also still called out in the local Batch 3 pass-port map in `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`
- `agent-todo.md` currently has **no dedicated `loop-invariant-code-motion` or `licm` slice**
- the local full name hides the upstream public alias `licm`
- it sits close to already-documented motion and cleanup neighbors like `code-pushing`, `precompute`, `local-cse`, and `simplify-locals`
- it has a real official Binaryen `version_129` implementation and dedicated lit coverage

So this is a justified second-wave tracker expansion, not an arbitrary detour.

## Scope and sources reviewed

Primary upstream sources reviewed:

- Binaryen `version_129` `src/passes/LoopInvariantCodeMotion.cpp`
- Binaryen `version_129` `src/passes/pass.cpp`
- Binaryen `version_129` `src/passes/pass.h`
- Binaryen `version_129` `src/ir/effects.h`
- Binaryen `version_129` `src/ir/find_all.h`
- Binaryen `version_129` `src/ir/parents.h`
- Binaryen `version_129` `test/lit/passes/licm.wast`
- current upstream `main` `src/passes/LoopInvariantCodeMotion.cpp`

Local project sources reviewed:

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`
- `src/passes/optimize.mbt`
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`

## Executive summary

Binaryen publishes this pass under the short public name **`licm`**.
The local Starshine registry still records it under the descriptive removed-registry name **`loop-invariant-code-motion`**.

That naming split matters because the pass is easy to mis-teach.
It is **not** a general “move pure code upward whenever convenient” optimizer.
Its real `version_129` contract is much narrower:

- find loops
- detect expressions inside those loops that are independent of loop-varying state
- require strong effect safety and child-hoistability
- hoist the chosen expression into a helper `local.set` before the loop
- replace the original in-loop occurrence with `local.get`
- rerun until a fixed point because hoisting one child can make its parent hoistable later

A good beginner summary is:

> Binaryen LICM is a conservative loop-header hoister. It proves an expression is loop-invariant and safe, stores it once before the loop, and reuses it inside the loop with a temp local.

## Scheduler and registry facts

From the reviewed sources:

- upstream public pass name in `pass.cpp`: `licm`
- local removed-registry name in `src/passes/optimize.mbt`: `loop-invariant-code-motion`
- local batch map status in `docs/0063...`: Batch 3 removed-until-hot-implementation work
- current canonical no-DWARF `-O` / `-Os` page: **absent**
- saved generated-artifact `-O4z` skipped queue: **absent**

So the durable scheduler story is:

- this is a real official Binaryen pass
- it is not part of the repo's current canonical no-DWARF path
- it is not part of the saved generated-artifact skipped-slot queue
- it is still a legitimate documentation target because it remains in the local registry and batch map

## Implementation structure

The implementation is concentrated in one main source file:

- `src/passes/LoopInvariantCodeMotion.cpp`

The main pass class is a whole-function walker that stores per-function state roughly like this:

- `Function* func`
- `Module* module`
- `Builder builder`
- `std::unordered_map<Loop*, std::unordered_set<Expression*>> loopEffects`
- `std::unordered_map<Expression*, std::unordered_set<Loop*>> loops` (which loops contain which expressions)
- `std::unordered_map<Expression*, std::unordered_set<Loop*>> canMove` (memoized hoistability facts)
- `std::unordered_set<Expression*> moved`
- `std::unordered_set<Expression*> cannotMove`

That already reveals three important teaching facts:

1. this is loop-aware, not just local-tree-aware
2. it tracks effects at loop scope
3. it memoizes negative and positive movement results instead of recomputing everything from scratch

## Main algorithmic phases

## Phase 1: collect loops and loop-contained expressions

The pass first gathers loops in the function and builds parent information.
It then walks each loop body and records:

- every expression syntactically inside that loop
- a conservative union of side-effect-causing expressions for that loop

This is where `FindAll<Loop>` and `Parents` matter.
Without a parent map and explicit loop membership, the pass cannot answer the key question: “is this expression completely inside the loop I want to hoist out of?”

## Phase 2: decide whether an expression is interesting enough to consider

Binaryen does not try to hoist every pure expression.
The reviewed implementation uses a narrow “interesting to move” filter.
It looks for expressions where hoisting can plausibly pay off and where the result can be reused cleanly.

The exact code matters more than the name here:

- constants and many trivial leaf nodes are not the real target
- obviously side-effecting nodes are rejected
- branch/control terminators are rejected
- movement is framed around reusable value-producing expressions, not arbitrary statements

This is the first beginner trap:

- LICM is not “all loop-invariant pure nodes move”
- it is “some loop-invariant reusable value nodes may move”

## Phase 3: prove an expression can move out of a specific loop

This is the real core.
The pass asks whether a candidate can move out of a given loop.
The proof is recursive and memoized.

An expression is only considered movable when all of these broad conditions line up:

- it is fully inside the loop being considered
- its own effects are safe relative to the loop's effects
- its children are either already outside the loop or themselves hoistable
- it is not one of the explicitly banned structural forms
- it is not blocked by loop-local writes, memory effects, calls, traps, or control dependence hazards

The important safety idea is not just “the expression is pure.”
Instead, Binaryen asks something closer to:

- would computing this before the loop observe the same inputs?
- would computing it before the loop change trap behavior or memory/GC/call ordering?
- can every needed child value also be made available before the loop?

That is why the pass uses `EffectAnalyzer` rather than only syntactic purity checks.

## Phase 4: hoist one expression by materializing a temp local

Binaryen does not duplicate the expression at each use.
It does the opposite:

- create a fresh helper local of the expression type
- insert `local.set temp, expr` before the loop
- replace the original in-loop expression with `local.get temp`

This is a very important porting constraint.
A future port should not silently turn LICM into:

- expression duplication
- speculative preheader cloning without a temp
- global caching
- SSA-only value renaming

The reviewed implementation is specifically temp-local hoisting.

## Phase 5: rerun to a fixed point

The pass repeats until nothing more moves.
That is essential because hoisting one child can make its parent newly movable.

Example beginner mental model:

Before the first round:

- child `a` depends only on loop-invariant inputs
- parent `add(a, b)` cannot move yet because `a` is still inside the loop tree

After `a` moves into a temp local:

- parent `add(local.get tempA, b)` may now become hoistable too

So this is not one pass over the tree.
It is a small fixed-point optimizer.

## Effect and safety model

The pass depends heavily on Binaryen's effect system.
The reviewed code uses `EffectAnalyzer` and loop-effect summaries to keep movement conservative.

Practical consequences:

- loads generally do not move across loop-side stores or other invalidating memory effects
- calls usually block motion unless their effect behavior is known safe for the candidate
- trapping expressions cannot be hoisted if doing so could change whether or when a trap happens
- GC operations with allocation or observable side effects are conservative barriers
- control-dependent constructs are not treated as ordinary movable values

This means LICM is not just “loop invariant” in the textbook compiler sense.
It is really:

- **loop invariant + effect-safe + child-hoistable + structure-allowed**

## Important helper utilities and analyses

## `EffectAnalyzer`

This is the main semantic safety dependency.
It answers whether evaluating a node earlier could change observable behavior.
That includes memory, calls, traps, and other side effects.

## `FindAll<Loop>`

This is the simple loop discovery step.
The pass only works because it has an explicit roster of loops to reason about.

## `Parents`

Used to repair and inspect structure while hoisting.
It helps the pass know where an expression sits and where replacements are legal.

## `Builder`

Used to create the helper temp locals and `local.set` / `local.get` rewrites.

## WAT / IR shapes that really matter

## Positive family 1: repeated pure arithmetic from loop-invariant inputs

Canonical shape:

```wat
(loop $L
  ...
  (drop
    (i32.add
      (local.get $outside_a)
      (local.get $outside_b)))
  ...)
```

If both inputs are unchanged by the loop and no effect/trap rule blocks motion, Binaryen can hoist the `i32.add` before the loop and replace the in-loop use with `local.get $temp`.

## Positive family 2: parent becomes movable after child hoisting

Canonical shape:

```wat
(loop $L
  ...
  (drop
    (i32.mul
      (i32.add (local.get $x) (i32.const 1))
      (local.get $y)))
  ...)
```

If the inner `i32.add` is hoisted first and `y` is loop-invariant too, a later round may hoist the `i32.mul` as well.
This fixed-point story is one of the easiest things to miss if you only skim the file.

## Positive family 3: one expensive value reused in the loop body

LICM is especially intuitive when the same invariant value feeds multiple in-loop operations.
The helper local makes the payoff easy to explain to beginners.

## Negative family 1: loop-carried locals

If the expression reads a local that the loop writes, it is not loop-invariant for that loop.
That is a direct bailout.

## Negative family 2: memory-sensitive loads

A load that might be affected by loop-side memory writes cannot just move out.
Even if its pointer expression is syntactically invariant, the loaded value might not be.

## Negative family 3: trap timing changes

Division, invalid conversion, or similar trap-capable operations do not move if hoisting would make the trap happen earlier or in executions where the loop body would not otherwise reach it.

## Negative family 4: calls and allocations

Calls, `call_ref`, allocations, and other observably effectful operations are conservative blockers unless the effect model says otherwise.
In practice, beginners should treat them as “usually not LICM material.”

## Negative family 5: structural control nodes

Branches, returns, and most scope-shaping control nodes are not the pass's target.
LICM hoists reusable values, not arbitrary control structure.

## Easy misunderstandings corrected

1. **This is not generic code motion.**
   It is loop-header value hoisting with a temp local.

2. **This is not just purity checking.**
   Effect safety and trap timing are part of the real contract.

3. **This is not one-shot.**
   The pass iterates because child hoists expose parent hoists.

4. **This is not `code-pushing` in reverse.**
   `code-pushing` sinks code deeper into control flow; LICM lifts some loop-invariant values outward.

5. **This is not `precompute`.**
   `precompute` folds compile-time-known expressions; LICM moves runtime expressions whose value stays stable across loop iterations.

6. **This is not `local-cse`.**
   `local-cse` reuses equivalent work in local windows; LICM changes loop placement.

## Pass interactions worth documenting

- `precompute` may simplify an expression enough that LICM later has less work to do.
- `local-cse` can remove leftover duplicate uses after LICM introduces temp locals.
- `simplify-locals` can clean up helper-local traffic around hoisted values.
- `code-pushing` is a conceptual neighbor but moves in the opposite direction.
- A future Starshine port should preserve that LICM is a separate pass with separate safety rules, not just a flag on one of those neighbors.

## Current-main drift check

A spot check of current upstream `main` found the same public pass registration name (`licm`) and the same main implementation structure in `LoopInvariantCodeMotion.cpp`.
Within the reviewed surfaces, the pass still appears materially aligned with `version_129`.

That is a narrow claim:

- it does **not** prove every helper header is unchanged
- it **does** support using `version_129` as the main oracle for this dossier today

## What a future Starshine port must preserve

A faithful port should preserve at least these semantic rules:

- public/local naming split: upstream `licm`, local `loop-invariant-code-motion`
- loop-scoped effect summaries, not just subtree purity
- loop-invariance checks against loop-carried local and memory changes
- helper-temp-local materialization before the loop
- in-loop replacement with `local.get`
- fixed-point iteration, not a single pass
- conservative bailouts on calls, traps, memory writes, and structural control hazards
- child-hoistability as part of parent-hoistability

## Open questions and uncertainty notes

I did not do a full line-by-line proof of every `interestingToMove(...)` exclusion branch or every exact `EffectAnalyzer` predicate used by the pass.
The living dossier should therefore preserve one careful uncertainty label:

- the high-level safety contract and main rewrite families are source-backed
- the exact profitability/interest filter details should still be treated as implementation facts to re-check during any real port

That uncertainty is narrow and does not weaken the main conclusions above.

## Durable conclusions

- `loop-invariant-code-motion` is a justified new tracker-expansion target because it remains in the local removed registry and Batch 3 pass-port map.
- `agent-todo.md` currently has no dedicated LICM slice.
- The upstream public pass name is `licm`, while the local registry keeps the full descriptive name.
- Binaryen `version_129` LICM is a conservative fixed-point loop-header hoister, not a generic motion pass.
- The pass depends on loop membership, effect safety, and child-hoistability.
- The rewrite strategy is temp-local hoisting before the loop plus in-loop `local.get` replacement.
- The main beginner-facing non-goals are just as important as the positives: no generic control motion, no unsafe trap reordering, no memory-insensitive load motion, and no blind duplication.

## Sources

- Local registry and project docs:
  - `docs/README.md`
  - `docs/wiki/binaryen/passes/tracker.md`
  - `docs/wiki/binaryen/passes/index.md`
  - `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
  - `agent-todo.md`
  - `src/passes/optimize.mbt`
  - `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`
- Official Binaryen sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LoopInvariantCodeMotion.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/find_all.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/parents.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/licm.wast>
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/LoopInvariantCodeMotion.cpp>
