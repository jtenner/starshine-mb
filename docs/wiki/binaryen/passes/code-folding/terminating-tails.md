---
kind: concept
status: supported
last_reviewed: 2026-06-05
sources:
  - ../../../raw/binaryen/2026-04-25-code-folding-current-main-recheck.md
  - ../../../raw/binaryen/2026-05-05-code-folding-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-22-code-folding-primary-sources.md
  - ../../../raw/research/0351-2026-04-25-code-folding-current-main-and-test-map.md
  - ../../../raw/research/0442-2026-05-05-code-folding-current-main-recheck.md
  - ../../../raw/research/0112-2026-04-20-code-folding-binaryen-research.md
  - ../../../raw/research/0257-2026-04-22-code-folding-primary-sources-and-starshine-followup.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
---

# Binaryen `code-folding` terminating tails

The 2026-05-05 current-main bridge rechecked the same owner and dedicated lit-test surfaces and did not find teaching-relevant drift in this subsystem. See [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md) for the owner-file and test-family map.

This page focuses on the part of `code-folding` that is easiest to misunderstand:

- Binaryen can share duplicated tails of `return`, `return_call*`, and `unreachable` paths
- it does that by building a new helper label block near the end of the function body

That is a different algorithm from the named-block / `if-else` tail folding family.

## The mental model

Imagine several control-flow paths in one function all end like this:

```wat
... same unique prefix A ...
(shared tail C)
(return)
```

and:

```wat
... same unique prefix B ...
(shared tail C)
(return)
```

Binaryen wants to keep only one copy of `C`, if moving `C` to one shared location at the end of the function is safe and worth the extra helper structure.

## What counts as a terminating tail

The pass records three families:

- `return`
- `return_call`, `return_call_indirect`, `return_call_ref`
- `unreachable`

The collection path is important:

- if the terminating instruction is the last child of a parent block, Binaryen stores it as a block-backed tail
- otherwise it stores a direct `Expression**` replacement pointer so it can still rewrite the function body correctly

That means this subsystem is not limited to neat block-wrapped endings.

## Why this is a separate algorithm

Expression-exit folding asks:

- “Do all tails to this expression exit share a suffix?”

Terminating-tail folding instead asks:

- “Is there some subset of function-terminating tails whose common suffix is worth merging at the end of the function body?”

That difference changes the search strategy.

## Search strategy

The core helper is:

- `optimizeTerminatingTails(tails, num = 0)`

where `num` means:

- how many trailing items are already known equal in this subset

The algorithm then:

1. removes tails already modified this iteration
2. removes tails that are too short to extend to depth `num + 1`
3. removes tails whose next candidate item has external break targets
4. hashes the next candidate item at depth `num`
5. groups equal items deterministically
6. recursively explores deeper equal suffixes first
7. only after deeper exploration fails does it ask whether the current depth is worth merging

Important beginner takeaway:

- the pass searches from the tail inward
- it is trying to find a profitable shared suffix, not a profitable whole-region duplicate

## Why external break targets are a hard bailout

For the next candidate item at depth `num`, Binaryen creates an `EffectAnalyzer` and checks:

- `hasExternalBreakTargets()`

If that returns true, the tail is removed from the exploration set.

This is how the pass avoids one of the nastiest invalid rewrites:

- code may look equal
- but if the moved code branches to a target outside itself,
- then hoisting it to the shared function-ending suffix can move it outside that target's scope

The `break-target-outside-of-return-merged-code` and `careful-of-the-switch` test families exist to make this concrete.

## Equality and deterministic grouping

At each depth, Binaryen hashes the candidate item with `ExpressionAnalyzer::hash(...)` and then confirms actual equality with `ExpressionAnalyzer::equal(...)`.

The implementation is careful to iterate hash groups in deterministic order.

That matters because the pass is heuristic and subset-based:

- it does not try to find the globally best merge
- it wants stable output even when several merge choices are possible

## Profitability rule

The pass only commits if `worthIt(num, tails)` says yes.

The important pieces of that heuristic are:

- saved size = size of the shared suffix times how many duplicate copies disappear
- cost = replacing tails with branches plus adding helper blocks

Important nuance:

- Binaryen assumes helper structure is real cost, not free
- if moving the items all the way to the function end is not safe, the current implementation simply refuses the optimization instead of trying to insert the helper block at some better intermediate spot

So this is a deliberately conservative implementation of function-ending tail merging.

## Rewrite shape

When Binaryen decides to merge a terminating suffix, it:

1. creates a fresh label like `folding-inner0`
2. rewrites every chosen tail so it branches to that label
3. builds a new inner labeled block containing the old function body
4. ensures control flow does not fall through from the old body into the shared suffix by adding `return` logic when needed
5. appends the shared suffix after that inner block inside a new outer block
6. makes the new outer block the function body

The fresh label comes from `LabelUtils::LabelManager`, which guarantees uniqueness.

## Why the old body sometimes gets wrapped in `return`

This is an easy point to miss.

If the old function body is still reachable, then after Binaryen appends the shared suffix, normal fallthrough from the old body into that suffix would be wrong.

So Binaryen may need to turn the old reachable body into:

- old body
- then explicit `return`

or directly:

- `return oldBody`

That is why this subsystem is more than just “append the suffix once at the end.”

## Positive shape: inside-targets are still fine

The shipped `break-target-inside-all-good` test shows a good case.

Two paths both end in equivalent tail code that branches only to targets that stay valid after hoisting. Binaryen rewrites both paths to branch to a shared `folding-inner0` block and keeps one copy of the shared suffix.

The important lesson is:

- branches inside the shared code are allowed
- as long as those branches still target something valid after hoisting

## Negative shape: targets outside the merged region block the transform

The shipped `break-target-outside-of-return-merged-code` test shows the bad case.

The tails look similar, but part of the would-be shared code branches to a label outside the safe moved region.

Binaryen refuses the fold.

Beginner takeaway:

- “looks the same” is not enough
- the branch-target scope must still exist where the code ends up

## Function-ending `unreachable` tails matter too

This subsystem is not only about `return`.

`unreachable` tails are tracked separately and optimized first. That ordering makes sense:

- if an unreachable tail can be merged, later return-tail matching may see cleaner or smaller structure

## `return_call*` is part of the family

The source records:

- `return_call`
- `return_call_indirect`
- `return_call_ref`

through the same `handleReturn(...)` helper.

That is easy to overlook if you only skim the tests.

A future port should not accidentally implement “plain return only.”

## Interaction with the rest of late cleanup

In the default late pipeline, function-ending code folding sits before:

- `merge-blocks`
- late `remove-unused-brs`
- late `remove-unused-names`
- the second late `merge-blocks`
- late `precompute(-propagate)`
- `optimize-instructions`
- `heap-store-optimization`
- `rse`
- final `vacuum`

That ordering is deliberate.

A terminating-tail merge can create:

- helper blocks
- new `br` instructions
- redundant names or wrappers

The next passes are exactly the passes you would want to clean that up.

## Current Starshine progress

The broader staged local plan is in [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md). As of the 2026-06-04 O4z audit continuation, Starshine first covered the adjacent shape where a no-else `if` then-tail and the immediately following fallthrough tail share an identical empty-payload `return` or `unreachable` suffix. The next slice now implements a conservative root-anchored helper-label algorithm: it collects root-level and nested region terminators, searches backward for the deepest profitable common suffix that also includes the function-end tail, rewrites the old nested tails to `br` to a fresh wrapper label, wraps the old function prefix in that void block, and leaves one shared terminal suffix after it. Focused tests cover non-adjacent `return`, block-backed `unreachable`, typed-result direct `return_call`, `return_call_indirect`, and core-built `return_call_ref` tails, plus narrow nested internal-label positives for direct, indirect, and ref tail calls and crossed-label negatives through direct and indirect tail calls. The H/I/J batch now reruns this local root-anchored model to fixpoint, with a focused test where the first root-anchored fold exposes a second root-anchored fold; the June 5 tail-call guards also keep operand-only return suffixes and simple result direct/indirect sibling tail-call suffixes unshared when Binaryen's helper-cost model preserves them, including a small late-neighborhood guard for the direct tail-call bailout. This is useful progress, but it is still not the full Binaryen subset/deeper-suffix terminating-tail algorithm because arbitrary non-root subsets, branch/control-bearing moved suffixes, exact helper cost modeling, and EH repair remain open.

## What a future Starshine port must preserve

For this subsystem specifically, preserve these facts first:

1. subset search, not “all tails or nothing”
2. deeper common suffixes are explored before shallower ones
3. external break targets are a hard bailout
4. profitability includes the cost of helper branches and blocks
5. root-level terminating expressions need a direct replacement path, not only block-backed tails
6. the old body may need explicit `return` wrapping to prevent accidental fallthrough
7. fresh helper labels must be unique

Those are the real implementation contracts.

## Sources

- [`../../../raw/binaryen/2026-04-25-code-folding-current-main-recheck.md`](../../../raw/binaryen/2026-04-25-code-folding-current-main-recheck.md)
- [`../../../raw/binaryen/2026-05-05-code-folding-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-code-folding-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-22-code-folding-primary-sources.md`](../../../raw/binaryen/2026-04-22-code-folding-primary-sources.md)
- [`../../../raw/research/0351-2026-04-25-code-folding-current-main-and-test-map.md`](../../../raw/research/0351-2026-04-25-code-folding-current-main-and-test-map.md)
- [`../../../raw/research/0442-2026-05-05-code-folding-current-main-recheck.md`](../../../raw/research/0442-2026-05-05-code-folding-current-main-recheck.md)
- [`../../../raw/research/0112-2026-04-20-code-folding-binaryen-research.md`](../../../raw/research/0112-2026-04-20-code-folding-binaryen-research.md)
- [`../../../raw/research/0257-2026-04-22-code-folding-primary-sources-and-starshine-followup.md`](../../../raw/research/0257-2026-04-22-code-folding-primary-sources-and-starshine-followup.md)
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/CodeFolding.cpp>
- Binaryen current `main` pass source: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/CodeFolding.cpp>
- Binaryen `version_129` label helpers: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/label-utils.h>
- Binaryen `version_129` effects helpers: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
- Binaryen `version_129` lit tests: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-folding.wast>
