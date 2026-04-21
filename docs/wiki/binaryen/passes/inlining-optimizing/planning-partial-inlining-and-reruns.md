---
kind: concept
status: supported
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0121-2026-04-20-inlining-optimizing-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ../dae-optimizing/index.md
  - ../duplicate-function-elimination/index.md
---

# `inlining-optimizing`: planning, partial inlining, and reruns

This page focuses on the parts of Binaryen `inlining-optimizing` that are easiest to misunderstand:

- why whole-module planning matters
- what keeps a callee alive even after some inlining
- how partial inlining differs from full inlining
- what ref-based callsite reasoning actually means here
- why the optimizing rerun is part of the pass contract

## The big beginner warning

If you summarize the pass as:

- “inline every small function”

you will miss most of the implementation.

The real story is closer to:

- “plan from whole-module call and use facts, pick one of several inline actions, preserve roots and escaping references, sometimes split a structured region first, then clean up the touched functions immediately.”

## 1. Root and escape conservatism

A function may be profitable to inline at one callsite and still be a function Binaryen must keep alive.

That happens because the planner distinguishes:

- rewriteable call uses
- and surviving observable uses

## Exports are roots

If a function is exported, Binaryen assumes callers outside the currently scanned internal call graph may exist.

So even if all internal direct calls were inlined, the function boundary still matters.

## The start function is a root

The same logic applies to the module start function.

It is implicitly invoked by the runtime, so Binaryen must not treat it like an ordinary disposable private helper.

## Escaping references keep the boundary alive

A function used through function references or other non-easy-to-rewrite paths is not just “a small helper.”

The precise source-level details can vary by use shape, but the important durable lesson is:

- surviving non-call or broad indirect uses make the pass conservative

That is why a callee can inline into some direct callers while still remaining in the module.

## 2. Why size heuristics are more than one threshold

Binaryen’s planner does not use only one flat “maximum inline size.”

The pass combines several ideas.

## Family A: always-inline tiny helpers

There is a tiny-function fast path.

If the function is extremely small and not blocked by the major hazards, Binaryen is happy to inline it aggressively.

## Family B: single-use helpers get extra slack

A helper used only once gets a more generous size budget.

This is important because keeping a one-use helper around buys little reuse, while removing the call overhead may still be a good trade.

## Family C: call overhead counts as recoverable size

Inlining removes the call instruction and its surrounding overhead.

So the planner reasons about **net** size, not only raw callee body size.

This is why “callee seems bigger than the threshold” does not automatically mean “Binaryen will not inline it.”

## Family D: shrink-vs-speed policy changes willingness

The pass is still an optimizer, not a proof engine.

Its willingness to inline depends partly on whether the surrounding run emphasizes shrinkage or more general optimization.

So inline decisions are policy-sensitive, not hardwired to a single universal cutoff.

## 3. Tail calls are not ordinary callsites

A very common mistake is to think:

- “if the callee is tiny, just inline it”

But Binaryen treats tail-call-containing functions as a special negative family.

Why that matters:

- tail calls are not just another AST child
- they imply different control-flow and size-growth considerations
- so the standard “worth inlining” path bails out early

A future port must preserve that conservatism unless it has an equally strong replacement rule.

## 4. Recursive growth is a separate hazard

Self-recursion is another place where naive inline intuition fails.

Even if one inline step looks locally profitable, repeatedly growing a self-recursive function is a bad direction.

So the planner has an explicit recursive-growth guard.

Beginner takeaway:

- inline profitability is not only “callee size versus threshold”
- it is also “will this make the surrounding function graph grow in a bad way?”

## 5. Partial inlining is a different strategy, not a fallback spelling

If full inlining is not chosen, Binaryen may still partially inline.

That does **not** mean:

- “inline half the callee body somehow”

It means something more structured:

1. find a profitable call-containing region in a function
2. split that region into a helper function
3. inline the new helper where the original whole function was too large or too mixed

## What kinds of regions matter

`FunctionSplitter::FlexSplitter` is focused on structured shapes such as:

- `if`
- `br_if`
- `select`
- straight-line fragments with a clean split point

This is a very important scope rule.

Partial inlining is not arbitrary CFG cloning.
It is structured region splitting under tight constraints.

## Why splitting can help even when full inlining does not

Imagine a function that is mostly large or shared, but contains one small conditional path that calls a tiny helper.

Inlining the whole original function into every caller may be too expensive.
But splitting out that one conditional path can create a new helper that *is* cheap enough to inline.

So partial inlining is really:

- “shrink the callable unit first, then inline the smaller unit”

## 6. Precise ref-based callsites are not the same as generic indirect calls

The pass can reason about some `call_ref` and `return_call_ref` sites using `PossibleContents`.

That is helpful, but it is easy to overread.

The safe summary is:

- precise target knowledge can unlock ref-based inline opportunities
- broad or unknown target knowledge cannot

So the pass is not:

- “direct calls only”

but it is also not:

- “all indirect-style calls are okay once we feel lucky”

This middle ground is exactly the sort of rule a future Starshine port must preserve.

## 7. Deleting the callee is conditional, not automatic

Another easy misunderstanding is:

- “if the call was inlined, the callee disappears”

That is only sometimes true.

A callee can survive because of:

- export/start root status
- escaping or broad uses
- other remaining callsites
- other planner conservatism

So “inline” and “remove the original function” are related but not identical actions.

## 8. The optimizing rerun is what turns raw inlining into useful cleanup

After inlining, Binaryen runs `OptUtils::optimizeAfterInlining(...)` on the touched functions.

That helper:

1. prepends `precompute-propagate`
2. reruns the default function optimization pipeline
3. only on the functions that actually changed

This is exactly why the pass name is `inlining-optimizing` and not just `inlining-aggressive`.

## What the rerun can clean up

Inlining frequently creates fresh debris such as:

- newly obvious constants
- dead local traffic
- dead branches
- redundant casts
- duplicated tails that `code-folding` can now share
- extra block structure that `merge-blocks` can simplify
- redundant sets that `rse` can erase

Without the nested rerun, a port would still be missing important real Binaryen behavior.

## Why the saved `-O4z` debug log matters

The repo’s saved generated-artifact log proves that the rerun is not just source-comment theory.

Between top-level `inlining-optimizing` and the next top-level `duplicate-function-elimination`, the saved log visibly contains repeated nested cleanup waves.

Repo-local counting over that interval finds:

- `5` nested `ssa-nomerge`
- `5` nested `code-folding`
- `10` nested `local-cse`
- `10` nested `merge-blocks`
- `15` nested `precompute-propagate`

So the nested rerun should be treated as part of the real pass contract, not as optional future polish.

## 9. The pass sits in a larger late boundary neighborhood

The no-DWARF post-pass cluster is not random here.

The nearby ordering is:

- `dae-optimizing`
- `inlining-optimizing`
- `duplicate-function-elimination`
- `duplicate-import-elimination`
- `simplify-globals-optimizing`
- `remove-unused-module-elements`

That order makes practical sense:

- DAE and inlining both rewrite function boundaries and callsites
- duplicate-function cleanup benefits after those rewrites
- duplicate imports and simplified globals make more sense once the function graph has settled somewhat

So a future Starshine port should not treat `inlining-optimizing` as a free-floating standalone pass.

## 10. A good mental model for future Starshine work

If you need one short planning summary, use this:

- scan first,
- keep roots honest,
- pick between full inline, partial inline, or no-op,
- delete helpers only when all surviving uses allow it,
- then rerun the function cleanup pipeline on the touched functions.

That is much closer to real Binaryen behavior than the simpler but misleading slogan:

- “inline small functions.”
