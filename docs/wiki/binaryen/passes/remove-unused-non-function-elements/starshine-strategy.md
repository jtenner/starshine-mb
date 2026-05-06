---
kind: concept
status: supported
last_reviewed: 2026-05-06
sources:
  - ../../../raw/binaryen/2026-05-05-remove-unused-non-function-elements-current-main-recheck.md
  - ../../../raw/research/0458-2026-05-05-remove-unused-non-function-elements-current-main-recheck.md
  - ../../../raw/binaryen/2026-05-06-remove-unused-non-function-elements-current-main-line-anchor-refresh.md
  - ../../../raw/research/0539-2026-05-06-runfe-direct-revalidation.md
  - ../../../raw/research/0509-2026-05-06-remove-unused-non-function-elements-current-main-line-anchor-refresh.md
  - ../../../raw/binaryen/2026-04-26-remove-unused-non-function-elements-port-readiness-primary-sources.md
  - ../../../raw/research/0408-2026-04-26-remove-unused-non-function-elements-port-readiness.md
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
  - ./starshine-port-readiness-and-validation.md
  - ../remove-unused-module-elements/starshine-hot-ir-strategy.md
  - ../remove-unused-module-elements/retention-and-index-rewrites.md
  - ../remove-unused-module-elements/parity.md
---

# Starshine strategy for `remove-unused-non-function-elements`

## Current status

Starshine now implements the Binaryen sibling pass as an active module pass.
The 2026-05-05 current-main recheck did not change that implementation story; the 2026-05-06 line-anchor refresh only tightened the local code-map pointers and the upstream source bridge.

The local state on 2026-05-06 is:

- active registry / CLI spelling: `remove-unused-nonfunction-module-elements`
- historical dossier label: `remove-unused-non-function-elements`
- upstream Binaryen spelling: `remove-unused-nonfunction-module-elements`
- registry category: **module pass**
- active HOT pass: no
- active module pass: yes
- preset member: no
- dedicated owner file: reused `src/passes/remove_unused_module_elements.mbt`
- active backlog slice: no dedicated slice found in `agent-todo.md`

The implementation is a small policy mode on the existing RUME liveness/rewrite path: root every defined function, leave imported functions as ordinary reachability candidates, then reuse the same module rewrite. Validation evidence and the signoff ladder are summarized in [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md), now including the 2026-05-06 refreshed mixed-generator direct lane with 6581 normalized matches, 0 semantic mismatches, and 20 known Binaryen empty-recursion-group command failures.

## Exact local code locations

### Registry and request gating

- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
  - `pass_registry_entries()` at `:153-155` seeds the registry list, and the sibling module-pass entry at `:271-275` registers `remove-unused-nonfunction-module-elements` as a `HotPassRegistryCategory::ModulePass` beside full `remove-unused-module-elements`.
  - `pass_registry_boundary_only_names()` no longer carries the historical dashed sibling spelling.
  - preset expansion still omits this sibling because it is not part of the documented no-DWARF optimize path.
- [`src/cmd/cmd.mbt`](../../../../../src/cmd/cmd.mbt)
  - CLI pass resolution at `:1972-1975` accepts the module-pass category entry, so `--remove-unused-nonfunction-module-elements` runs through the normal module-pass pipeline.
  - help listing at `:2962-2965` still filters to hot passes and presets, matching the existing module-pass help policy.
- [`src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt)
  - the registry tests at `:114-118` assert that `remove-unused-nonfunction-module-elements` is an active module pass.

### Module dispatcher gap

- [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
  - The module-pass dispatcher at `:8929-8932` handles active module passes.
  - It dispatches full [`remove-unused-module-elements`](../remove-unused-module-elements/index.md) to `rume_run_module_pass(mod_)`.
  - It dispatches `remove-unused-nonfunction-module-elements` to `rume_run_nonfunction_module_pass(mod_)`.

### Reusable implementation surfaces

The closest local implementation is full RUME:

- [`src/passes/remove_unused_module_elements.mbt`](../../../../../src/passes/remove_unused_module_elements.mbt)
  - `rume_nonfunction_summary()` at `:7-8` names the active sibling mode.
  - `rume_collect_liveness_with_import_parent_policy(...)` accepts `keep_all_funcs?` at `:1056-1103`, and the sibling path roots defined functions when that flag is true.
  - the imported-parent segment branch at `:1133-1135` still shares the ordinary cleanup pipeline.
  - `rume_run_nonfunction_module_pass(...)` at `:3518-3532` wires the sibling policy into the shared rewrite path.
  - full-RUME import counters and absolute-index helpers live near lines `17-118`.
  - `rume_defined_func_count(...)` and defined-function lookup surfaces live near lines `200-252`.
  - `rume_has_binaryen_noop_start_sec(...)` captures the Binaryen-compatible no-op-start cleanup around lines `264-270`.
  - `rume_mark_*` helpers and expression traversal cover function/global/table/memory/tag/elem/data roots around lines `276-573`.
  - `rume_mark_imported_parent_segments(...)` preserves visible active imported-parent element/data segments around lines `768-807`.
  - `rume_rewrite_*` helpers rewrite surviving module indices from roughly lines 1021 onward.
  - `rume_collect_used_type_flags(...)` and type-section rebuild helpers begin around lines `2080-2227`.
  - `rume_apply_module_rewrite(...)` starts around line `2276` and applies section filtering/remapping.
  - `rume_run_module_pass(...)` starts around line `3233` and wires collection into rewrite.
- [`src/passes/remove_unused_module_elements_test.mbt`](../../../../../src/passes/remove_unused_module_elements_test.mbt)
  - existing tests cover full-RUME section deletion/remap, imported-parent segment retention, imported-function remap, no-op start behavior, active data/elem edge cases, and validation of rewritten modules.
  - these are reusable as sibling-test scaffolding, but a faithful sibling needs new expectations that dead defined functions survive.

## Mapping to Binaryen's strategy

Binaryen's source-backed strategy for the sibling is tiny but semantically important:

1. use the same full-RUME engine;
2. before shared analysis, root every **defined** function;
3. do **not** root imported functions by that special rule;
4. then preserve all ordinary RUME roots and cleanup behavior.

Current Starshine implements those items through `rume_collect_liveness_with_import_parent_policy(..., keep_all_funcs=true)` and `rume_run_nonfunction_module_pass(...)`.

The implementation deliberately reuses the existing RUME traversal and rewrite stages. Focused tests prove that dead defined functions stay, dead imported functions can still disappear, no-op start metadata can be dropped while the function body remains, active startup-visible segments with global offsets or trapping out-of-bounds offsets are retained, and empty in-bounds active element segments can still be removed.

## What Starshine must not do

The implementation should **not** become a new ad hoc non-function sweep.
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

## Validation evidence

The implemented Starshine port added tests before and during implementation:

1. **dead defined helper survives**: a module with an unreachable defined helper remains with that helper after `remove-unused-non-function-elements`.
2. **dead non-function section vanishes**: dead memory/table/global/tag/data/elem sections still clean up.
3. **dead imported function can vanish**: an unused imported function is pruned while a used imported function remains.
4. **function types still compact**: type-section cleanup remains active.
5. **no-op start metadata is separate**: a no-op start declaration can disappear while the start function body survives.
6. **full RUME stays stricter**: the existing `remove-unused-module-elements` behavior still deletes dead defined helpers, proving the sibling policy did not leak into full RUME.
7. **Binaryen parity**: compare the direct pass against `wasm-opt --remove-unused-nonfunction-module-elements`.

## Current uncertainty

- The wiki still uses the historical dashed folder name to preserve existing research links; the active public pass spelling is upstream-compatible.
- Current Binaryen `main` still has the pass identity and dedicated test path, but the owner file has helper/container drift after `version_129`; this page intentionally anchors strategy to the stable `version_129` source capture and the local oracle runs.
- A pure `wasm-smith`-only exploratory lane still exposed rare Binaryen body-canonicalization noise unrelated to the module-element policy; the canonical mixed and `gen-valid` signoff lanes are mismatch-free on comparable cases.

## Bottom line

Starshine exposes Binaryen's `remove-unused-nonfunction-module-elements` sibling as an active module pass.
The implementation is the intended small, source-backed policy mode on the existing module liveness-and-rewrite pass: root all defined functions, then run the ordinary RUME engine.
The 2026-05-06 post-fuzzer-refresh direct revalidation is green on all comparable mixed-generator cases.
