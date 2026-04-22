---
kind: concept
status: supported
last_reviewed: 2026-04-22
sources:
  - ../../../raw/binaryen/2026-04-22-once-reduction-primary-sources.md
  - ../../../raw/research/0138-2026-04-20-once-reduction-binaryen-research.md
  - ../../../raw/research/0256-2026-04-22-once-reduction-primary-sources-and-code-map-followup.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./parity.md
  - ../memory-packing/index.md
  - ../global-refining/index.md
---

# `once-reduction`: dominance, propagation, and cycle safety

## Why this page exists

The easiest way to misunderstand `once-reduction` is to imagine one of two wrong extremes:

- a tiny peephole that only removes literally adjacent repeated `call $once`
- a broad whole-program theorem prover that knows every once-callee has fully completed once its bit was set

The real Binaryen pass is in between.

This page focuses on the part that makes that possible:

- dominated-path facts
- conservative call-summary propagation
- why after-merge shapes stay narrower than they first look
- why trivial wrapper cleanup must respect cycles

## The central question

Ask this question, not the pass name:

- “is this specific once-bit definitely already nonzero on every path Binaryen is willing to prove reaches here?”

If the answer is yes, a later guarded direct call or later redundant write can disappear.
If the answer is no, Binaryen keeps the code.

That is the personality of the pass.

## What domination contributes

`OnceReduction.cpp` builds a CFG and a dominator tree for each function.
The optimizer then walks blocks in reverse postorder and seeds each block's fact set from its **immediate dominator**.

In plain language:

- if block A must execute before block B, facts from A can flow into B
- if control merely *might* have come from A or from some sibling block, Binaryen does not automatically merge those facts today

That is why the pass is stronger than a local adjacency peephole but weaker than full all-path dataflow.

## Why after-`if` shapes stay conservative

Suppose both arms of an `if` call the same once function:

```wat
(if (local.get $cond)
  (then (call $once))
  (else (call $once)))
(call $once)
```

A beginner might expect the call after the `if` to vanish.
The shipped lit file says it does not.

Why:

- current Binaryen does not intersect all predecessor facts at the merge
- it mostly trusts facts inherited through immediate dominators and straight-line accumulation

So the real rule is:

- “both branches look equivalent to me” is not enough here
- Binaryen wants the simpler dominated-path proof it actually implements

## Why loops split into easy and hard cases

### Easy loop case: unconditional once call in the loop body

If the loop body contains a direct unconditional `call $once`, then later code in the same dominated region can often treat the once-bit as set.
That is why Binaryen can nop later repeated calls inside the loop body, and sometimes after the loop, in the positive lit cases.

### Hard loop case: only a conditional once call in the loop body

If the loop only *might* call the once function, then Binaryen cannot safely assume the once-bit is set after the loop.
The lit file keeps the first post-loop call alive in exactly that situation.

So the distinction is not “is there a loop?”
It is:

- “did this loop body provide a dominated guaranteed-set fact?”

## What call-summary propagation really means

The pass keeps per-function summary sets of once-bits that are definitely set by calling that function, according to the conservative analysis it has today.
Then callers union those facts in when they see a direct call.

That enables straight-line chains like:

- `A -> B -> C -> D -> once`

where `A` later learns that its earlier `call B` was enough to make a later `call once` redundant.

This is a real whole-module effect of the fixed-point loop.
It is one of the reasons `once-reduction` is a module pass instead of a pure per-function peephole.

## Important correction: the summary is not “callee fully completed”

This is the most important thing to get right.

A once function sets its once-bit at the beginning of its body, before the payload runs.
So from “we entered once function X” we can often conclude:

- X's own bit is nonzero now

But we cannot always conclude:

- every other once function that X might call has already completed its whole payload

That stronger claim would be wrong in cycle-heavy or reentrant-looking shapes.

## Why the dangerous triple loop is really dangerous

The official triple-loop test freezes exactly this issue.
Conceptually, it looks like three once functions that call one another and also perform an import-side effect afterward.

The tempting, but wrong, optimization would be:

- “if calling `$once.1` implies `$once.2` is already set, then I can remove my later direct `call $once.2`”

The problem is ordering.
Because the once-bit is set before the payload runs, a partially-entered once function can make its bit true without having reached its own later side effects yet.
Removing the later direct call can therefore reorder observable imported effects.

So the safe rule is:

- entering another once function is not the same thing as proving its whole payload happened before now

The official triple-loop comments explain that with an explicit side-effect order example.

## What `optimizeOnceBodies(...)` is really allowed to simplify

At the end, Binaryen performs a tiny body cleanup on once functions themselves.
The important case is a trivial wrapper:

```wat
(func $foo
  (if (global.get $foo$once) (then (return)))
  (global.set $foo$once (i32.const 1))
  (call $bar_once))
```

Binaryen may turn that into:

```wat
(func $foo
  (call $bar_once))
```

But only when that is the **entire** payload story.
If `$foo` did anything after calling `$bar_once`, removing the guard would be wrong because the later work would no longer be protected against repeated execution.

## Why cycle safety needs its own guard

Wrapper cleanup sounds local, but it is not.
If Binaryen removed the early-exit logic from every node in a cycle like:

- `A -> B -> A`

then the cycle could become infinite when entered.

That is why `optimizeOnceBodies(...)` tracks `removedExitLogic`.
The pass iterates functions deterministically and refuses to remove a wrapper's guard when doing so would stack on top of an already-simplified cycle partner.

The practical rule is:

- trivial wrapper cleanup is safe only if at least one relevant guard remains where a risky cycle needs it

## Self-recursion is easier than a multi-node cycle

A self-recursive once function is a special positive case.

Why it works:

- the function sets its own once-bit first
- the recursive call immediately sees that bit already set
- so the recursive direct call itself becomes `nop`

That is simpler than the multi-node wrapper-cycle story because there is no separate partner whose guard removal could create an infinite ping-pong.

## Where idempotent annotations fit in

Upstream also supports no-param/no-result functions annotated:

- `@binaryen.idempotent`

The pass models them by assigning fake once-global names.
That means they participate in the same call-elimination propagation machinery.

But they are still limited:

- params and results are not supported
- fake-global functions do not participate in the real-global body cleanup that expects an actual module global to exist

So idempotent support is a narrow extension of the same framework, not a separate general analysis.

## Why the debug log says `running nested passes`

The saved Binaryen debug log shows `once-reduction` followed by `running nested passes`.
That can look like a scheduler-level rerun signal.
Here it really means:

- the outer module pass internally runs helper passes such as the `Scanner` and repeated `Optimizer`

That is useful to remember because it explains why a pass that appears only once in the top-level schedule still behaves like a small multi-phase analysis internally.

## What a future Starshine port must preserve

A future strict-parity implementation must keep these durable facts explicit:

- domination is the main proof vehicle here
- current Binaryen does not do broad all-predecessor merge reasoning
- call-summary propagation is conservative and must not be over-read as full payload completion
- triple-loop / cycle ordering safety is real, not a theoretical edge case
- trivial wrapper cleanup needs deterministic cycle protection
- self-recursive once calls are safe to fold in ways some multi-node cycles are not
- idempotent annotations extend the same once-bit framework, but only narrowly

## Freshness note

The 2026-04-22 raw primary-source capture rechecked the official `version_129` release page plus the current `main` `OnceReduction.cpp` and dedicated `once-reduction.wast` surfaces, and did not surface a new teaching-relevant drift in the dominance, summary-propagation, or wrapper-cycle rules described here.
