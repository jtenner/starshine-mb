---
kind: concept
status: supported
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0141-2026-04-20-ssa-nomerge-binaryen-research.md
related:
  - ./index.md
  - ./merge-shapes-and-canonical-slots.md
  - ./wat-shapes.md
  - ./parity.md
  - ../../no-dwarf-default-optimize-path.md
---

# Binaryen `ssa-nomerge` strategy

## Upstream source rule

Use Binaryen `version_129` as the primary source oracle for this pass.

Primary files:

- `src/passes/SSAify.cpp`
- `src/passes/pass.cpp`
- `src/passes/passes.h`
- `src/ir/local-graph.h`
- `src/ir/LocalGraph.cpp`
- `src/ir/ReFinalize.cpp`

Most important official test surfaces for this dossier:

- dedicated no-merge golden pair:
  - `test/passes/ssa-nomerge_enable-simd.wast`
  - `test/passes/ssa-nomerge_enable-simd.txt`
- shared `SSAify.cpp` helper surface:
  - `test/lit/passes/ssa.wast`
- helper-level LocalGraph behavior samples:
  - `test/gtest/local-graph.cpp`

I also did a narrow 2026-04-20 freshness check against current GitHub `main` for:

- `SSAify.cpp`
- `local-graph.h`
- `LocalGraph.cpp`
- `ReFinalize.cpp`
- the dedicated `ssa-nomerge_enable-simd` input and golden output

Durable result:

- all of those surfaces still match `version_129` exactly
- the only visible `pass.cpp` drift I found was unrelated typo cleanup in other pass descriptions

So the current wiki should continue treating `version_129` as the semantic oracle here without an active trunk-drift caveat.

## High-level intent

Binaryen uses `ssa-nomerge` to untangle local traffic into a more SSA-like shape **only where doing so is cheap and local-graph-certain**.

The important qualifier is the second half:

- it does **not** build merge locals in no-merge mode
- it does **not** insist that every local.get end up with a unique rewritten source local
- it only creates new locals for sets whose influenced gets are all single-source

That makes the pass a practical pre-cleanup simplifier rather than a full proper-SSA builder.

## The pass in one table

| Phase | What Binaryen does | Why it exists |
| --- | --- | --- |
| Build LocalGraph | Compute get/set reachability, influence sets, SSA-ish indexes | Understand real local traffic across CFG joins |
| Rename eligible sets | Fresh local for each non-SSA set whose influenced gets never merge | Untangle obvious one-def regions without adding merge copies |
| Rewrite gets | Point single-source gets at the rewritten set; materialize default values when entry/default is the only source | Make uses match the untangled defs |
| Skip merge gets | Leave multi-source gets alone in no-merge mode | Avoid code-size growth and overlapping lifetimes |
| Narrow refinalize | Repair type refinements after default ref/null replacement | Keep typed AST valid |

## Where the pass runs

## Registered surface

`pass.cpp` registers:

- `ssa`
  - ssa-ify variables so that they have a single assignment
- `ssa-nomerge`
  - ssa-ify variables so that they have a single assignment, ignoring merges

`passes.h` exports both constructors:

- `createSSAifyPass()`
- `createSSAifyNoMergePass()`

That matters because the implementation is shared.

## Canonical no-DWARF placement

In `pass.cpp`, the default function pipeline begins with this comment and gate:

- untangling to semi-ssa form is helpful, but best to ignore merges so as to not introduce new copies
- if `optimizeLevel >= 3 || shrinkLevel >= 1`, add `ssa-nomerge`

So in the repo's canonical no-DWARF path, `ssa-nomerge` is the first function pass because Binaryen wants simpler local traffic before the first cleanup wave.

## Aggressive and nested placement

The same `addDefaultFunctionOptimizationPasses()` also places `flatten` and the aggressive flat-IR locals cluster later in the function pipeline, but only after this early `ssa-nomerge` step.

And because Binaryen's optimizing boundary passes rerun the default function cluster on changed functions, `ssa-nomerge` reappears in nested reruns as well.

The saved generated-artifact `-O4z` log makes that concrete:

- top-level: `gsi -> ssa-nomerge -> flatten -> ...`
- nested: repeated `precompute-propagate -> ssa-nomerge -> flatten -> simplify-locals-notee-nostructure -> local-cse -> ...`

So this is both an early top-level cleanup preparation pass and a repeated boundary-rerun helper.

## Phase 1: the source file is one shared `SSAify` implementation with a flag

`SSAify.cpp` defines one pass struct with:

- `bool allowMerges`

Construction is the entire high-level split:

- `SSAify(true)` => full `ssa`
- `SSAify(false)` => `ssa-nomerge`

That means the first durable correction is:

- `ssa-nomerge` is not a different codebase from `ssa`
- it is the same algorithm with one policy switch

## Phase 2: `runOnFunction(...)` is short, but the order matters

For each function, Binaryen does:

1. `LocalGraph graph(func, module)`
2. `graph.computeSetInfluences()`
3. `graph.computeSSAIndexes()`
4. `createNewIndexes(graph)`
5. `computeGetsAndPhis(graph)`
6. `addPrepends()`
7. `ReFinalize()` if needed

This order is important because:

- the graph is built over the original function shape
- set renaming happens before get rewriting
- merge materialization decisions happen while the graph still talks about original def/use relationships
- prepended entry copies, if any, happen last

## Phase 3: LocalGraph is the real engine behind the pass

`LocalGraph` is not just a convenience map.
It is the reason `ssa-nomerge` can be more than a straight-line peephole.

### What LocalGraph records

The helper records:

- where each `local.get` and `local.set` appears
- for each get, which sets can reach it
- optionally, which gets a set can influence
- whether an index is already SSA enough for this family of optimizations

### What `nullptr` means

A reaching-set entry of `nullptr` means:

- parameter entry value for params
- zero-init entry value for vars

That choice is central to the default-value materialization logic later.

### How flow works

`LocalGraphFlower`:

- builds CFG blocks with ordered local actions
- tracks the last set per index in each block
- scans blocks backwards to match gets to in-block sets
- when needed, flows backwards through predecessor blocks until it finds relevant sets or the function entry

### Important precision caveat

The `local-graph.h` comments explicitly say the helper may overestimate in unreachable code.
In particular, it may include the entry/default value even when real unreachability would block it.

That is a deliberate optimization tradeoff, not an accidental bug.
A future port must preserve the practical meaning:

- good enough for optimization
- not guaranteed to be debugger-perfect in unreachable code

## Phase 4: “already SSA” is stricter than it sounds

`computeSSAIndexes()` does not merely ask whether gets have one reaching set.
It effectively requires all of these:

- gets see one set
- that set dominates those gets
- no other explicit set of that index exists aside from the implicit entry/default value

The helper comment explains why the “no extra explicit set” rule matters:

- a later unrelated set of the same index could make naïve local-substitution rewrites unsafe even if the current gets look single-source

So `ssa-nomerge` is already conservative before its main no-merge policy begins.

## Phase 5: `createNewIndexes(...)` applies the central no-merge rule per set

This is the most important part of the pass.

Binaryen iterates all `LocalSet`s and renames a set only if:

- its original index is not already SSA, and
- either merges are allowed, or `hasMerges(set, graph)` is false

### What `hasMerges(...)` actually checks

For each get influenced by the set:

- if that get has more than one reaching set, return true

So a set is considered merge-participating if **any** of its influenced gets is multi-source.

### Practical consequence

The no-merge decision is **per set**, not per original local.

One local slot can therefore split into regions like this:

- set A -> single-source gets -> fresh local
- set B -> single-source gets -> fresh local
- set C -> later merge gets -> keep canonical slot
- set D after the merge -> single-source again -> fresh local

This is exactly the behavior the dedicated `nomerge` golden test is designed to lock in.

## Phase 6: `computeGetsAndPhis(...)` has three important cases in no-merge mode

## Case A: no reaching sets

If `sets.size() == 0`:

- Binaryen treats the get as unreachable noise and ignores it

## Case B: exactly one reaching set

If the single reaching set is a real `LocalSet`:

- rewrite the get index to that set's (possibly fresh) index

If the single reaching set is `nullptr`:

- if it is a parameter, keep the parameter slot
- otherwise, if the type is defaultable, replace the get with an explicit zero/default literal
- otherwise leave it alone

This is why `ssa-nomerge` is also a default-value materialization pass, not just a renamer.

### Narrow refinalize trigger

When the replacement is a reference-typed null/default literal, the pass marks `refinalize = true` because the replacement can sharpen what the parent expression sees.

That is a small but real part of the pass contract.

## Case C: multiple reaching sets

If `allowMerges` is false, as in `ssa-nomerge`:

- do nothing
- keep the get on the original canonical slot

This is the defining no-merge policy.

## Phase 7: the full-`ssa` phi path exists right next to it

The same function contains the full merge-handling logic for `allowMerges == true`.
That path:

- creates a fresh merge local
- retargets the get to it
- inserts `local.tee` on each explicit incoming set
- prepends an entry `local.set` when a parameter is an incoming value

This is important context because it shows what `ssa-nomerge` is deliberately refusing to do.

In other words:

- predecessor copies, entry prepends, and merge locals are not unknown to the source file
- they are intentionally skipped in no-merge mode

## Phase 8: `addPrepends()` is mainly for full `ssa`, not no-merge

Because multi-source gets are skipped in no-merge mode, the `functionPrepends` vector usually stays empty for `ssa-nomerge`.

That is a subtle but useful practical rule:

- if you see function-entry copies being discussed, you are usually thinking about full `ssa`, not `ssa-nomerge`

## Phase 9: `ReFinalize` is a narrow repair step, not a whole second algorithm

`ssa-nomerge` does not broadly refinalize everything for every rewrite.
It only asks for refinalization in the narrow default ref/null replacement case.

So the pass's type story is:

- mostly ordinary local-index retargeting
- plus a small but important typed-literal replacement boundary

## What the dedicated official tests matter for

The dedicated `ssa-nomerge_enable-simd` golden pair is the clearest source for the real contract.
It shows:

- straight-line set untangling
- parameter overwrite behavior
- default scalar zero replacement
- `v128` zero materialization
- one-arm and two-arm merge bailouts
- mixed per-set behavior inside one original local

The shared `ssa.wast` file matters as a secondary surface because it locks shared `SSAify.cpp` helper behavior like:

- non-nullable param-overwrite retargeting
- tuple and ref default replacement
- narrow refinalization after sharpening types

The helper-level `test/gtest/local-graph.cpp` file also matters because it shows the LocalGraph design assumptions the pass relies on:

- obstacle-sensitive backward flow
- unreachable-code treatment
- multi-set / multi-get cases
- structured-control and GC-aware flow boundaries

## What this pass does **not** do

These non-goals are worth keeping explicit:

- no proper phi instructions in the AST
- no merge-local materialization in no-merge mode
- no attempt to remove or coalesce the fresh locals it creates
- no generic value propagation beyond local traffic
- no debugger-perfect provenance in unreachable code
- no broad typed repair beyond the narrow default-ref replacement case

## Why later passes are part of the story

The source comment itself points at one of the main reasons for the pass:

- the new variables added by `ssa-nomerge` can be easily removed by `coalesce-locals`

That means the scheduler logic is part of the pass meaning.
It is meant to create cheaper local shapes that later cleanups can capitalize on.

So a future port should not judge `ssa-nomerge` in isolation only by “how many locals did it add?”
The intended question is:

- did it create better single-source local regions without prematurely paying the merge-copy cost?

## Bottom line

Binaryen `ssa-nomerge` is a deliberately selective SSAification pass.

Its strength comes from being:

- whole-function aware enough to understand real local traffic,
- conservative enough to avoid merge locals,
- and cheap enough to run early and repeatedly.

Its defining rule is simple to say but easy to miss in practice:

- **rename only the sets whose later gets never merge.**

Everything else in the pass follows from that rule.
