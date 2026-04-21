---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0138-2026-04-20-once-reduction-binaryen-research.md
  - ../../../raw/research/0202-2026-04-21-once-reduction-implementation-followup.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./dominance-propagation-and-cycle-safety.md
  - ./wat-shapes.md
  - ./parity.md
  - ../../no-dwarf-default-optimize-path.md
---

# Binaryen `once-reduction` strategy

## Upstream source rule

Use Binaryen `version_129` as the primary source oracle for this pass.

Primary files:

- `src/passes/OnceReduction.cpp`
- `src/passes/pass.cpp`

Most important helper dependencies visible in the implementation:

- `CFGWalker`
- `DomTree`
- `Intrinsics::getAnnotations(...)`
- `Names::getValidGlobalName(...)`
- `ExpressionManipulator::nop(...)`
- `std::atomic<bool>` in the shared scan state

The shipped lit surface is also part of the contract:

- `test/lit/passes/once-reduction.wast`

For a compact file/test ownership map, see:

- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)

## High-level intent

Binaryen uses `once-reduction` to remove redundant work around run-once control scaffolding.

But the real contract is narrower than the pass name sounds.

The pass only stays correct because it preserves all of these at once:

1. the controlling once-bit global is monotonic in the only way the pass actually needs
2. only the guard read at the top of the once function matters
3. the optimized call is a no-param/no-result direct call
4. the optimized write is a redundant nonzero constant write to the same once-bit
5. the optimization point is reached on a path where that once-bit is definitely already set
6. wrapper-body cleanup does not collapse every guard in a call cycle

That is why this must stay a module pass with nested function analysis.

## Where the pass runs

In `pass.cpp`, the default no-DWARF global-prepass builder inserts `once-reduction`:

- after `memory-packing`
- before `global-refining`
- only when `optimizeLevel >= 2`

That is notable for two reasons.

### 1. It is early

This is not a late local cleanup or post-inlining helper pass.
It is part of the early module pass cluster that tries to simplify the whole module before the main function-optimization stack begins.

### 2. It is top-level one-shot, but internally nested

The saved local Binaryen debug log shows one top-level `running pass: once-reduction` line and then `running nested passes`.
That second line is easy to misread.
Here it reflects the implementation launching nested helper passes (`Scanner` and then `Optimizer` repeatedly), not a later pass-runner rerun contract like `optimizeAfterInlining(...)`.

## Concrete ownership summary

The exact `version_129` source is easiest to keep straight if you assign each phase to the file-local owner that actually implements it:

- `Scanner`
  - rejects bad reads and writes and recognizes the exact wrapper shape
- `OnceReduction::run(...)`
  - seeds candidates, invalidates exported globals, adds fake-global idempotent support, and runs the fixed-point loop
- `Optimizer`
  - performs the CFG/dominator walk and writes the next iteration of function summaries
- `optimizeOnceBodies(...)`
  - does the tiny final empty-wrapper and single-call-wrapper cleanup with deterministic cycle protection

That ownership split is important because a future port can easily get the semantics subtly wrong by collapsing those responsibilities into one vaguer “once analysis” step.

## Phase 0: top-level shared state in `OptInfo`

The pass centers everything around `OptInfo`.

The 2026-04-21 follow-up confirms that this is not incidental implementation detail; it is the real contract between scanning, optimization, and wrapper cleanup.

It stores four related maps:

- `onceGlobals`
  - global name -> still a legal once-bit candidate?
- `onceFuncGlobals`
  - function name -> real or fake once-global name used to track that function
- `onceGlobalsSetInFuncs`
  - function name -> currently known set of once-globals definitely set by that function summary
- `newOnceGlobalsSetInFuncs`
  - next-iteration version of the same summary

The `std::atomic<bool>` in `onceGlobals` is important.
The scan phase is function-parallel and multiple worker instances may discover disqualifying evidence for the same global concurrently.

## Phase 1: seed the legal once-global surface

Before scanning functions, `OnceReduction::run(...)` initializes the global candidacy map conservatively.

A global begins as a possible once-global only if it is:

- integer-typed
- and not imported

Then exports narrow the set further:

- exported globals are immediately disqualified

This preserves the module boundary.
If the outside world can read or write the global, the pass refuses to reason about it as a private once-bit.

## Phase 2: `Scanner` finds explicit once functions and disqualifying evidence

`Scanner` is a parallel `PostWalker` over functions.
It has two main tasks.

### A. reject bad once-global writes and reads

The pass keeps a global as “once” only while all observed evidence stays within a narrow contract.

Allowed writes:

- integer constant writes with value `> 0`

Disqualifying writes:

- zero constant writes
- nonconstant writes
- anything that shows the pass cannot rely on zero-versus-nonzero monotonicity

Allowed reads:

- the single guard read at the top of a recognized once function

Disqualifying reads:

- every other read anywhere else

That tells you what the pass really cares about:

- not the exact numeric payload of the global
- just the boolean-like distinction between “still guarded” and “already run”

## Phase 3: exact once-function shape detection in `getOnceGlobal(...)`

This helper is intentionally strict.
It recognizes only this top-of-function shape:

```wat
(block
  (if (global.get $g)
    (then (return)))
  (global.set $g (i32.const 1))
  ...payload...)
```

More precisely, the implementation requires:

- function body root is a `Block`
- body has at least two items
- item `0` is an `If`
- the `If` condition is exactly `GlobalGet`
- the true arm is exactly `Return`
- there is no false arm
- item `1` is a `GlobalSet` to the same global
- that `GlobalSet` is not unreachable and was already proven elsewhere to write a nonzero constant
- function params are none
- function results are none

The lit file tests nearby failures such as:

- `nop` before the `if`
- `nop` between the `if` and the `global.set`
- an `else` arm
- mismatched get/set globals
- non-block body roots
- too-short bodies
- params or results

## Important nuance: actual Binaryen does not check the initializer value

The comments describe once-globals as beginning at zero.
But `OnceReduction.cpp` never validates that initializer.
The shipped lit file includes a nonzero-initial-value case and still expects optimization.

So the safer statement is:

- Binaryen requires the relevant later writes to stay nonzero
- it does not require the initial value to literally be zero today

## Phase 4: post-scan combine step

The scan phase is optimistic about functions.
It first records functions that match the once-body shape.
Then the main pass checks whether the controlling global survived all the bad-read and bad-write filters.

If the global did not survive:

- the function is demoted from once-function status

So there are really two separate proofs:

1. the function body looks like a once wrapper
2. the global is actually safe to reason about as a private monotonic once-bit

Both must succeed.

## Phase 5: upstream idempotent fast path

This is one of the most important source-derived details in the file.

After the explicit once-global scan, Binaryen also checks for no-param/no-result functions with the annotation:

- `@binaryen.idempotent`

When it finds one, it manufactures a fake once-global name with `Names::getValidGlobalName(...)` and stores that name in `onceFuncGlobals`.
It also marks the fake global as valid in `onceGlobals`.

That lets the rest of the pass reuse the same analysis machinery.

Important limits remain:

- params are still unsupported
- results are still unsupported
- fake-global functions can participate in call elimination, but later body cleanup that requires a real global is skipped for them

## Phase 6: initialize the first summary facts

Before the main fixed-point loop, the pass seeds `onceGlobalsSetInFuncs`.

For each function:

- ensure the map entry exists
- if the function itself is a once-function, insert its controlling once-global into its initial set

If no once-functions were found at all:

- the pass returns immediately

So there is no point running the CFG optimizer unless there is at least one relevant once fact to propagate.

## Phase 7: per-function CFG optimization in `Optimizer`

`Optimizer` is where the pass stops being a simple scan and becomes a real control-flow analysis.

### What it records in each block

Each basic block stores a list of only two relevant expression kinds:

- `GlobalSet`
- `Call`

The pass deliberately ignores other node kinds here.
This is not a general expression optimizer.

### Why `Call` but not everything else matters

The pass only knows how to prove redundancy for direct calls whose target has an associated once-global key.
That is why the implementation does not visit `call_ref` and does not try to chase indirect-call targets here.

## Phase 8: dominator-tree propagation

For each function, the optimizer:

- builds the CFG
- builds a `DomTree`
- processes blocks in reverse postorder
- starts each reachable block with a copy of the immediate dominator's known-once set

The code leaves TODOs about richer merge reasoning:

- intersecting all predecessors
- intersecting exit blocks for function summaries

That means the released algorithm is intentionally conservative.
It mostly knows facts that flow through domination, not arbitrary “all branches did the same thing” summaries.

This is why the lit file keeps after-`if` merge cases conservative even when both arms call the same once function.

## Phase 9: the `optimizeOnce(...)` action

Inside a block, both relevant node families are normalized to the same question:

- does this instruction definitely set once-global `G`, and do we already know `G` is set on this path?

If yes:

- `ExpressionManipulator::nop(expr)` removes the instruction

If no:

- `G` is inserted into the current known-once set

That one action handles both:

- redundant `global.set` to an already-set once-global
- redundant direct `call` to a once-function whose once-global is already known set

The strict no-param/no-result restriction matters here.
Because optimized calls have no operands and no results, the whole node can safely become `nop` without extra repair or temp locals.

## Phase 10: direct-call summary propagation

When the optimizer sees a direct call to an ordinary function, it still unions in the caller-visible summary facts from `onceGlobalsSetInFuncs[target]`.
That is how simple straight-line call chains propagate useful once facts outward.

Example shape:

- `A -> B -> C -> D -> once`

After enough iterations:

- `D` knows it sets `once`
- then `C` learns that calling `D` definitely sets `once`
- then `B` learns that calling `C` definitely sets `once`
- then `A` can remove a later redundant `call once`

## Important nuance: summary facts are conservative

The implementation stores the learned summary from `onceGlobalsWrittenVec[0]` and leaves a TODO about intersecting exits in the future.
Combined with the lit tests, the safest interpretation is:

- these summaries are conservative guaranteed facts, closer to entry-prefix or dominator-safe facts than to arbitrary full-function postconditions

I am calling that an inference from source structure plus tests, not a prose quote from the file.
But it matches the observable behavior and matters a lot when explaining the triple-loop case.

## Phase 11: outer fixed-point iteration

The pass reruns `Optimizer` until the total count of known once-globals in all function summaries stops increasing.

That makes `once-reduction` a small whole-module fixed-point analysis.
It is not enough to optimize each function once, because new caller facts can appear only after callee summaries have been improved.

The pass uses a simple monotonic progress metric:

- total number of once-globals in all summary sets

As long as that total rises:

- there may be more useful facts to propagate

## Phase 12: final trivial once-body cleanup in `optimizeOnceBodies(...)`

Only after the main analysis stabilizes does Binaryen simplify the once functions themselves.
That avoids changing the bodies while the main optimizer is still learning from them.

The cleanup is intentionally tiny.

### Case A: no payload

If the body contains only:

- the guard `if (global.get) return`
- the nonzero `global.set`

then the whole body becomes `nop`.

This overlaps with later global-cleanup reasoning, but Binaryen does it here because the pass has already done all the hard proof work.

### Case B: payload is a single direct call to another once function

If the payload is exactly:

- `call $other_once`

then Binaryen may delete the two early-exit lines in the wrapper.
The resulting function is just:

- `call $other_once`

Why that is safe:

- one layer of once-guard is enough if the wrapper does nothing else

Why that is **not** always safe:

- if the wrapper did more work after the call, that work could run multiple times
- if the pass removed guards on every node in a cycle, it could create an infinite loop

So the file tracks `removedExitLogic` and iterates functions deterministically, refusing to remove a wrapper's guard when the target wrapper already had its guard removed.

## What this pass does **not** do

These non-goals are worth keeping explicit:

- no general effect-based repeated-call elimination
- no `call_ref` or indirect-target reasoning
- no support for params or results in optimized once calls
- no all-predecessor merge intersection today
- no full exit-summary intersection today
- no body cleanup for arbitrary once functions; only trivial empty or trivial single-call wrapper bodies
- no requirement that the once-global initializer be literally zero

## Why the official tests matter so much

The real contract is easiest to understand once you see the test surface Binaryen ships.
The dedicated `once-reduction.wast` file covers:

- straight-line call elimination
- merge and loop conservatism
- nonzero initializer acceptance
- zero-write and nonconstant-write rejection
- params/results rejection
- extra-read rejection
- imported/exported global boundaries
- long control-flow and try/catch stability
- straight-line call-chain propagation
- wrapper cleanup
- call-cycle and triple-loop ordering hazards
- self-recursive once calls

That is much broader than the current local test file.

## Current freshness note

A narrow 2026-04-20 check found no semantic drift here:

- current `main` `OnceReduction.cpp` is identical to `version_129`
- current `main` `once-reduction.wast` is also identical to `version_129`

So the current wiki should continue treating `version_129` as the semantic oracle without an active trunk-drift caveat.

## What a future port or parity pass must preserve

A future strict-parity Starshine port or refactor must keep these Binaryen-backed rules honest:

- global candidacy is a whole-module property, not a local peephole property
- the once-function pattern matcher is intentionally exact
- no-param/no-result direct-call scope matters for safe `nop` replacement
- nonzero later writes are acceptable, but zero or nonconstant writes are not
- extra reads of the once-global anywhere disqualify it
- after-merge cases stay conservative because Binaryen does not do full predecessor intersection here
- call-chain propagation is real, but triple-loop/cycle overreach is explicitly blocked
- trivial wrapper cleanup must keep at least one guard in risky cycles
- idempotent annotations are part of the official surface even though they are easy to miss in the dedicated lit file

If local code intentionally broadens or narrows any of those rules, keep that as an explicit documented divergence.
