---
kind: concept
status: supported
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0115-2026-04-20-code-pushing-binaryen-research.md
related:
  - ./index.md
  - ./segment-selection-and-barriers.md
  - ./wat-shapes.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
---

# Binaryen `code-pushing` Strategy

## Upstream source rule

- Use Binaryen `version_129` as the current source oracle for this pass.
- The core implementation is `src/passes/CodePushing.cpp`.
- Scheduler placement comes from `src/passes/pass.cpp` and the after-inlining helper in `src/passes/opt-utils.h`.
- The key helper contract for movement safety comes from `src/ir/effects.h`.
- The shipped behavior examples come from these lit tests:
  - `test/lit/passes/code-pushing.wast`
  - `test/lit/passes/code-pushing_into_if.wast`
  - `test/lit/passes/code-pushing_ignore-implicit-traps.wast`
  - `test/lit/passes/code-pushing_tnh.wast`
  - `test/lit/passes/code-pushing-gc.wast`
  - `test/lit/passes/code-pushing-eh.wast`

Primary source URLs:

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/CodePushing.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing_into_if.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing_ignore-implicit-traps.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing_tnh.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing-gc.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing-eh.wast>

## High-level intent

Binaryen uses `code-pushing` to take work from a common prefix and sink it into control-dependent regions where it is actually needed.

That sentence is true but incomplete.

The actual implementation is deliberately narrow.

It is not:

- arbitrary CFG-wide sinking
- generic loop motion in reverse
- generic CSE
- generic duplication of every pure expression under every profitable-looking branch

Instead, the real `version_129` contract is:

- scan one block at a time
- track a **contiguous** candidate suffix of pushable expressions
- look at the next structured control-flow separator
- clone some suffix of that candidate region into specific downstream segments or `if` arms
- only do it when effect, use, type, and heuristic checks all pass

## The pass in one table

| Phase | What Binaryen does | Why it exists |
| --- | --- | --- |
| Post-walk inner structure first | Visit children before parents | Outer opportunities depend on inner shapes already being simplified |
| Scan a block | Track `pushable`, `values`, and `neededByBlock` while walking children left-to-right | Keep the candidate region cheap and structured |
| Invalidate candidates | Use effect checks to remove candidates that can no longer move past the next child | Preserve ordering, side effects, and trap semantics |
| Find sink targets | Use `BranchSeeker` for generic branchy shapes or `optimizeIntoIf(...)` for `if` | Separate the two main rewrite families |
| Check profitability | Compare local `benefit` and `cost` before rewriting | Avoid code-growth rewrites that upstream deliberately skips |
| Rewrite | Clone the chosen suffix into target segments / arms with `Pusher` and remove the old copy | Make execution more path-specific |
| Repair | Run `ReFinalize` on the changed region | Restore correct outer types and structure |

## Phase 1: function-parallel post-walk

`CodePushing` reports `isFunctionParallel() == true`, so Binaryen treats it as a per-function pass that can run across functions in parallel.

Within each function, the pass is a post-walk.

That choice is important:

- inner blocks and `if`s are considered before outer ones
- the outer scan sees the already-updated child shapes
- opportunities can therefore emerge after deeper regions have already been simplified

A faithful port should preserve that traversal direction instead of treating it as an incidental implementation detail.

## Phase 2: candidate collection is block-local and contiguous

The heart of the pass is the block scan.

Binaryen keeps a current region of expressions that are still candidates for pushing. The source uses containers like:

- `pushable`
- `values`
- `neededByBlock`

The durable mental model is:

- `pushable`
  - the current contiguous region of expressions we might sink
- `values`
  - tracked candidate values from that region that are still movable past later children
- `neededByBlock`
  - bookkeeping for whether a value must remain available outside the immediate place we hope to sink into

This is the first big “what the pass sounds like vs what it really does” correction.

Binaryen is not gathering arbitrary expressions from all over a block.
It is always working with a **suffix** of a **contiguous** region.

## Phase 3: invalidation is the real correctness engine

Every time the next child in the block arrives, Binaryen uses effect information to decide whether any currently tracked candidate values can still move past it.

If a child invalidates some candidate values, those values are removed from `values`. If that invalidation breaks the candidate region badly enough, the pass resets the current segment boundary.

That means the block scan is always maintaining a local truth of the form:

> “Given everything we have seen so far, this suffix is still movable past the next interesting control-flow node.”

That is why the pass is much safer than a naive “duplicate pure code under branches” rewrite.

## Phase 4: the generic branchy family uses `BranchSeeker`

For non-`if` control-flow structures, Binaryen uses a helper inside `CodePushing.cpp` named `BranchSeeker`.

Its job is to look at the following control-flow child and figure out which downstream segments can receive the pushed suffix.

Important durable takeaways:

- the pass reasons about **structured segments**, not arbitrary CFG nodes
- branches and fallthroughs are both part of the target story
- the helper cares about how branches relate to the immediate child-block structure it is inspecting
- the pass is still local and structural even when it handles `br_table`-style shapes

So the generic family is broader than just `if`, but still much narrower than arbitrary region sinking.

## Phase 5: `optimizeSegment(...)` chooses a suffix and measures it

Once `BranchSeeker` has exposed candidate target segments, `optimizeSegment(...)` walks backward over the current `pushable` region and tries possible suffix boundaries.

For each suffix candidate, it checks:

1. is the suffix still legal for every target segment?
2. do the relevant target segments actually use what the suffix computes?
3. what is the local size / execution tradeoff if we duplicate that suffix there?

The source comments around the `benefit` / `cost` calculation are worth preserving in plain English.

### `full`

- the total estimated cost of the full pushed suffix

### `cost`

- the duplication cost after discounting cases where the original copy disappears because the control-flow already branches all the way out

### `benefit`

- the estimated win from shrinking / simplifying the surrounding control-flow region

### `executed`

- a penalty term so the pass does not overestimate wins in shapes where sinking might still make the work run often, especially in loops

The rewrite only happens when:

- `benefit > cost`

That heuristic is not a side detail.
It is part of the Binaryen contract.

## Phase 6: `optimizeIntoIf(...)` is stricter and asymmetrical

The direct `if` path deserves its own summary because it behaves differently from the generic segment path.

## Case A: one arm is `unreachable`

If one arm is already `unreachable`, Binaryen can sink the suffix into the one reachable arm.

Why this case is easier:

- there is no duplication into two live arms
- the transform is closer to postponing execution until the one path that actually continues

This is why some shapes that would fail the strict two-arm rules can still pass here.

## Case B: both arms are reachable

If both arms are reachable, Binaryen is intentionally much stricter.

Key source-enforced facts:

- the `if` must not have a concrete result type
- the candidate segment must not transfer control flow
- no calls
- no side effects
- no throws
- no reads or writes of mutable globals
- no memory or table traffic
- no trap-sensitive operations under default safety settings
- at least one arm must actually use the pushed value

Then Binaryen can choose among:

- push into both arms
- push only into `then`
- push only into `else`

And when the rewritten arm structure becomes statement-like, it may insert `drop(...)` to preserve valid shape.

That makes the `if` path a good example of a pass whose name is much broader than its real implementation.

## Phase 7: result-use checks gate what can move

A critical source-level nuance is that the pass repeatedly checks whether the result of the candidate expression is used in the destination segment or arm.

That means a seemingly pure candidate may still stay put because:

- the value is used after the control-flow separator
- only part of the downstream structure consumes it in a way this pass does not model
- sinking into just one destination would strand another necessary use

This is the main reason some “obvious” pure examples do not rewrite in the shipped tests.

## Phase 8: `Pusher` performs structural rewriting

Once Binaryen decides to rewrite, the helper `Pusher` does the actual cloning and insertion.

The durable takeaway is not the helper name. It is the kind of mutation the pass performs.

`code-pushing` can change:

- block child lists
- the contents of `then` / `else`
- whether an empty or singleton block still needs to exist
- whether a surrounding structure now needs `drop(...)`
- the outer types of the affected expressions

So a faithful port needs real structure-editing machinery, not just expression replacement.

## Phase 9: `ReFinalize` is mandatory

After rewriting, `CodePushing.cpp` runs `ReFinalize` on the changed region.

That is mandatory because the pass can change:

- whether a block still has a concrete result
- whether an `if` is still effectively statement-like or value-like
- where ref-typed values are produced
- how `unreachable` interacts with the surrounding region

A port that skips the refinalization step will not be an honest Binaryen port.

## Helper dependency map

## `EffectAnalyzer` and `ShallowEffectAnalyzer`

These helpers are the pass’s safety boundary.

They are used to:

- invalidate candidate values during scanning
- reject impure two-arm `if` candidates
- respect trap-sensitive and option-sensitive ordering rules

If you want only one helper family to keep in your head while reading this pass, keep this one.

## `BranchSeeker`

Pass-local structured target finder for generic branchy shapes.

## `Pusher`

Pass-local rewriter that clones the chosen suffix into destination segments / arms.

## `Builder`

Used to construct replacement `if`, block, and `drop(...)` shapes.

## `ReFinalize`

Restores valid types after rewrite.

## `opt-utils.h`

Explains why the pass reappears in nested reruns after optimizing passes.

## Scheduler placement is part of the meaning

In `pass.cpp`, Binaryen schedules `code-pushing` in the early-mid function pipeline, after `precompute` and before `tuple-optimization` plus `simplify-locals-nostructure`.

That placement says a lot about intended use:

- earlier peepholes and constant folding have already simplified obvious prefixes
- `code-pushing` can now make the remaining branch-local work more local
- tuple cleanup then sees a better-shaped body
- early local cleanup follows that new structure

The repo’s tuple docs already rely on this exact neighborhood for honest scheduler parity.

## Why the saved nested reruns matter

`opt-utils.h` shows that after-inlining cleanup prepends `precompute-propagate` and then reruns the default function pipeline on touched functions.

That is why the saved generated-artifact `-O4z` debug log contains repeated:

```text
precompute-propagate -> code-pushing -> tuple-optimization
```

subsequences after the top-level pass list has already advanced.

A Starshine scheduler that models only the top-level slot but ignores the nested rerun sites will still miss part of real Binaryen behavior.

## What the pass does **not** do

A future Starshine port should avoid accidentally broadening this pass beyond upstream behavior.

`code-pushing` does **not**:

- solve arbitrary CFG code sinking
- move arbitrary disjoint expressions from one block into another
- ignore use-after-branch issues
- treat every pure `if` prefix as sinkable
- skip profitability checks
- replace tuple optimization or local cleanup
- make trap sensitivity irrelevant under default settings

The real Binaryen contract is structured, local, and heuristic-gated.

## The most important porting lessons

If Starshine ports `code-pushing`, preserve these facts first:

1. function-parallel post-walk structure
2. contiguous block-suffix model
3. separate generic-segment and `if`-specific logic
4. effect-based invalidation while scanning
5. strict two-arm `if` purity rules
6. one-arm-unreachable special case
7. result-use checks before motion
8. local `benefit > cost` gating
9. structural rewriting plus `ReFinalize`
10. exact scheduler placement before `tuple-optimization` / `simplify-locals-nostructure`
11. nested reruns under optimizing passes
12. dedicated GC / EH / trap-option test coverage

Those are the durable upstream-level truths.

## Sources

- [`../../../raw/research/0115-2026-04-20-code-pushing-binaryen-research.md`](../../../raw/research/0115-2026-04-20-code-pushing-binaryen-research.md)
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/CodePushing.cpp>
- Binaryen `version_129` scheduler source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Binaryen `version_129` after-inlining helper: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- Binaryen `version_129` effects helpers: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
- Binaryen `version_129` lit tests:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing_into_if.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing_ignore-implicit-traps.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing_tnh.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing-gc.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing-eh.wast>
