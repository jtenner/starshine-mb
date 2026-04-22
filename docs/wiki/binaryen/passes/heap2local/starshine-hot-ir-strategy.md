---
kind: concept
status: working
last_reviewed: 2026-04-22
sources:
  - ../../../raw/binaryen/2026-04-22-heap2local-primary-sources.md
  - ../../../raw/research/0245-2026-04-22-heap2local-primary-sources-and-code-map-followup.md
  - ../../../raw/research/0135-2026-04-20-heap2local-binaryen-research.md
  - ../../../../../src/passes/heap2local.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/heap2local_test.mbt
  - ../../../../../src/passes/heap2local_primary_test.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../agent-todo.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./validation-fixups-and-special-cases.md
  - ./wat-shapes.md
  - ./parity.md
---

# Current Starshine `heap2local` strategy

This page is the local “what is actually implemented today?” companion to the upstream Binaryen strategy page.
The main upgrade in this refresh is an exact MoonBit code map so readers can move quickly from the wiki to the implementation.

## Short version

Current Starshine `src/passes/heap2local.mbt` follows the same broad goal as upstream Binaryen:

- replace some nonescaping GC allocation traffic with locals

But it is not a literal source port of Binaryen `Heap2Local.cpp`.
The local implementation is narrower, more direct, and much more HOT/use-def driven.

## Exact code map

## 1. Registry, summary, and preset placement

Start here when you want to confirm that `heap2local` is live and where the public presets place it.

- `src/passes/heap2local.mbt`
  - `heap2local_descriptor()` declares the pass name plus the only required analysis: `@ir.HotAnalysis::use_def()`.
  - `heap2local_summary()` is the registry summary text used elsewhere in the pass catalog.
- `src/passes/optimize.mbt`
  - `pass_registry_entries()` registers `heap2local` as an active hot pass.
  - `optimize_preset_passes(...)` and `shrink_preset_passes(...)` place it in the current local mid-function GC slot.
- `src/passes/optimize_test.mbt`
  - `test "optimize preset schedules heap2local in the mid-function GC slot"` locks the exact neighboring order.
  - `test "optimize preset hands simplify-locals output to the late merge-blocks cleanup cluster"` proves the local handoff order around `heap2local -> simplify-locals -> merge-blocks`.
- `src/passes/registry_test.mbt`
  - `test "pass registry classifies active, boundary-only, and removed names"` and `test "batch 1 descriptors expose the active first hot ports"` keep the registry and descriptor contract explicit.

## 2. Dispatcher entry point

- `src/passes/pass_manager.mbt`
  - `hot_pass_run(...)` dispatches the public pass name `"heap2local"` directly to `heap2local_run(ctx, func)`.

Important local nuance:

- unlike some other Starshine passes, this path does **not** have a dedicated pass-manager raw prefilter or special-case dispatcher branch beyond the standard hot-pass dispatch.
- the real semantics live in `heap2local_run(...)` itself, not in a separate pass-manager raw-skip layer.

## 3. Struct candidate discovery

This is the main local owner-analysis surface.

- `src/passes/heap2local.mbt`
  - `h2l_supported_struct_new_fields(...)` recognizes supported `struct.new` and `struct.new_default` owners.
  - `h2l_is_direct_struct_alloc(...)` and `h2l_direct_descriptor_alloc_info(...)` recognize direct fresh allocations, including the descriptor-bearing forms used by the local `ref.get_desc` fold.
  - `h2l_field_index(...)` and `h2l_exact_field_user_matches(...)` gate the direct field-use families that Starshine currently accepts.
  - `h2l_local_can_hold_struct_ref(...)` enforces the current local-owner type shape.
  - `h2l_collect_source_use(...)` is the key local-family walker for supported struct traffic: direct field users, `ref.as_non_null`, successful `ref.cast`, final-value block flow, and exclusive local-copy chains.
  - `h2l_find_candidate_for_local(...)` is the top-level struct candidate matcher: one write, supported owner, supported read family, supported copy family, and nonempty use set.

This is where the biggest local-vs-upstream difference shows up most clearly.
Binaryen teaches `heap2local` through `EscapeAnalyzer`, parent walking, branch-target flow, and exclusivity proofs.
Starshine teaches it through a much narrower one-write local owner plus exact supported-use family matcher.

## 4. Array candidate discovery

Current Starshine does support arrays, but through a simpler direct element-localization path rather than upstream Binaryen's array-to-synthetic-struct stage.

- `src/passes/heap2local.mbt`
  - `h2l_supported_array_init(...)` accepts the current local array subset: `array.new_default`, `array.new`, and `array.new_fixed` with constant size and the existing `< 20` cap.
  - `h2l_local_can_hold_array_ref(...)` enforces the owner-local type check.
  - `h2l_collect_array_use(...)` accepts the current local use subset: constant-index `array.get`, `array.get_s`, `array.get_u`, and `array.set`.
  - `h2l_find_array_candidate_for_local(...)` ties those checks together into the direct array candidate matcher.

That direct path is simpler than Binaryen, but it also means local Starshine does **not** inherit the larger upstream shared struct-stage handling for many type-flow, atomic, and cmpxchg cases.

## 5. Rewrite helpers and emitted shapes

Once a candidate is accepted, these helpers emit the local replacement IR.

- `src/passes/heap2local.mbt`
  - `h2l_alloc_field_locals(...)` allocates one local per struct field.
  - `h2l_alloc_array_element_locals(...)` allocates one local per array slot.
  - `h2l_build_init_replacement(...)` lowers supported struct initializers into local sets.
  - `h2l_build_array_init_replacement(...)` lowers supported array initializers into local sets.
  - `h2l_wrap_replacement_with_init(...)`, `h2l_passthrough_child_node(...)`, `h2l_source_requires_tee_init(...)`, `h2l_node_is_block(...)`, `h2l_block_flow_tail_node(...)`, and `h2l_wrap_replacement_with_block_prefix(...)` own the local tee-flow and simple block-result wrapper repair.
  - `h2l_apply_candidate(...)` performs the main struct rewrite.
  - `h2l_apply_array_candidate(...)` performs the direct array rewrite.
  - `h2l_delete_detached_live_nodes(...)` cleans up detached live nodes after the accepted rewrites.

This is the exact local bridge from the shape pages to the code.
If you want to understand why a specific local `tee`, block-result, or array case does or does not rewrite, these helpers are the shortest path.

## 6. Direct ref-op folds that are currently local-only helpers

The local file also folds a few direct ref-operation families outside the main field/element rewrite loop.

- `src/passes/heap2local.mbt`
  - `h2l_ref_eq_null_replacement(...)` plus `h2l_try_fold_direct_ref_eq(...)`
  - `h2l_ref_get_desc_replacement(...)` plus `h2l_try_fold_direct_ref_get_desc(...)`
  - `h2l_array_ref_test_replacement(...)` plus `h2l_try_fold_direct_array_ref_test(...)`

Those helpers explain why the local pass already covers:

- direct `ref.eq` against a fresh nonescaping struct allocation and `ref.null`
- direct `ref.get_desc` on descriptor-bearing allocations
- direct array `ref.test`

but still does **not** claim the full upstream direct-ref surface.

## 7. Top-level pass driver

- `src/passes/heap2local.mbt`
  - `heap2local_run(...)` is the real local pass driver.

It does four things in order:

1. pulls `module_ctx` and `use_def`
2. scans every local for struct and array candidates
3. applies accepted candidate rewrites
4. runs the direct-ref fold helpers and detached-node cleanup

That ordering is the practical summary of current Starshine behavior.
It is much smaller than upstream Binaryen's broader helper stack, but it is the right local mental model.

## What current Starshine already models well

The current in-tree pass covers the green primary suite described in `agent-todo.md` and `src/passes/heap2local_primary_test.mbt`.
That includes:

- direct exclusive struct owners through locals
- exclusive local-copy chains
- direct tee owners
- simple block-result flow
- `ref.as_non_null`
- successful `ref.cast`
- direct `ref.eq` against `ref.null`
- descriptor-bearing `struct.new_desc` / `struct.new_default_desc` with `ref.get_desc`
- constant-size `array.new_default`, `array.new`, and `array.new_fixed`
- constant-index `array.get`, `array.get_s`, `array.get_u`, and `array.set`
- direct array `ref.test`
- bailout on parameter-backed mixed provenance

That is already a meaningful subset of the upstream pass.

## Local evidence surface

The best local proof surface is spread across several files, not just one test file.

- `src/passes/heap2local_test.mbt`
  - focused direct pass tests for struct owners, copy chains, tee owners, block flow, `ref.as_non_null`, successful `ref.cast`, direct `ref.eq`, descriptor-bearing `ref.get_desc`, array lowering, array `ref.test`, and a parameter-backed bailout
- `src/passes/heap2local_primary_test.mbt`
  - broader Binaryen-aligned primary suite covering the main green subset plus the explicit bailout families
- `src/passes/optimize_test.mbt`
  - preset-order evidence showing where `heap2local` sits today in the active `optimize` / `shrink` cluster
- `src/passes/registry_test.mbt`
  - registry and descriptor coverage

Important touched-area hygiene note:

- there is **no** dedicated `heap2local` CLI replay lane in `src/cmd/cmd_wbtest.mbt` today, so this dossier should not imply otherwise.

## What current Starshine does differently from Binaryen

## 1. The local pass depends only on HOT use-def

The registry descriptor currently requires only:

- `@ir.HotAnalysis::use_def()`

That is much smaller than the upstream Binaryen helper stack, which explicitly uses broader escape/exclusivity and fixup machinery.
So the local proof model is simpler and narrower.

## 2. Struct candidates are discovered directly from local write/read shapes

Starshine's candidate finder looks for:

- a non-parameter local
- exactly one write to that local
- that write being `local.set` or `local.tee`
- a directly supported `struct.new` / `struct.new_default` initializer
- a family of reads whose uses all match a limited supported pattern

That is a much more direct local-pattern approach than upstream Binaryen's general child->parent + branch-target flow analyzer.

## 3. Array support is direct, not array->struct->locals

This is the biggest architectural difference.

Upstream Binaryen:

- turns eligible arrays into synthetic structs first
- then reuses the struct scalarization engine

Current Starshine:

- allocates one local per array element directly
- rewrites supported array gets/sets straight to those element locals

That keeps the local implementation smaller, but it also means current Starshine does **not** model all of the type-flow, cast, atomic, and cmpxchg behaviors that upstream gets from the shared struct stage.

## 4. Current local folding of direct ref ops is narrower

The local pass currently folds only a focused direct-use set outside the main candidate machinery:

- `ref.eq` against fresh struct + `ref.null`
- `ref.get_desc` on direct descriptor-bearing allocations
- direct array `ref.test`

That is useful, but it is still smaller than upstream Binaryen's broader direct-ref surface.

## 5. No documented local equivalent of Binaryen's nondefaultable-local fixups

The backlog and parity note still treat this as the main remaining gap.
Binaryen relies on generic pass-runner `TypeUpdating::handleNonDefaultableLocals(...)` plus in-pass refinalization and EH repair.
Current Starshine's HOT pipeline does not currently advertise an equivalent automatic repair layer here.

That is why the backlog still calls out:

- non-nullable-local / refinalization fixups

as the main remaining local `heap2local` gap.

## Current scheduler story in-tree

The local preset tests show that Starshine currently schedules `heap2local` in a simplified mid-function GC slot:

- `remove-unused-brs -> heap2local -> simplify-locals`

That is intentionally smaller than upstream Binaryen's full neighborhood, which continues with:

- `optimize-casts`
- `local-subtyping`
- `coalesce-locals`
- `local-cse`
- `simplify-locals`

So the current Starshine scheduler story is honest but incomplete.
The local slot exists, but several important neighbors are still missing.

## Best current mental model

Upstream Binaryen tells us what `heap2local` means semantically:

- nonescaping + exclusive GC scalarization with real type/atomic/EH repair

Current Starshine tells us what a smaller HOT/use-def implementation already gets right today:

- direct local, tee, block, descriptor, and small-array patterns

When those two stories differ, treat Binaryen `version_129` as the semantic oracle and treat the current Starshine file as the narrower local strategy that still needs to grow.

## What a future local refactor must preserve

If Starshine rewrites this pass again, keep these lessons explicit:

- preserve the distinction between nonescape and exclusivity
- do not treat arrays as fully solved unless the upstream-sized synthetic-struct and type-repair story is really ported
- keep descriptor-bearing support honest
- add nondefaultable-local / refinalization repair instead of papering over it
- keep the preset slot aligned with the future `optimize-casts -> local-subtyping -> coalesce-locals -> local-cse` neighbor cluster
- keep the strong existing parity evidence visible, but do not overstate it as full upstream surface parity
