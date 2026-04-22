---
kind: concept
status: supported
last_reviewed: 2026-04-22
sources:
  - ../../../raw/binaryen/2026-04-22-remove-unused-brs-primary-sources.md
  - ../../../raw/research/0146-2026-04-20-remove-unused-brs-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RemoveUnusedBrs.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/branch-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/branch-hints.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/cost.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/drop.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/gc-type-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/localize.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-brs.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-brs-gc.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-brs-eh.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-brs-desc.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-brs-exact.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-brs-exact-only.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-brs-intrinsics.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-brs_all-features.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-brs_branch-hints.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-brs_branch-hints-unconditionalize.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-brs_branch-hints-shrink.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-brs_enable-multivalue.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-brs_levels.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-brs_shrink-level=1.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-brs_trap.wast
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/RemoveUnusedBrs.cpp
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./parity.md
---

# Upstream implementation structure and test map for `remove-unused-brs`

## Why this page exists

The older RUB folder already had many local family pages, but it still lacked one compact source-backed page answering these practical questions together:

- which upstream files really matter
- which helpers are part of the algorithm rather than incidental utilities
- which official test families prove the real pass surface
- what small current-main drift has actually been verified

This page is that file-and-test map.

## File map

| File | Why it matters | Durable lesson |
| --- | --- | --- |
| `src/passes/RemoveUnusedBrs.cpp` | Core implementation | RUB is a staged function pass: flow cleanup, loop cleanup, block sinking, GC cleanup, jump-threading, and a late final optimizer. |
| `src/passes/pass.cpp` | Registration and scheduler placement | RUB is a public pass and is intentionally rerun multiple times in the default optimize pipeline. |
| `src/ir/branch-utils.h` | Branch search and retarget helpers | RUB is deeply about scope-target discovery and controlled branch retargeting, not only deletion. |
| `src/ir/branch-hints.h` | Metadata propagation helpers | Branch-hint metadata survival is part of the contract. |
| `src/ir/effects.h` | Reorder / side-effect legality | Many RUB rewrites are guarded by effect invalidation, not just by shape. |
| `src/ir/cost.h` | Unconditionalization policy | RUB only turns branching into unconditional execution when the cost model says it is worthwhile. |
| `src/ir/properties.h` | Fallthrough and select emission helpers | `selectify`, constant-branch cleanup, and GC reasoning depend on these helpers. |
| `src/ir/localize.h` | `ChildLocalizer` | Some rewrites preserve child evaluation order by explicitly localizing children. |
| `src/ir/drop.h` | Child-dropping helper | Throw/GC rewrites preserve child side effects even when replacing the parent control form. |
| `src/ir/gc-type-utils.h` | GC cast reasoning | GC BrOn simplification is a real sub-surface of RUB. |

## The core C++ shape

The pass is one function-parallel `WalkerPass<PostWalker<RemoveUnusedBrs>>`.

The main state is intentionally small:

- `anotherCycle`
- `neverUnconditionalize`
- `flows`
- `ifStack`
- `loops`
- `catchers`

That matters because it teaches what the pass is **not** using as its core proof:

- no whole CFG construction
- no SSA
- no local liveness framework
- no dominant big global summary

Instead, it is a custom structured-control walk with a few targeted helper stacks and late helper passes.

## The real helper dependency story

### Helpers that are part of the real algorithm

- `BranchUtils::BranchSeeker`
- `BranchUtils::replacePossibleTarget(...)`
- `BranchUtils::operateOnScopeNameUsesAndSentTypes(...)`
- `BranchUtils::getUniqueTargets(...)`
- `EffectAnalyzer`
- `TooCostlyToRunUnconditionally`
- `Properties::canEmitSelectWithArms(...)`
- `Properties::getFallthrough(...)`
- `Properties::getFallthroughType(...)`
- `ChildLocalizer`
- `getDroppedChildrenAndAppend(...)`
- `GCTypeUtils::evaluateCastCheck(...)`
- `BranchHints::{copyTo, copyFlippedTo, applyAndTo, applyOrTo, flip}`
- `ReFinalize`

### Helpers it notably does not use as the central proof

RUB is **not** built around:

- a classic dominator tree
- dataflow liveness over locals
- alias analysis
- a broad CFG optimizer framework

That absence is part of the real teaching surface.
RUB is structured-control-heavy, not generic-control-flow-heavy.

## Current-main freshness note

A narrow 2026-04-22 check found:

- the `remove-unused-brs*` lit roster is unchanged between `version_129` and current `main`
- the core implementation is still recognizably the same staged algorithm
- at least one small semantic drift exists in current `main`
  - `version_129` `JumpThreader` only redirects a named parent block to a named child block when the child and parent types match
  - current `main` removed that type-equality check

Treat that as a **tracked drift**, not as permission to rewrite the `version_129` teaching story.

## Official lit-family map

The upstream `version_129` lit roster contains fifteen `remove-unused-brs*` files.
That alone is a helpful teaching fact: Binaryen itself treats RUB as much broader than plain dead-branch stripping.

### `remove-unused-brs.wast`

This is the main core-behavior file.
It covers:

- `if` to `br_if`
- nested-condition folding
- `restructureIf`
- block-tail redundant `br_if` value cleanup
- `selectify`
- `optimizeSetIf`
- `tablify`

If someone only studies one upstream test file first, this should be it.

### `remove-unused-brs-gc.wast`

This is the best single file for the GC half of the pass.
It proves that RUB owns:

- `br_on_null`
- `br_on_non_null`
- `br_on_cast`
- `br_on_cast_fail`
- ref-type LUB / GLB and refinalization behavior
- some selectification in ref-typed shapes

### `remove-unused-brs-desc.wast`

This file shows the custom-descriptor side of GC branch cleanup.
It proves that descriptor-based cast forms are part of the real surface and that the pass must preserve descriptor semantics while simplifying control.

### `remove-unused-brs-exact.wast` and `remove-unused-brs-exact-only.wast`

These files prove that exact-type cast behavior matters here.
They are especially useful for teaching that RUB may need to insert or preserve casts while simplifying a BrOn family, not merely erase control instructions.

### `remove-unused-brs-eh.wast`

This is the clearest proof that caught-throw-to-branch rewriting is part of RUB.
It covers:

- `throw` caught by `try_table`
- `catch_all` versus exact `catch`
- `catch_ref` / `catch_all_ref` negative cases
- multivalue thrown payloads
- mixed `Try` versus `TryTable` conservatism

### `remove-unused-brs_trap.wast`

This file shows trap-sensitive branch threading and preservation.
It is the best single reminder that “jump goes to a trap” is not just a parity anecdote; it is an official tested family.

### `remove-unused-brs-intrinsics.wast`

This file connects RUB to Binaryen intrinsics and shrink-level behavior.
It proves that cost-sensitive unconditionalization interacts with `binaryen-intrinsics` surfaces rather than only with arithmetic toy examples.

### `remove-unused-brs_branch-hints.wast`

This file proves branch-hint metadata movement is part of the real pass contract.
Rewrites are not correct if they only preserve control semantics but lose or misplace branch hints.

### `remove-unused-brs_branch-hints-unconditionalize.wast`

This is the clearest official proof that `remove-unused-brs-never-unconditionalize` is a real behavior knob.
The flag is not wiki folklore; it has dedicated upstream coverage.

### `remove-unused-brs_branch-hints-shrink.wast`

This file proves that branch-hint propagation also matters in shrink-sensitive adjacent-`br_if` merging.

### `remove-unused-brs_levels.wast` and `remove-unused-brs_shrink-level=1.wast`

These files are the best place to learn how RUB's cost model changes with shrink level.
They show that the pass does **not** have one fixed aggressiveness mode.

### `remove-unused-brs_enable-multivalue.wast`

This file proves RUB must stay honest around multivalue control.
It is a good antidote to beginner overgeneralization from scalar-only `selectify` examples.

### `remove-unused-brs_all-features.wast`

This is the broadest surface file.
It exercises many combined modern-feature shapes and is useful for teaching that RUB is part of the general all-features optimizer, not just the MVP branch-cleanup corner.

## What the test surface means for the docs

The official test roster says RUB has at least these stable teaching buckets:

- core structured branch cleanup
- GC BrOn cleanup
- descriptor and exact-type subtleties
- EH throw-to-branch cleanup
- trap-sensitive jump threading
- branch-hint propagation
- shrink-level and unconditionalization policy
- multivalue and all-features coverage

Any dossier that only explains tail `br` / `return` stripping is therefore incomplete.

## Practical porting lesson

A future Starshine port or parity refinement should preserve the same division of labor:

- early flow cleanup
- mid-phase loop/block preparation
- separate GC cleanup
- late jump-threading
- late final optimizer families
- metadata and refinalization repair

The official file-and-test map makes it clear that this division is not accidental implementation clutter.
It is the pass contract.
