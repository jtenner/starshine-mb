---
kind: concept
status: supported
last_reviewed: 2026-04-22
sources:
  - ../../../raw/binaryen/2026-04-22-merge-blocks-primary-sources.md
  - ../../../raw/research/0255-2026-04-22-merge-blocks-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0111-2026-04-20-merge-blocks-binaryen-research.md
related:
  - ./index.md
  - ./wat-shapes.md
  - ./starshine-hot-ir-strategy.md
  - ../../no-dwarf-default-optimize-path.md
---

# Binaryen `merge-blocks` Strategy

## Upstream source rule

- Use Binaryen `version_129` as the current source oracle for this pass.
- The core implementation is `src/passes/MergeBlocks.cpp`.
- The late-slot placement is confirmed by the saved generated-artifact `-O4z` audit and by Binaryen's scheduler source in `src/passes/pass.cpp`.
- The immutable primary-source manifest for this dossier is [`../../../raw/binaryen/2026-04-22-merge-blocks-primary-sources.md`](../../../raw/binaryen/2026-04-22-merge-blocks-primary-sources.md).
- On 2026-04-22, the reviewed official Binaryen `version_129` release page showed publish date **2026-04-01**.

Primary source URLs:

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MergeBlocks.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/branch-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/branch-utils.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm/wasm-traversal.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-blocks.wast>

## High-level intent

Binaryen's `merge-blocks` pass is trying to remove a very specific kind of structural noise:

- a block whose final child is another block
- where the child is only acting as a wrapper around the parent's tail

It is not trying to solve arbitrary control-flow simplification.

A good beginner summary is:

- flatten only the tail nested block
- only when branch targets, result types, and effects still mean the same thing afterwards

## The pass in one table

| Phase | What Binaryen checks or does | Why it exists |
| --- | --- | --- |
| Prescan | Run `ProblemFinder` over the whole function | Avoid the shadowed same-name descendant-branch family that can make branch retargeting ambiguous |
| Candidate selection | Only consider a `block` whose last item is also a `block` | Tail children are the only easy flattening case |
| Naming gate | Child must be unnamed or share the parent's name | Avoid general arbitrary-label retargeting |
| Type gate | Parent and child block types must match | Preserve branch payload and result typing |
| Effect gate | Named children must satisfy `!EffectAnalyzer::invalidates(child)` | Prevent retargeted branches from skipping observable work |
| Rewrite | Splice the child list into the parent list | Delete the redundant wrapper |
| Repair | `ReFinalize().walk(curr)` | Recompute types after the structural rewrite |

## Phase 1: whole-function prescan with `ProblemFinder`

This is the most important surprising detail in the implementation.

Before Binaryen performs any merges, it runs a separate post-order walker called `ProblemFinder`.

The source comment explains the danger it is looking for:

- Binaryen removes the inner block first
- only then does it update branches
- in the bad same-name shadow family, once the inner block is gone, some branches that used to target the inner block can become indistinguishable from branches that target the outer block
- a later branch rewrite can then update **too much**

The crucial policy choice is the bailout strength:

- Binaryen does not skip only one candidate
- it skips the **entire function** if `ProblemFinder` finds that hazard family anywhere

That means a future Starshine port should not model this as a tiny local guard inside only the final splice helper. The upstream behavior is stronger than that.

## Phase 2: only tail nested blocks are candidates

Inside `optimizeBlock(...)`, Binaryen immediately rejects:

- empty blocks
- blocks whose last child is not another block

This is why `merge-blocks` should not be described as a generic flatten pass.

Binaryen only knows how to safely flatten a nested block when that child is at the parent's tail.

Why tail position matters:

- if the child ends the parent, the child and parent share the same continuation point
- that makes some branch retargeting and wrapper deletion safe
- a non-tail child would leave later siblings whose reachability could change after flattening

## Phase 3: the naming gate is deliberately narrow

Binaryen then requires one of these:

- the child block has **no name**, or
- the child block's name equals the parent block's name

This is a very strong statement about upstream intent.

Binaryen is explicitly **not** doing the general problem:

- merge a named `$child`
- then rewrite arbitrary branches from `$child` to some different `$parent`
- while preserving all control-flow semantics

Instead, it only accepts the easy cases:

### Unnamed child

- no branch can target it by name
- so the structural rewrite is much simpler

### Same-name child

- the child is already pretending to be the same exit label family as the parent
- that makes flattening plausible, but only after the shadow-hazard prescan and the other gates pass

## Phase 4: type equality is mandatory

Binaryen next requires:

- `curr->type == child->type`

The source comment gives the reason directly:

- if the types differ, changing the branch target can also change the branch's value contract

This is the easiest correctness rule to port faithfully:

- never flatten if the parent and child block result types differ

For beginner readers, the safe mental model is:

- the parent and child must promise the same number and kind of results
- otherwise deleting one wrapper can change what a branch is expected to produce

## Phase 5: named children must not invalidate effects

When the child has a name, Binaryen adds another gate:

- `!EffectAnalyzer::invalidates(child)`

The source comment makes the reason unusually explicit:

- because the child is at the end of the parent, branches to the child can be retargeted to the parent
- but if the child body has observable side effects, those effects could disappear if a retargeted branch now skips the child body entirely

This is the important beginner version:

- if flattening could make a branch bypass the child's work, that work must not matter observably

Important nuance:

- unnamed children skip this gate
- that is not because effects suddenly stop mattering in general
- it is because unnamed blocks are not label targets, so the named-branch retargeting hazard does not arise in the same way

## Phase 6: the actual rewrite is tiny

Once all gates pass, Binaryen does only a few mechanical steps:

1. run `BranchUtils::operateOnScopeNameUses(curr, ...)`
2. remove the tail child from the parent list
3. append the child's list items directly into the parent list
4. run `ReFinalize().walk(curr)`
5. mark the pass as having optimized something

This is one of those cases where a short source file is deceptive.

The file is short because Binaryen has already pushed the hard parts into helpers:

- branch-scope traversal utilities
- effect invalidation analysis
- post-rewrite type repair

## Why `ReFinalize` is non-optional

A common porting mistake would be to think:

- “I only changed structure, not value instructions, so maybe I can skip type repair.”

Binaryen does not do that.

After every successful splice, it refinalizes the rewritten block.

That is upstream evidence that the pass treats type repair as part of the main correctness contract, not as optional cleanup.

## What `BranchUtils` contributes

The relevant Binaryen helper here is not a magical whole-function relabeler.

The important contract is smaller:

- operate on branch-relevant names in the current scope
- descend through unnamed nested scopes where those uses still belong to the current branch domain

That matches the narrowness of `merge-blocks` itself.

The pass is small because it avoids the general branch-rewrite problem.

My current reading of the source is:

- the branch helper call is mostly a scoped safety belt around an already narrow transform
- the real semantic boundary is still the candidate gating, especially the same-name hazard prescan and the named-child effect barrier

That is an inference from the current implementation shape, not a line-comment from Binaryen.

## What the pass does **not** do

A future Starshine port should avoid accidentally growing this pass beyond Binaryen's actual scope.

`merge-blocks` does **not**:

- flatten arbitrary nested blocks anywhere in a parent list
- solve arbitrary named-child retargeting
- repair control flow for non-tail children
- replace `remove-unused-brs`
- replace `flatten`
- replace `vacuum`
- create new blocks or branches to make merging possible
- perform general CFG simplification

It only flattens already-safe tail nested blocks.

## Why the pass is late and repeated

The saved `-O4z` audit shows the top-level late cluster:

- `code-folding`
- `merge-blocks`
- `remove-unused-brs`
- `remove-unused-names`
- `merge-blocks`
- `precompute-propagate`
- `optimize-instructions`
- `heap-store-optimization`
- `rse`
- `vacuum`

That ordering is a clue to the pass's intended role.

### First late `merge-blocks`

After `code-folding`, duplicate-region cleanup can leave nested wrapper blocks.

A first `merge-blocks` run flattens easy wrappers before the next branch cleanup.

### Second late `merge-blocks`

After `remove-unused-brs` and `remove-unused-names`, more wrappers can become trivially mergeable.

A second run catches those newly exposed shapes.

So the repeated scheduling is not accidental duplication. It is part of the cleanup strategy.

## The most important porting lessons

If Starshine ports `merge-blocks`, the implementation should preserve these upstream-level facts first:

1. whole-function shadow-hazard bailout
2. tail-child-only matching
3. unnamed-or-same-name child restriction
4. parent-child block type equality
5. named-child effect invalidation barrier
6. post-rewrite type repair
7. repeated late-slot scheduling rather than one one-off flatten step

Those are the real Binaryen contracts. Everything else is detail.

## Sources

- [`../../../raw/binaryen/2026-04-22-merge-blocks-primary-sources.md`](../../../raw/binaryen/2026-04-22-merge-blocks-primary-sources.md)
- [`../../../raw/research/0255-2026-04-22-merge-blocks-primary-sources-and-starshine-followup.md`](../../../raw/research/0255-2026-04-22-merge-blocks-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0111-2026-04-20-merge-blocks-binaryen-research.md`](../../../raw/research/0111-2026-04-20-merge-blocks-binaryen-research.md)
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MergeBlocks.cpp>
- Binaryen `version_129` scheduler source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Binaryen `version_129` branch utilities: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/branch-utils.h>
- Binaryen `version_129` branch-utility implementation: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/branch-utils.cpp>
- Binaryen `version_129` effects helpers: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
- Binaryen `version_129` traversal / refinalize helpers: <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm/wasm-traversal.h>
- Binaryen `version_129` lit tests: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-blocks.wast>
