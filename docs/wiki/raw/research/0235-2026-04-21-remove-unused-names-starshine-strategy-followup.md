# Binaryen / Starshine `remove-unused-names` follow-up: local strategy map, code locations, and touched-area wiki health

_Date:_ 2026-04-21  
_Status:_ absorbed into the living `docs/wiki/binaryen/passes/remove-unused-names/` dossier in this same change  
_Related living pages:_
- `docs/wiki/binaryen/passes/remove-unused-names/index.md`
- `docs/wiki/binaryen/passes/remove-unused-names/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/remove-unused-names/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/remove-unused-names/control-names-implicit-blocks-and-delegates.md`
- `docs/wiki/binaryen/passes/remove-unused-names/wat-shapes.md`
- `docs/wiki/binaryen/passes/remove-unused-names/starshine-hot-ir-strategy.md`
- `docs/wiki/binaryen/passes/remove-unused-names/invalid-tag-index-parser-gap.md`

## Why this follow-up existed

The `remove-unused-names` folder was already a strong Binaryen-side dossier, but it still had one practical gap for Starshine contributors:

- the folder taught the upstream `version_129` pass well,
- it already had a compact implementation/test map and a shape catalog,
- but it still lacked a dedicated living page that mapped the current Starshine strategy back to concrete code locations in this repository.

That gap mattered because the surrounding implemented-pass schema already treated active hot-pass folders as stable homes for:

- a landing page,
- a Binaryen strategy page,
- a shape page,
- and a Starshine strategy page when the pass is implemented locally.

`remove-unused-names` was still missing that local-strategy piece.

## Process followed

I re-read:

- `AGENTS.md`
- `docs/README.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- the existing `docs/wiki/binaryen/passes/remove-unused-names/` folder
- `src/passes/remove_unused_names.mbt`
- `src/passes/remove_unused_names_test.mbt`
- the local registry / preset / dispatch locations in `src/passes/optimize.mbt` and `src/passes/pass_manager.mbt`

I also checked `git status` first.
The worktree was clean aside from branch metadata, so there was no unrelated-local-change blockage.

## Primary online sources reviewed

Primary official Binaryen sources reviewed for this follow-up:

- Binaryen `version_129` `src/passes/RemoveUnusedNames.cpp`
- Binaryen `version_129` `src/passes/pass.cpp`
- Binaryen `version_129` `test/passes/remove-unused-names.wast`

Useful exact source locations from the official repo:

- `RemoveUnusedNames.cpp:31`
  - `branchesSeen` owner field
- `RemoveUnusedNames.cpp:40`
  - `handleBreakTarget(...)`
- `RemoveUnusedNames.cpp:53-68`
  - same-type block retarget-and-merge in `visitBlock(...)`
- `RemoveUnusedNames.cpp:71-80`
  - dead-label loop demotion in `visitLoop(...)`
- `RemoveUnusedNames.cpp:82-85`
  - special `visitTry(...)` handling
- `RemoveUnusedNames.cpp:87-90`
  - `DELEGATE_CALLER_TARGET` cleanup and final empty-map assertion
- `pass.cpp:654`
  - public pass registration for `remove-unused-names`
- `pass.cpp:729`
  - first no-DWARF slot after `dce`
- `pass.cpp:736`
  - second slot after `remove-unused-brs`
- `pass.cpp:763`
  - late rerun after `merge-blocks -> remove-unused-brs`

Those exact locations were enough to keep the new Starshine page honest about where the local implementation is intentionally narrower than upstream Binaryen.

## Main local code locations captured in the new living page

The new Starshine strategy page now points readers directly to the in-tree owner sites:

- `src/passes/remove_unused_names.mbt:2`
  - descriptor / invalidation surface
- `src/passes/remove_unused_names.mbt:15`
  - summary text
- `src/passes/remove_unused_names.mbt:43`
  - label-use bitset construction
- `src/passes/remove_unused_names.mbt:113`
  - same-typed block-chain peel collection
- `src/passes/remove_unused_names.mbt:152`
  - detached-body cleanup for peeled child blocks
- `src/passes/remove_unused_names.mbt:166`
  - HOT-side candidate gate
- `src/passes/remove_unused_names.mbt:203`
  - region recursion
- `src/passes/remove_unused_names.mbt:236`
  - loop demotion helper
- `src/passes/remove_unused_names.mbt:241`
  - control-node rewrite logic
- `src/passes/remove_unused_names.mbt:351`
  - pass entrypoint and mutation marking
- `src/passes/pass_manager.mbt:7095`
  - raw candidate pre-scan
- `src/passes/pass_manager.mbt:7126`
  - raw skip path
- `src/passes/pass_manager.mbt:8693`
  - dispatch site
- `src/passes/optimize.mbt:182-184`
  - registry entry wiring
- `src/passes/optimize.mbt:246-249`
  - the three preset placements
- `src/passes/remove_unused_names_test.mbt:14`
  - same-type block peel proof
- `src/passes/remove_unused_names_test.mbt:40`
  - branch-retarget proof
- `src/passes/remove_unused_names_test.mbt:53`
  - nested-control bailout proof
- `src/passes/remove_unused_names_test.mbt:86`
  - `try_table` catch-target bailout proof
- `src/passes/remove_unused_names_test.mbt:120`
  - loop demotion proof
- `src/passes/remove_unused_names_test.mbt:128`
  - live-continue-target bailout proof

## Main findings

### 1. The local pass is best taught as a structural subset, not generic label cleanup

The new Starshine page makes the main local teaching rule explicit:

- Starshine does not keep an upstream-style `branchesSeen` map of exact users,
- does not clear labels generically on every named scope,
- and does not retarget generic symbolic scope-name uses the way Binaryen does.

Instead, the local MoonBit pass does two concrete things:

- peels same-typed single-child block chains when the removed intermediate labels are dead,
- and demotes loops when their continue target is dead.

That is the most important correction for future contributors.

### 2. The local pass is HOT-bitset-driven, not name-map-driven

Upstream Binaryen uses exact expression-user sets because it rewrites symbolic name users directly.
Local Starshine uses a `BitSet` of label ids because the implemented rewrites only need to know whether an intermediate block label or loop label is still targeted.

That is both:

- a real implementation simplification,
- and a real semantic narrowing.

The new page makes that tradeoff explicit instead of leaving readers to infer it from the MoonBit file.

### 3. The pass manager already documents a useful local raw-skip contract

One practical local detail that deserved to be filed back into the living wiki is the pass-manager fast path.
Before lifting a function, `run_hot_pipeline_raw_remove_unused_names(...)` skips work entirely unless the raw WAT body contains:

- a loop, or
- a nested one-child block-of-block candidate shape

That is important local behavior for both performance work and future parity debugging, and it was not previously surfaced in the folder.

### 4. The touched area had a small but real dossier-shape inconsistency

Before this follow-up:

- `docs/wiki/binaryen/passes/index.md` still described implemented hot-pass folders as stable homes for Binaryen strategy, WAT-shape, and Starshine strategy coverage,
- but `remove-unused-names` still lacked the Starshine page while other implemented hot passes already had one.

This change fixes that inconsistency and makes the touched folder easier to navigate from beginner-level overview to exact MoonBit code.

## Durable conclusions filed back into the living wiki

- `remove-unused-names` now has the full implemented-hot-pass dossier shape used elsewhere in the pass wiki.
- The correct local teaching headline is: **Starshine currently implements the same-typed block-peel plus dead-label loop-demotion subset of Binaryen `remove-unused-names`, not the whole generic control-label cleanup contract.**
- The touched area is healthier because the pass folder, pass-folder map, tracker row, and top-level wiki index now all advertise the same dossier shape.
- The Binaryen `version_129` sources remain the right oracle for the upstream side of the dossier, while the new page is the canonical local code-map and subset-contract page.

## Files updated in this change

- `docs/wiki/raw/research/0235-2026-04-21-remove-unused-names-starshine-strategy-followup.md`
- `docs/wiki/binaryen/passes/remove-unused-names/index.md`
- `docs/wiki/binaryen/passes/remove-unused-names/starshine-hot-ir-strategy.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `CHANGELOG.md`

## Source links

- Binaryen `version_129` `RemoveUnusedNames.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RemoveUnusedNames.cpp>
- Binaryen `version_129` `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Binaryen `version_129` `remove-unused-names.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-names.wast>
