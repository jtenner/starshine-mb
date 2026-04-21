# Binaryen / Starshine `tuple-optimization` follow-up: exact code map, local strategy refresh, and touched-folder hygiene

_Date:_ 2026-04-21  
_Status:_ absorbed into the living `docs/wiki/binaryen/passes/tuple-optimization/` dossier in this same change  
_Related living pages:_
- `docs/wiki/binaryen/passes/tuple-optimization/index.md`
- `docs/wiki/binaryen/passes/tuple-optimization/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/tuple-optimization/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/tuple-optimization/wat-shapes.md`
- `docs/wiki/binaryen/passes/tuple-optimization/starshine-hot-ir-strategy.md`
- `docs/wiki/binaryen/passes/tuple-optimization/implementation-map.md`
- `docs/wiki/binaryen/passes/tuple-optimization/scheduler-and-gates.md`
- `docs/wiki/binaryen/passes/tuple-optimization/reduced-repros-and-evidence.md`
- `docs/wiki/binaryen/passes/tuple-optimization/parity.md`

## Why this follow-up existed

The `tuple-optimization` folder was already in decent shape before this run:

- the landing page explained the pass purpose and scheduler role,
- the Binaryen strategy page covered the upstream tuple-local algorithm,
- the implementation/test-map page covered the upstream owner-file split,
- the WAT page covered the main before/after shapes,
- and the parity page recorded the current local evidence.

But one practical gap still mattered for contributors working in this repo:

- the folder still did **not** have a dedicated Starshine implementation-map page, and the existing Starshine strategy page still read more like an internal design essay than a maintained code-location guide.

That made the dossier weaker than neighboring refreshed implemented-pass folders:

- it was harder to jump from a reduced repro to the owning MoonBit helper cluster,
- harder to see where registry / dispatch / preset decisions live,
- and harder for beginner-to-advanced readers to connect the local strategy narrative to exact in-tree code locations.

So this follow-up is not a brand-new dossier.
It is a source-backed completion and cleanup pass over an already-useful implemented-pass folder.

## Process followed

I re-read:

- `AGENTS.md`
- `docs/README.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- the existing `docs/wiki/binaryen/passes/tuple-optimization/` folder
- `src/passes/tuple_optimization.mbt`
- `src/passes/tuple_optimization_wbtest.mbt`
- `src/passes/pass_manager.mbt`
- `src/passes/optimize.mbt`
- `src/passes/registry_test.mbt`
- `src/cmd/cmd_wbtest.mbt`
- `src/cmd/cmd_native_wbtest.mbt`
- `CHANGELOG.md`

I also checked `git status` first.
The worktree was clean aside from branch metadata, so there was no unrelated-local-change blockage.

## Primary online sources reviewed

Primary official Binaryen sources reviewed for this follow-up:

- Binaryen `version_129` `src/passes/TupleOptimization.cpp`
- Binaryen `version_129` `src/passes/pass.cpp`
- Binaryen `version_129` `test/lit/passes/tuple-optimization.wast`
- Binaryen current `main` `src/passes/TupleOptimization.cpp`
- Binaryen current `main` `test/lit/passes/tuple-optimization.wast`

These were used to keep the refreshed local pages honest about:

- the released upstream oracle surface,
- the exact split between tuple-local scalarization and neighboring peepholes,
- and the current no-drift freshness claim the folder already carried.

I did **not** need a new wider upstream mechanics page here because the existing Binaryen side was already strong.
The main missing piece was the Starshine code map.

## Main local code locations captured in the refreshed living pages

### Public surface, dispatch, and preset policy

- `src/passes/tuple_optimization.mbt:97`
  - `tuple_optimization_descriptor()`
- `src/passes/tuple_optimization.mbt:114`
  - `tuple_optimization_summary()`
- `src/passes/pass_manager.mbt:8699`
  - active hot-pass dispatch entry
- `src/passes/pass_manager.mbt:7938-7946`
  - debug trace hook that re-runs tuple analysis and prints the rewrite mask for the targeted function
- `src/passes/optimize.mbt:212`
  - registry entry in `pass_registry_entries()`
- `src/passes/optimize.mbt:374-379`
  - `tuple_optimization_exact_slot_prereqs_ready()`
- `src/passes/optimize.mbt:380-392`
  - explicit preset exclusion comment and current `optimize` gate
- `src/passes/registry_test.mbt:172-185`
  - active-hot-pass acceptance test

### Analysis and group formation

- `src/passes/tuple_optimization.mbt:134`
  - `tuple_optimization_collect_seed_group(...)`
- `src/passes/tuple_optimization.mbt:200`
  - `tuple_optimization_collect_seed_groups(...)`
- `src/passes/tuple_optimization.mbt:228`
  - `tuple_optimization_build_local_group_ids(...)`
- `src/passes/tuple_optimization.mbt:245-360`
  - payload-source recovery helpers
- `src/passes/tuple_optimization.mbt:515`
  - `tuple_optimization_collect_result_block_copy_group(...)`
- `src/passes/tuple_optimization.mbt:894`
  - `tuple_optimization_collect_scalar_forward_copy_group(...)`
- `src/passes/tuple_optimization.mbt:1118`
  - `tuple_optimization_build_query_summary(...)`
- `src/passes/tuple_optimization.mbt:1264-1680`
  - direct-use and forwarded-use predicates
- `src/passes/tuple_optimization.mbt:1702`
  - `tuple_optimization_finalize_host_lanes(...)`
- `src/passes/tuple_optimization.mbt:1864`
  - `tuple_optimization_propagate_badness(...)`
- `src/passes/tuple_optimization.mbt:1901-1935`
  - analysis entry points

### Rewrite-mask, carrier, and cleanup ownership

- `src/passes/tuple_optimization.mbt:1955-2132`
  - group rewrite-eligibility and suppression policy
- `src/passes/tuple_optimization.mbt:2282`
  - `tuple_optimization_build_group_rewrite_mask(...)`
- `src/passes/tuple_optimization.mbt:2322-2676`
  - split-local allocation and reuse policy
- `src/passes/tuple_optimization.mbt:2684-2902`
  - root-slot and passthrough-chain placement helpers
- `src/passes/tuple_optimization.mbt:2941-3564`
  - source-host, host-result, tuple-carrier, and copy-carrier builders
- `src/passes/tuple_optimization.mbt:3628-4242`
  - concrete rewrite entry points
- `src/passes/tuple_optimization.mbt:4750`
  - `tuple_optimization_rewrite_good_components(...)`
- `src/passes/tuple_optimization.mbt:4866-5256`
  - cleanup cluster
- `src/passes/tuple_optimization.mbt:5268`
  - top-level pass runner

### Test ownership

- `src/passes/tuple_optimization_wbtest.mbt:120-1109`
  - focused analysis / rewrite / lowered-shape test lane
- `src/cmd/cmd_wbtest.mbt:1998-2369`
  - CLI acceptance plus lowered-module validity on committed repros
- `src/cmd/cmd_native_wbtest.mbt:404-1281`
  - direct Binaryen-oracle lane for committed repros

## Main findings

### 1. The local pass is now best taught as a HOT-native component-analysis pass with three different maintenance surfaces

The most useful local teaching split is:

1. registry / dispatch / preset policy
2. HOT analysis and rewrite logic
3. focused pass tests plus CLI / native-oracle tests

Before this follow-up, the dossier mostly covered item `2` well but left `1` and `3` too scattered.
The new implementation-map page closes that gap.

### 2. The biggest practical local complexity is not tuple syntax itself; it is host-lane preservation plus root-slot placement

The upstream Binaryen side is already deliberately small.
The local Starshine side is bigger because the port starts from lifted scalar traffic rather than explicit tuple locals.

The hard local clusters are therefore:

- forwarded-use classification,
- rewrite suppression,
- root-slot discovery,
- and carrier construction.

That is the real reason the refreshed Starshine page now points readers first to:

- the host-lane helpers,
- the rewrite-mask helpers,
- and the root / carrier builders,

instead of only retelling the seed-group story.

### 3. The local folder had a real usability gap even though it already had all the nominal page types

This follow-up is a good example of why “folder complete” and “folder easy to use” are different questions.

Before this run, `tuple-optimization` already had:

- a landing page,
- Binaryen strategy,
- shapes,
- Starshine strategy,
- scheduler notes,
- repro notes,
- and parity notes.

But it still lacked the one page a future porter or bug-fixer was most likely to need first:

- a compact exact code map tying those concepts back to MoonBit owner files and test lanes.

### 4. No new upstream drift warning was needed

The existing folder already recorded a narrow no-drift freshness result for the core Binaryen pass file and lit file.
This follow-up rechecked the same upstream surfaces and found no reason to change that claim.
So the durable update here is local-documentation completion, not a new upstream semantic warning.

## Durable conclusions filed back into the living wiki

- `tuple-optimization` now has a dedicated Starshine implementation-map page alongside the existing strategy page.
- The Starshine strategy page is now a better-maintained code-location guide instead of only a design narrative.
- The touched folder is now easier for beginner-to-advanced readers to navigate from:
  - transformed shape
  - to Binaryen strategy
  - to Starshine strategy
  - to exact MoonBit owner file
  - to the focused local test lane that proves the behavior.
- The correct local teaching headline remains:
  - **Starshine is not porting Binaryen's tuple-local AST literally; it is reconstructing the same safe-bundle idea from lifted scalar traffic.**
- The most important exact local owner clusters are now explicit in the living docs, especially for:
  - seed discovery
  - copy-payload resolution
  - forwarded-use classification
  - rewrite-mask suppression
  - root-slot placement
  - host / copy carrier construction
  - and post-rewrite cleanup.

## Files updated in this change

- `CHANGELOG.md`
- `docs/wiki/raw/research/0239-2026-04-21-tuple-optimization-starshine-code-map-followup.md`
- `docs/wiki/binaryen/passes/tuple-optimization/index.md`
- `docs/wiki/binaryen/passes/tuple-optimization/starshine-hot-ir-strategy.md`
- `docs/wiki/binaryen/passes/tuple-optimization/implementation-map.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`

## Source links

- Binaryen `version_129` `TupleOptimization.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/TupleOptimization.cpp>
- Binaryen `version_129` `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Binaryen `version_129` `tuple-optimization.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/tuple-optimization.wast>
- Binaryen current `main` `TupleOptimization.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/TupleOptimization.cpp>
- Binaryen current `main` `tuple-optimization.wast`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/tuple-optimization.wast>
