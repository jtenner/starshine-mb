---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-inlining-optimizing-current-main-implementation-test-map.md
  - ../../../raw/binaryen/2026-04-23-inlining-optimizing-primary-sources.md
  - ../../../raw/research/0361-2026-04-25-inlining-optimizing-current-main-and-test-map.md
  - ../../../raw/research/0121-2026-04-20-inlining-optimizing-binaryen-research.md
  - ../../../raw/research/0271-2026-04-23-inlining-optimizing-primary-sources-and-starshine-followup.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../dae-optimizing/index.md
  - ../duplicate-function-elimination/index.md
  - ../inlining/index.md
---

# `inlining-optimizing`: planning, partial inlining, and reruns

This page focuses on the parts of Binaryen `inlining-optimizing` that are easiest to misunderstand. For the file/test map and current-main no-drift bridge, see [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md).

This page focuses on:

- why whole-module planning matters
- what keeps a callee alive even after some inlining
- why reviewed `version_129` chosen actions are still direct-call based
- how partial inlining differs from full inlining
- why the optimizing rerun is part of the pass contract

## The big beginner warning

If you summarize the pass as:

- “inline every small function”

you will miss most of the implementation.

The real story is closer to:

- “plan from whole-module call and use facts, pick one of several inline actions, preserve roots and `ref.func` uses, sometimes split a structured top-of-function region first, then clean up the touched functions immediately.”

## 1. Root and escape conservatism

A function may be profitable to inline at one callsite and still be a function Binaryen must keep alive.
That happens because the planner distinguishes:

- chosen rewriteable call uses
- and surviving observable uses that still require the boundary

### Exports are roots

If a function is exported, Binaryen assumes callers outside the currently scanned internal call graph may exist.
So even if all internal direct calls were inlined, the function boundary still matters.

### The start function is a root

The same logic applies to the module start function.
It is implicitly invoked by the runtime, so Binaryen must not treat it like an ordinary disposable private helper.

### `ref.func` uses keep the boundary alive

In reviewed `version_129`, `FunctionInfoScanner` counts `ref.func` uses in `refs`.
That means a function can inline into ordinary direct callers and still survive because explicit function-reference uses remain.

This is one of the most important reasons the pass is a whole-module planner instead of a local rewrite.

## 2. Why size heuristics are more than one threshold

Binaryen’s planner does not use only one flat “maximum inline size.”
The pass combines several ideas.

### Family A: always-inline tiny helpers

There is a tiny-function fast path.
If the function is extremely small and not blocked by the major hazards, Binaryen is happy to inline it aggressively.

### Family B: single-use helpers get extra slack

A helper used only once gets a more generous size budget.
This is important because keeping a one-use helper around buys little reuse, while removing the call overhead may still be a good trade.

### Family C: call overhead counts as recoverable size

Inlining removes the call instruction and its surrounding overhead.
So the planner reasons about **net** size, not only raw callee body size.

### Family D: shrink-vs-speed policy changes willingness

The pass is still an optimizer, not a proof engine.
Its willingness to inline depends partly on whether the surrounding run emphasizes shrinkage or more general optimization.
So inline decisions are policy-sensitive, not hardwired to one universal cutoff.

## 3. Tail calls are not ordinary small-helper structure

A very common mistake is to think:

- “if the callee is tiny, just inline it”

But Binaryen treats tail-call-containing functions as a special negative family.
Why that matters:

- tail calls are not just another AST child
- they imply different control-flow and size-growth considerations
- so the standard `worthFullInlining(...)` path bails out early

A future port must preserve that conservatism unless it has an equally strong replacement rule.

## 4. Recursive growth is a separate hazard

Self-recursion is another place where naive inline intuition fails.
Even if one inline step looks locally profitable, repeatedly growing a self-recursive function is a bad direction.
So the planner has an explicit recursive-growth guard.

Beginner takeaway:

- inline profitability is not only “callee size versus threshold”
- it is also “will this make the surrounding function graph grow in a bad way?”

## 5. Reviewed `version_129` chosen actions are still direct-call based

This is the main correction this follow-up keeps explicit and that the 2026-04-25 implementation/test-map bridge rechecked against current `main`.
The file contains updater logic for `return_call_ref` and `return_call_indirect`, and the scanner tracks `ref.func` uses.
It is easy to overread that as “general precise ref-call selection.”

The safer source-backed summary is narrower:

- chosen inline actions are discovered from reachable direct `call` / `return_call` sites
- copied code may still contain `call_ref` / `return_call_ref` that the updater must repair
- `ref.func` still matters for roots and surviving uses
- but the reviewed `version_129` planner contract is not “choose arbitrary precise `call_ref` sites to inline”

That distinction is important enough to keep repeated in both the strategy and WAT-shape pages.

## 6. Partial inlining is a different strategy, not a fallback spelling

If full inlining is not chosen, Binaryen may still partially inline.
That does **not** mean:

- “inline half the callee body somehow”

It means something more structured:

1. find a profitable top-of-function region in a function
2. split that region into a helper function
3. inline the new helper where the original whole function was too large or too mixed

### What kinds of regions matter

The reviewed pass only supports two narrow families:

- Pattern A: a function beginning with `if (simple) return;` followed by heavier later work
- Pattern B: a short run of top-level `if`s with simple conditions, no else arms, and tight final-item/local-dependency rules

This is a very important scope rule.
Partial inlining is not arbitrary CFG cloning.
It is structured region splitting under tight constraints.

### Why splitting can help even when full inlining does not

Imagine a function that is mostly large or shared, but begins with a tiny guard region.
Inlining the whole original function into every caller may be too expensive.
But splitting out that one guard region can create a new helper that *is* cheap enough to inline.

So partial inlining is really:

- “shrink the callable unit first, then inline the smaller unit”

## 7. Deleting the callee is conditional, not automatic

Another easy misunderstanding is:

- “if the call was inlined, the callee disappears”

That is only sometimes true.
A callee can survive because of:

- export/start root status
- `ref.func` uses
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

### What the rerun can clean up

Inlining frequently creates fresh debris such as:

- newly obvious constants
- dead local traffic
- dead branches
- redundant casts
- duplicated tails that `code-folding` can now share
- extra block structure that `merge-blocks` can simplify
- redundant sets that `rse` can erase

Without the nested rerun, a port would still be missing important real Binaryen behavior.

## 9. Why the saved `-O4z` debug log matters

The repo’s saved generated-artifact log proves that the rerun is not just source-comment theory.
Between top-level `inlining-optimizing` and the next top-level `duplicate-function-elimination`, the saved log visibly contains repeated nested cleanup waves.
Repo-local counting over that interval finds:

- `5` nested `ssa-nomerge`
- `5` nested `code-folding`
- `10` nested `local-cse`
- `10` nested `merge-blocks`
- `15` nested `precompute-propagate`

So the nested rerun should be treated as part of the real pass contract, not as optional future polish.

## 10. The pass sits in a larger late boundary neighborhood

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
- later late-tail cleanup makes more sense once the function graph has settled somewhat

So a future Starshine port should not treat `inlining-optimizing` as a free-floating standalone pass.

## 11. A good mental model for future Starshine work

If you need one short planning summary, use this:

- scan first,
- keep roots and `ref.func` uses honest,
- pick between full inline, partial inline, or no-op,
- delete helpers only when all surviving uses allow it,
- then rerun `precompute-propagate` and the default function cleanup pipeline on the touched functions.

That is much closer to real Binaryen behavior than the simpler but misleading slogan:

- “inline small functions.”
