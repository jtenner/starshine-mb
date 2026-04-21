---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0207-2026-04-21-ssa-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SSAify.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/LocalGraph.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/ReFinalize.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/ssa.wast
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./merge-locals-entry-prepends-and-default-values.md
  - ./wat-shapes.md
  - ../ssa-nomerge/binaryen-strategy.md
---

# Binaryen `ssa` strategy

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

- dedicated public lit file:
  - `test/lit/passes/ssa.wast`
- helper-level LocalGraph surface:
  - `test/gtest/local-graph.cpp`
- sibling comparison surface:
  - `test/passes/ssa-nomerge_enable-simd.wast`

## High-level intent

Binaryen uses `ssa` to rewrite local traffic so each logical value gets its own single-assignment local, **including across merge points**.

The crucial part is the second half.
Unlike `ssa-nomerge`, full `ssa` does not stop when a read can see multiple incoming values.
Instead it materializes a fresh merge local and rewrites the incoming definitions to feed that local.

## Registered surface and scheduler placement

`pass.cpp` registers:

- `ssa`
  - ssa-ify variables so that they have a single assignment
- `ssa-nomerge`
  - ssa-ify variables so that they have a single assignment, ignoring merges

`passes.h` exports both constructors:

- `createSSAifyPass()`
- `createSSAifyNoMergePass()`

Important scheduler fact:

- the canonical no-DWARF `-O` / `-Os` function path documented in this repo adds only `ssa-nomerge`
- full `ssa` is therefore a public upstream pass, but not the default sibling used in that pathway

That is why this dossier is mostly about sibling clarity, not default-pipeline parity.

## One implementation, one policy flag

`SSAify.cpp` contains one pass struct:

- `SSAify(bool allowMerges)`

Construction is the full split:

- `SSAify(true)` => `ssa`
- `SSAify(false)` => `ssa-nomerge`

So the safest durable mental model is:

- same LocalGraph analysis
- same first-pass renaming logic
- different behavior only when a `local.get` has multiple reaching sets

## The pass in one table

| Phase | What Binaryen does | Why it exists |
| --- | --- | --- |
| Build LocalGraph | Compute get/set flow, influence sets, and already-SSA indexes | Understand real local traffic across structured control flow |
| Rename non-SSA sets | Give eligible writes fresh local indexes | Make each rewritten definition single-assignment |
| Rewrite single-source gets | Retarget gets to the one proved source, or materialize entry/default values when that is the only source | Keep reads aligned with the new definitions |
| Rewrite multi-source gets | Allocate a merge local, tee explicit incoming values into it, prepend param-entry copies when needed | Model phi-like joins without a phi instruction |
| Add prepends | Insert entry copies in front of the function body | Handle param-entry inputs to merge locals |
| Narrow refinalize | Repair parent types after more-refined ref/null replacement | Keep typed AST valid |

## Phase 1: LocalGraph is the whole-function proof engine

`LocalGraph` and `LocalGraphFlower` are why this pass is more than a straight-line locals peephole.
They compute:

- which sets can reach each get
- which gets each set can influence
- which local indexes are already SSA enough to ignore
- where expressions live so in-place rewrites stay valid

Important caveat from the helper comments and code:

- the analysis may overestimate in unreachable code
- `nullptr` in the reaching-set data means the implicit entry value
  - parameter entry for params
  - zero/null default entry for ordinary locals

That implicit-entry representation is central to full `ssa` merge handling later.

## Phase 2: `createNewIndexes(...)` still starts from the same per-set renaming rule

Binaryen iterates all `LocalSet`s and, for each one:

- if the original index is already SSA, leave it alone
- otherwise, add a fresh local index for that set

In full `ssa`, merge participation is **not** a blocker for this initial renaming step.
That is one of the main differences from `ssa-nomerge`, whose no-merge mode refuses to rename sets that feed merged gets.

## Phase 3: `computeGetsAndPhis(...)` is where full `ssa` becomes a different pass

For each `LocalGet`, Binaryen looks at the reaching-set set from LocalGraph.

### Case A: zero reaching sets

If `sets.size() == 0`:

- the get is treated as unreachable noise
- the pass leaves it alone

### Case B: exactly one reaching set

If the single reaching set is an explicit `LocalSet`:

- retarget the get to that set's rewritten local index

If the single reaching set is `nullptr`:

- params keep their original parameter slot
- defaultable non-params are replaced with an explicit zero/null/default literal
- nondefaultable locals are left alone because there is no sound default literal to materialize

If that replacement sharpens a reference-typed parent to a more refined null/default type:

- set `refinalize = true`
- run `ReFinalize` later

### Case C: multiple reaching sets

This is the full-`ssa`-only path.
Binaryen:

1. allocates a fresh merge local of the get's type
2. retargets the get to that merge local
3. for each explicit incoming set:
   - wraps the set value in `local.tee mergeLocal ...`
4. for each `nullptr` incoming source:
   - if it is a parameter entry, prepends `local.set mergeLocal (local.get oldParam)`
   - if it is a defaultable ordinary local entry, does nothing because the fresh merge local already has that default value

This is why the source comments talk about phi-like joins even though the AST has no phi node.

## Phase 4: entry prepends are specific, not generic

A common wrong mental model is:

- any merge involving an entry value needs a prepended copy

The real rule is narrower:

- param entry values need a prepended copy because the parameter is not automatically stored in the new merge local
- defaultable local entry values need no prepend because the fresh merge local already starts at the same default value

That distinction is one of the easiest details to lose when teaching the pass only from intuition.

## Phase 5: explicit incoming defs become `local.tee`s

For explicit incoming sets, Binaryen does not add separate standalone copies after the set.
Instead it rewrites the set's value to a `local.tee` of the new merge local.

That means the pass preserves the original value flow shape while making the merge local receive the incoming value at the same point.

It also updates tracked expression locations when the value moved into the new tee, which keeps later in-place rewrites honest.

## Phase 6: `addPrepends()` is part of correctness, not just formatting

If the pass accumulated any function-entry copies, `addPrepends()` wraps the original body in a new block:

- prepended entry `local.set`s first
- original body last
- finalized to the original body type

That wrapper is the way Binaryen encodes parameter-entry incoming values to merge locals.

## Phase 7: `ReFinalize` is narrow

The pass does **not** refinalize the whole function after every local rewrite.
It only sets `refinalize = true` when a default ref/null replacement can sharpen a parent's observed type.

So the type repair contract is small but real:

- most of the pass is local-index retargeting and tee insertion
- the extra type walk exists only for the more-refined default reference cases

## What the official `ssa.wast` file directly proves

The shipped lit file directly demonstrates:

- overwriting a non-nullable parameter creates fresh locals so each one is assigned once
- replacing a ref-typed default local read with a more refined null can change parent typing enough to require narrow refinalization
- tuple default replacement works too

That file is excellent for the pass's direct public surface, but it is still small.
So the dossier should be explicit that some full-merge shapes are source-derived from `SSAify.cpp` rather than isolated in a dedicated lit example.

## What the LocalGraph gtests add

`test/gtest/local-graph.cpp` helps justify the analysis assumptions beneath `ssa`:

- obstacle-sensitive flow
- multi-block and multi-set behavior
- unreachable-code conservatism
- structured-control and GC-aware obstacle families

Those tests are not `ssa` goldens, but they do validate important helper behavior the pass relies on.

## What this pass does not do

Keep these non-goals explicit:

- no phi instruction in the AST
- no generic constant propagation
- no local coalescing or cleanup of fresh locals
- no scheduler guarantee that this pass runs in the default no-DWARF optimize path here
- no debugger-perfect reachability precision inside unreachable code

## Bottom line

Binaryen `ssa` is the full merge-owning sibling of `ssa-nomerge`.

Its defining rule is:

- when a read has multiple incoming sources, **do not leave it on the canonical slot**
- instead, create a fresh merge local and rewrite each incoming source to feed that local

That is the durable algorithmic distinction this new folder exists to make easy to teach.
