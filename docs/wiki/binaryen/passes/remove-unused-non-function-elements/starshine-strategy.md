---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-remove-unused-non-function-elements-primary-sources.md
  - ../../../raw/research/0328-2026-04-24-remove-unused-non-function-elements-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/remove_unused_module_elements.mbt
  - ../../../../../src/passes/remove_unused_module_elements_test.mbt
  - ../../../../../src/cmd/cmd.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../agent-todo.md
  - ../remove-unused-module-elements/index.md
  - ./index.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./shared-engine-rooting-and-defined-vs-imported-functions.md
  - ./module-shapes.md
  - ../remove-unused-module-elements/starshine-hot-ir-strategy.md
  - ../remove-unused-module-elements/retention-and-index-rewrites.md
  - ../remove-unused-module-elements/parity.md
---

# Starshine strategy for `remove-unused-non-function-elements`

## Current status

Starshine does **not** implement the Binaryen sibling pass yet.

The local state on 2026-04-24 is:

- local registry spelling: `remove-unused-non-function-elements`
- upstream Binaryen spelling: `remove-unused-nonfunction-module-elements`
- registry category: **boundary-only**
- active HOT pass: no
- active module pass: no
- preset member: no
- dedicated owner file: no
- active backlog slice: no dedicated slice found in `agent-todo.md`

So this page is a status and port-strategy bridge, not a claim that the sibling already runs in Starshine.

## Exact local code locations

### Registry and request gating

- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
  - `pass_registry_boundary_only_names()` lists `remove-unused-non-function-elements` beside `remove-unused` and `remove-unused-types` around lines 127-139.
  - `pass_registry_entries()` converts every boundary-only name into a `HotPassRegistryCategory::BoundaryOnly` entry around lines 156-274.
  - `expand_pass_entries_for_names(...)` rejects a direct lower-level pass request with `pass flag <name> is boundary-only and is not implemented in the hot pipeline` around lines 461-466.
- [`src/cmd/cmd.mbt`](../../../../../src/cmd/cmd.mbt)
  - CLI pass resolution only accepts `HotPass`, `ModulePass`, and `Preset` categories around lines 1972-1977, so the command path currently rejects this boundary-only spelling before it can run.
  - Help output only prints `HotPass` and `Preset` entries around lines 2962-2967, so this boundary-only name is intentionally hidden from the user-facing pass list.
- [`src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt)
  - The registry tests prove the category machinery for active, module, preset, and removed names. They do not currently include a dedicated assertion for this sibling name.

### Module dispatcher gap

- [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
  - The module-pass dispatcher handles active module passes around lines 8637-8647.
  - It dispatches full [`remove-unused-module-elements`](../remove-unused-module-elements/index.md) to `rume_run_module_pass(mod_)`.
  - It has no case for `remove-unused-non-function-elements`, which matches the boundary-only registry status.

### Reusable implementation surfaces

The closest local implementation is full RUME:

- [`src/passes/remove_unused_module_elements.mbt`](../../../../../src/passes/remove_unused_module_elements.mbt)
  - `rume_summary()` describes the active full module pass.
  - import counters and absolute-index helpers live near lines 17-118.
  - `rume_defined_func_count(...)` and defined-function lookup surfaces live near lines 200-252.
  - `rume_has_binaryen_noop_start_sec(...)` captures the Binaryen-compatible no-op-start cleanup around lines 264-270.
  - `rume_mark_*` helpers and expression traversal cover function/global/table/memory/tag/elem/data roots around lines 276-573.
  - `rume_mark_imported_parent_segments(...)` preserves visible active imported-parent element/data segments around lines 768-807.
  - `rume_collect_liveness_with_import_parent_policy(...)` and `rume_collect_liveness(...)` seed roots and process the shared reachability queue around lines 820-949.
  - `rume_rewrite_*` helpers rewrite surviving module indices from roughly lines 1021 onward.
  - `rume_collect_used_type_flags(...)` and type-section rebuild helpers begin around lines 2080-2227.
  - `rume_apply_module_rewrite(...)` starts around line 2276 and applies section filtering/remapping.
  - `rume_run_module_pass(...)` starts around line 3233 and wires collection into rewrite.
- [`src/passes/remove_unused_module_elements_test.mbt`](../../../../../src/passes/remove_unused_module_elements_test.mbt)
  - existing tests cover full-RUME section deletion/remap, imported-parent segment retention, imported-function remap, no-op start behavior, active data/elem edge cases, and validation of rewritten modules.
  - these are reusable as sibling-test scaffolding, but a faithful sibling needs new expectations that dead defined functions survive.

## Mapping to Binaryen's strategy

Binaryen's source-backed strategy for the sibling is tiny but semantically important:

1. use the same full-RUME engine;
2. before shared analysis, root every **defined** function;
3. do **not** root imported functions by that special rule;
4. then preserve all ordinary RUME roots and cleanup behavior.

Current Starshine has item 1 for full RUME, but it has no switch for item 2.

The cleanest future Starshine port would probably parameterize the local RUME liveness entry point rather than copy the pass:

- add a sibling public module pass name in the active registry only when implemented;
- add a `root_all_defined_functions` policy to the liveness seed phase;
- seed all defined function absolute indices after the no-op-start decision and before or beside the ordinary export/start/imported-parent roots;
- reuse the existing RUME traversal and rewrite stages;
- add focused tests proving that dead defined functions stay while dead imported functions and dead non-function sections can still disappear.

## What Starshine must not do

A future implementation should **not** be a new ad hoc non-function sweep.
That would likely miss inherited RUME obligations:

- `FuncIdx`, `TableIdx`, `MemIdx`, `GlobalIdx`, `TagIdx`, `ElemIdx`, and `DataIdx` remapping;
- start/export/segment metadata repair;
- imported-parent active segment retention;
- function-type compaction;
- data-count repair;
- annotation/name remapping;
- validation of the rewritten module.

It also should **not** interpret the local spelling as “keep every function declaration.”
The upstream sibling protects defined function bodies; it still allows dead imported functions to disappear through the ordinary shared engine.

## Validation plan for a future port

A faithful Starshine port should add tests before implementation:

1. **dead defined helper survives**: a module with an unreachable defined helper remains with that helper after `remove-unused-non-function-elements`.
2. **dead non-function section vanishes**: dead memory/table/global/tag/data/elem sections still clean up.
3. **dead imported function can vanish**: an unused imported function is pruned while a used imported function remains.
4. **function types still compact**: type-section cleanup remains active.
5. **no-op start metadata is separate**: a no-op start declaration can disappear while the start function body survives.
6. **full RUME stays stricter**: the existing `remove-unused-module-elements` behavior still deletes dead defined helpers, proving the sibling policy did not leak into full RUME.
7. **Binaryen parity**: compare the dedicated upstream all-features shape families against `wasm-opt --remove-unused-nonfunction-module-elements`.

## Current uncertainty

- The wiki did not find a current Starshine backlog slice dedicated to this sibling.
- The local boundary-only name may have been kept mostly for registry compatibility rather than near-term implementation.
- Current Binaryen `main` still has the pass identity and dedicated test path, but the owner file has helper/container drift after `version_129`; this page intentionally anchors strategy to the stable `version_129` source capture.

## Bottom line

Starshine has the right reusable full-RUME machinery, but it does not yet expose Binaryen's `remove-unused-nonfunction-module-elements` sibling.
The future implementation should be a small, source-backed policy mode on the existing module liveness-and-rewrite pass: root all defined functions, then run the ordinary RUME engine.
