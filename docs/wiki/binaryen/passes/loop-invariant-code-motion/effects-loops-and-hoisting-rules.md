---
kind: concept
status: supported
last_reviewed: 2026-06-02
sources:
  - ../../../raw/binaryen/2026-04-25-loop-invariant-code-motion-current-main-port-readiness.md
  - ../../../raw/binaryen/2026-06-02-loop-invariant-code-motion-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-24-loop-invariant-code-motion-primary-sources.md
  - ../../../raw/research/0696-2026-06-02-loop-invariant-code-motion-current-main-recheck.md
  - ../../../raw/research/0282-2026-04-24-loop-invariant-code-motion-primary-sources-and-source-correction-followup.md
  - ../../../raw/research/0173-2026-04-21-loop-invariant-code-motion-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LoopInvariantCodeMotion.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
---

# Effects, loops, and hoisting rules in `loop-invariant-code-motion`

## The real proof obligation

The most important thing to teach about Binaryen LICM is that the pass is **not** asking only:

- “is this subtree pure?”

It is asking something closer to:

- is this a none-result statement on the loop's unconditional entry surface?
- can evaluating that statement before the loop preserve observable behavior?
- do its local reads avoid values written inside this loop?
- does moving it avoid local-set conflicts with statements still inside the loop?

That is why the corrected proof obligation is:

- **unconditional loop-entry statement + effect-safe + local-dependency-safe**.

A 2026-06-02 current-main recheck, together with the earlier 2026-04-25 bridge, found no teaching-relevant drift from this proof obligation and uses it as the acceptance bar for the first Starshine slice.

## Placement: unconditional loop entry only

Binaryen scans the immediate body entries of a loop in order.
It stops scanning when it sees control-transfer effects.

That means LICM does not search every nested expression in a loop.
It only moves statements from the prefix that always executes when the loop body is entered.

Practical consequences:

- a statement after `br`, `return`, `throw`, or similar transfer is not a candidate,
- a statement hidden in a conditional arm is not a candidate unless earlier passes expose it as an unconditional entry statement,
- flattening can help expose smaller candidate statements, but LICM does not do that restructuring itself.

## Candidate shape: none-typed statements

The reviewed `interestingToMove(...)` gate requires candidates to have type `none`.
It also excludes trivial or structural forms such as `nop`, `unreachable`, control-flow nodes, gets, calls, and stores.

That gives the most important source-correction rule:

- LICM moves eligible statements,
- not arbitrary value subexpressions,
- and not value expressions by synthesizing helper locals.

## Effect safety

Even a statement on the unconditional entry surface may fail the effect test.

Moving a statement earlier is illegal if it can change:

- global state ordering,
- exception behavior,
- control-flow transfer,
- mutable state ordering,
- or trap timing.

`EffectAnalyzer` is central because LICM is a semantics-preserving motion pass, not just a syntactic loop-invariance pass.

## Local dependency safety

Local reads are checked through `LazyLocalGraph`.
If a candidate has a `local.get` that depends on a `local.set` inside the loop, the candidate stays.

Local writes are also guarded.
If a candidate is a `local.set`, Binaryen checks whether another set to the same local remains in the loop.
If yes, the candidate stays.

This makes the local rule sharper than “locals are cheap”:

- a read of an outer stable local can be fine,
- a read of a loop-carried local is not fine,
- a lone invariant `local.set` may move,
- a `local.set` competing with another in-loop set cannot move.

## Rewrite shape: statement prelude plus `nop`

When Binaryen moves a statement, it makes the motion explicit in the tree:

- the original statement is remembered for the pre-loop prelude,
- its old loop-body slot is replaced with `nop`,
- moved statements are emitted before the loop,
- the moved prelude and the original loop are wrapped in a block.

This is the corrected replacement for the older helper-local story.
A future Starshine port should not silently turn reviewed `version_129` LICM into generic value caching.

## Common positive shapes

## 1. Dropped pure work at loop entry

```wat
(loop $L
  (drop (i32.add (local.get $x) (i32.const 1)))
  ...)
```

If `$x` does not depend on a loop-local set and the statement has no blocking effects, Binaryen can move the `drop` statement before the loop and leave `nop` behind.

## 2. Single invariant `local.set` at loop entry

```wat
(loop $L
  (local.set $t (i32.add (local.get $x) (i32.const 1)))
  ...)
```

This can move when `$x` is safe and there is no other set to `$t` still inside the loop.

## 3. Nested-loop exposure

A statement moved out of an inner loop can become visible around an outer loop as the walker continues.
That is the nested-loop exposure story the source calls out.
It is not the same as arbitrary child-then-parent temp-local hoisting.

## Common bailout shapes

## 1. Non-prefix statement

```wat
(loop $L
  (if (local.get $cond)
    (then (drop (i32.add (local.get $x) (i32.const 1))))))
```

The `drop` is not an unconditional loop-entry statement.
Expect it to stay unless another pass exposes it first.

## 2. Control-transfer boundary

```wat
(loop $L
  (br_if $L (local.get $cond))
  (drop (i32.add (local.get $x) (i32.const 1))))
```

The scan stops at the branch-like transfer boundary.
The later statement is not moved by LICM.

## 3. Loop-carried local dependency

```wat
(loop $L
  (local.set $x (i32.add (local.get $x) (i32.const 1)))
  (drop (i32.mul (local.get $x) (i32.const 2))))
```

The later read of `$x` depends on a set inside the loop.
That dependency blocks motion.

## 4. Competing local sets

```wat
(loop $L
  (local.set $x (i32.const 1))
  (local.set $x (i32.const 2)))
```

Moving only one set while another remains in the loop would change the local timeline.
Binaryen counts sets and rejects that case.

## 5. Mutable-state / trap hazards

```wat
(loop $L
  (drop (i32.div_s (local.get $x) (local.get $y))))
```

If evaluating the statement before the loop could change trap timing relative to mutable state, it stays.

## 6. Calls, stores, and structural nodes

```wat
(loop $L
  (call $helper)
  (i32.store (local.get $p) (i32.const 0)))
```

Calls and stores are excluded from the ordinary candidate surface.
Branches, returns, blocks, loops, and similar structure are not treated as movable statements here either.

## Easy-to-miss contrast with nearby passes

## Versus `flatten`

- `flatten` can expose more independently movable statements.
- LICM consumes those shapes if they are already present.

## Versus `code-pushing`

- `code-pushing` moves code deeper into selected control-flow arms.
- LICM moves safe loop-entry statements outward before the loop.

## Versus `precompute`

- `precompute` can eliminate runtime work by folding constants.
- LICM keeps runtime work but changes when it happens.

## Versus `simplify-locals`

- LICM may leave `nop`s and changed local traffic for later cleanup.
- `simplify-locals` can clean some neighboring local shapes.
- LICM itself is responsible only for the safe statement move.

## The one-sentence rule for future ports

If a future Starshine LICM port forgets everything else, it should preserve this:

> Only move a loop-entry statement when the statement is none-typed, always executes on loop entry, and can run before the loop without changing effects, traps, local dependencies, or local-set ordering.

## Sources

- [`../../../raw/binaryen/2026-04-25-loop-invariant-code-motion-current-main-port-readiness.md`](../../../raw/binaryen/2026-04-25-loop-invariant-code-motion-current-main-port-readiness.md)
- [`../../../raw/binaryen/2026-06-02-loop-invariant-code-motion-current-main-recheck.md`](../../../raw/binaryen/2026-06-02-loop-invariant-code-motion-current-main-recheck.md)
- [`../../../raw/research/0378-2026-04-25-loop-invariant-code-motion-port-readiness.md`](../../../raw/research/0378-2026-04-25-loop-invariant-code-motion-port-readiness.md)
- [`../../../raw/research/0696-2026-06-02-loop-invariant-code-motion-current-main-recheck.md`](../../../raw/research/0696-2026-06-02-loop-invariant-code-motion-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-24-loop-invariant-code-motion-primary-sources.md`](../../../raw/binaryen/2026-04-24-loop-invariant-code-motion-primary-sources.md)
- [`../../../raw/research/0282-2026-04-24-loop-invariant-code-motion-primary-sources-and-source-correction-followup.md`](../../../raw/research/0282-2026-04-24-loop-invariant-code-motion-primary-sources-and-source-correction-followup.md)
- [`../../../raw/research/0173-2026-04-21-loop-invariant-code-motion-binaryen-research.md`](../../../raw/research/0173-2026-04-21-loop-invariant-code-motion-binaryen-research.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LoopInvariantCodeMotion.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h>
