---
kind: concept
status: supported
last_reviewed: 2026-04-22
sources:
  - ../../../raw/binaryen/2026-04-22-code-pushing-primary-sources.md
  - ../../../raw/research/0258-2026-04-22-code-pushing-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0115-2026-04-20-code-pushing-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
---

# `code-pushing` Segment Selection And Barriers

This page focuses on the easiest part of Binaryen `code-pushing` to misunderstand:

- how the pass chooses a movable suffix
- why some shapes that look pure still do not move
- why the one-arm and two-arm `if` cases behave differently

## One mental model first

Binaryen is not asking:

- “what code in this function could theoretically be sunk deeper?”

It is asking something more local:

- “in this one block, do I have a contiguous suffix of expressions immediately before a control-flow separator, and can some suffix of that region move into the specific downstream segments that actually use it?”

That is the real shape.

## Phase A: build a contiguous candidate region

While scanning a block left-to-right, Binaryen tracks a current region of expressions that are still candidates for pushing.

Useful beginner shorthand:

- **candidate region** = the current contiguous block suffix under consideration
- **tracked values** = expressions in that region that are still safe to move past later children
- **separator** = the next `if` or branchy structured node that might receive the pushed suffix

If a later child invalidates too much of that region, the region ends and the pass starts fresh.

That is why the pass does not gather disjoint expressions from far-apart places.

## Phase B: invalidation decides where the region can end

The real engine is invalidation.

Binaryen repeatedly asks whether the next child conflicts with the currently tracked candidate values.

If it does, those values are no longer movable past that child.

Typical invalidation families are:

- later local writes that break a candidate value’s local assumptions
- side effects that make reordering visible
- calls that can do visible work before a moved trap would happen
- control-flow transfers that make the execution relationship non-linear
- memory / table / mutable-global interactions
- EH-sensitive operations
- trap-sensitive operations under default settings

The details come from `EffectAnalyzer`, but the beginner takeaway is simple:

- *being pure in isolation is not enough*
- the candidate must remain safe to move **past what follows it**

## Phase C: the pass always chooses a suffix

When Binaryen finally considers a rewrite, it walks backward from the end of the current candidate region.

That means it is not choosing an arbitrary subset.
It is choosing among possible **suffixes**.

Why this matters:

- the algorithm stays cheap
- the rewrite stays structured
- the later target segments see a clean appended suffix
- the prefix that remains in the old block is still a real prefix, not a scattered remainder

If you ever find yourself describing the pass as choosing a random handful of independent expressions, that description has drifted away from upstream behavior.

## The generic segment family

The generic path uses `BranchSeeker` plus `optimizeSegment(...)`.

The resulting destinations are not arbitrary CFG successors. They are structured target segments associated with the next control-flow node.

A safe beginner summary is:

- Binaryen looks at the next branchy structure
- finds the concrete downstream segments or fallthroughs that matter
- checks whether the candidate suffix can be appended there safely and profitably

This family explains why `code-pushing.wast` contains block / branch / `br_table` flavored examples rather than only `if` examples.

## The `if` family is asymmetric

The `if` path is where many false intuitions come from.

## One arm unreachable

When one arm is already `unreachable`, Binaryen can often sink into the one reachable arm.

Why that matters:

- no duplication into two live destinations
- no need for the strict “both arms must be ultra-pure” rule set
- conceptually closer to postponing work than to duplicating it

This is why some tests that would fail the general two-arm rules still optimize in the one-arm-unreachable subfamily.

## Both arms reachable

When both arms are reachable, the pass becomes much stricter.

Binaryen requires all of these at once:

- the `if` must not have a concrete result type
- the candidate segment must not transfer control flow
- no calls
- no other side effects
- no throws
- no mutable-global reads or writes
- no memory or table reads or writes
- no default-mode trap-sensitive operations
- at least one arm must really use the value

So the real question is not:

- “is this expression pure enough in general?”

It is:

- “is this entire candidate suffix pure enough for the **two-arm** `if` rewrite Binaryen actually knows how to do?”

That is a much narrower question.

## Why “used after the `if`” matters so much

Several negative tests are easiest to understand through this rule.

If the value is still used after the `if`, then sinking it into only one arm or only the internal segments Binaryen currently models would strand another real use.

So even a perfectly pure arithmetic expression may stay in place because the use topology is wrong.

That is not a missed optimization by accident.
It is the real contract.

## Barrier families you should expect

## Local barriers

- `local.set` to the same local can invalidate the candidate story.
- Reads that must still work after the separator can keep the value in place.
- This is one reason `code-pushing` and later local-cleanup passes are separate passes.

## Control-flow barriers

- Branch transfers and non-linear execution break the cheap local reasoning the pass depends on.
- The generic segment family only handles the structured target-segment cases it explicitly models.

## Side-effect barriers

- calls
- visible side effects
- throws
- mutable-global traffic
- table traffic
- memory traffic

These matter most in the strict two-arm `if` family, where Binaryen refuses to duplicate them into two live arms.

## Trap barriers

Under default settings, trap-sensitive operations are a barrier for the strict two-arm `if` path.

The shipped option-specific tests show that this is not fixed forever. Binaryen deliberately supports looser modes such as:

- `--ignore-implicit-traps`
- `--traps-never-happen`

The durable lesson is:

- the barrier model is partly **pass-option-sensitive**

## GC barriers and GC positives

GC operations are not automatically barriers.

The `code-pushing-gc.wast` tests show that operations like:

- `struct.get`
- `array.get`
- `ref.cast`
- `ref.as_non_null`

can participate when the effect model allows it.

But control-sensitive ref operations and ref-typed contexts are also exactly where type and trap mistakes get easier to make, which is why the tests are valuable.

## EH barriers

The `code-pushing-eh.wast` tests exist because EH is one of the easiest places to make an unsound motion pass.

A good practical rule is:

- if `try` / `catch` / `pop` / `throw` structure matters to when a value exists or when an effect becomes visible,
- expect `code-pushing` to be conservative unless the exact shape is explicitly supported

## The heuristic barrier: not worth it

Even a semantically legal move can still be rejected because the pass’s local `benefit > cost` test says the duplication is not worthwhile.

That matters especially in:

- loops
- tiny expressions
- shapes where the pushed code would still execute on most paths anyway

This is one of the biggest reasons a manual “that looks sinkable” intuition can disagree with actual Binaryen behavior.

## Porting checklist for this page’s topic

If Starshine ports `code-pushing`, this page’s core contract becomes:

1. preserve the contiguous-suffix model
2. preserve invalidation while scanning, not only at rewrite time
3. keep one-arm-unreachable and two-arm-reachable `if` logic separate
4. preserve use-after-separator checks
5. preserve option-sensitive trap behavior
6. preserve the local heuristic gate
7. preserve EH conservatism explicitly

If any of those are weakened, the result may still look like “code motion,” but it will not be the same pass.

## Source strength note

- The contiguous-suffix, invalidation, `if`, and heuristic story above comes directly from `CodePushing.cpp`.
- The trap-option discussion is partly grounded in the dedicated shipped test files and partly in the visible effect-analysis contract. I did not fully line-trace every option constructor path in `effects.h` in this run, so that part should be treated as a well-supported implementation inference rather than a fully exhaustively line-anchored audit.

## Sources

- [`../../../raw/binaryen/2026-04-22-code-pushing-primary-sources.md`](../../../raw/binaryen/2026-04-22-code-pushing-primary-sources.md)
- [`../../../raw/research/0258-2026-04-22-code-pushing-primary-sources-and-starshine-followup.md`](../../../raw/research/0258-2026-04-22-code-pushing-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0115-2026-04-20-code-pushing-binaryen-research.md`](../../../raw/research/0115-2026-04-20-code-pushing-binaryen-research.md)
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/CodePushing.cpp>
- Binaryen `version_129` effects helpers: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
- Binaryen `version_129` lit tests:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing_into_if.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing_ignore-implicit-traps.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing_tnh.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing-gc.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing-eh.wast>
