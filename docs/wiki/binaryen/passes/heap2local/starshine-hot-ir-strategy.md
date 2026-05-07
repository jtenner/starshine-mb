---
kind: concept
status: working
last_reviewed: 2026-05-06
sources:
  - ../../../raw/research/0531-2026-05-06-heap2local-direct-revalidation.md
  - ../../../raw/binaryen/2026-04-25-heap2local-current-main-and-code-map.md
  - ../../../raw/binaryen/2026-04-22-heap2local-primary-sources.md
  - ../../../raw/research/0365-2026-04-25-heap2local-current-main-and-code-map.md
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
  - ./implementation-structure-and-tests.md
  - ./validation-fixups-and-special-cases.md
  - ./wat-shapes.md
  - ./parity.md
---

# Current Starshine `heap2local` strategy

This page is the local “what is actually implemented today?” companion to the upstream Binaryen strategy page.
The 2026-04-25 refresh turns the earlier helper-name map into exact MoonBit line ranges so readers can move quickly from the wiki to the implementation. The source-confirmed owner/test map lives in [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md).

## Short version

Current Starshine `src/passes/heap2local.mbt` follows the same broad goal as upstream Binaryen:

- replace some nonescaping GC allocation traffic with locals

But it is not a literal source port of Binaryen `Heap2Local.cpp`.
The local implementation is narrower, more direct, and much more HOT/use-def driven.

## Exact code map

## 1. Registry, summary, and preset placement

Start here when you want to confirm that `heap2local` is live and where the public presets place it.

- `src/passes/heap2local.mbt:2-16`
  - `heap2local_descriptor()` declares the pass name, the only required analysis (`@ir.HotAnalysis::use_def()`), and the invalidation set.
- `src/passes/heap2local.mbt:18-20`
  - `heap2local_summary()` is the registry summary text used elsewhere in the pass catalog.
- `src/passes/optimize.mbt:201-205`
  - `pass_registry_entries()` registers `heap2local` as an active hot pass.
- `src/passes/optimize.mbt:253-257`, `src/passes/optimize.mbt:392-396`, `src/passes/optimize.mbt:265-269`, and `src/passes/optimize.mbt:405-409`
  - `optimize_preset_passes(...)` and `shrink_preset_passes(...)` place it in the current local mid-function GC slot.
- `src/passes/optimize_test.mbt:398-403`
  - `test "optimize preset schedules heap2local in the mid-function GC slot"` locks the exact neighboring order.
- `src/passes/optimize_test.mbt:435-446`
  - the traced-order test proves the local handoff order around `heap2local -> simplify-locals`.
- `src/passes/registry_test.mbt:2-31`, `src/passes/registry_test.mbt:102-133`, and `src/passes/registry_test.mbt:146-160`
  - registry classification, descriptor requirement, and preset roster coverage keep the registry and descriptor contract explicit.

## 2. Dispatcher entry point

- `src/passes/pass_manager.mbt:8698`
  - `hot_pass_run(...)` dispatches the public pass name `"heap2local"` directly to `heap2local_run(ctx, func)`.

Important local nuance:

- unlike some other Starshine passes, this path does **not** have a dedicated pass-manager raw prefilter or special-case dispatcher branch beyond the standard hot-pass dispatch.
- the real semantics live in `heap2local_run(...)` itself, not in a separate pass-manager raw-skip layer.

## 3. Struct candidate discovery

This is the main local owner-analysis surface.

- `src/passes/heap2local.mbt:84-145`
  - `h2l_supported_struct_new_fields(...)`, `h2l_is_direct_struct_alloc(...)`, and `h2l_direct_descriptor_alloc_info(...)` recognize supported `struct.new`, `struct.new_default`, and descriptor-bearing fresh allocations.
- `src/passes/heap2local.mbt:147-466`
  - field-index, exact-field-user, local-owner, passthrough, block-flow, and supported-use collection helpers gate the direct field-use families that Starshine currently accepts.
- `src/passes/heap2local.mbt:468-558`
  - `h2l_find_candidate_for_local(...)` is the top-level struct candidate matcher: non-parameter local, exactly one write, supported owner, supported read/copy family, and nonempty use set.

This is where the biggest local-vs-upstream difference shows up most clearly.
Binaryen teaches `heap2local` through `EscapeAnalyzer`, parent walking, branch-target flow, and exclusivity proofs.
Starshine teaches it through a much narrower one-write local owner plus exact supported-use family matcher.

## 4. Array candidate discovery

Current Starshine does support arrays, but through a simpler direct element-localization path rather than upstream Binaryen's array-to-synthetic-struct stage.

- `src/passes/heap2local.mbt:562-658`
  - `h2l_supported_array_init(...)` accepts the current local array subset: `array.new_default`, `array.new`, and `array.new_fixed` with constant size and the existing `< 20` cap.
- `src/passes/heap2local.mbt:660-725`
  - `h2l_collect_array_use(...)` accepts the current local use subset: constant-index `array.get`, `array.get_s`, `array.get_u`, and `array.set`.
- `src/passes/heap2local.mbt:695-748`
  - `h2l_find_array_candidate_for_local(...)` ties owner-local checks, supported initializer checks, and supported uses together into the direct array candidate matcher.

That direct path is simpler than Binaryen, but it also means local Starshine does **not** inherit the larger upstream shared struct-stage handling for many type-flow, atomic, and cmpxchg cases.

## 5. Rewrite helpers and emitted shapes

Once a candidate is accepted, these helpers emit the local replacement IR.

- `src/passes/heap2local.mbt:750-1054`
  - local allocation, struct initializer, array initializer, tee-wrapper, and simple block-result wrapper helpers prepare replacement IR.
- `src/passes/heap2local.mbt:1164-1216`
  - `h2l_apply_array_candidate(...)` performs the direct array rewrite into element locals.
- `src/passes/heap2local.mbt:1219-1347`
  - `h2l_apply_candidate(...)` performs the main struct rewrite into field locals, including tee/block wrapper repair and detached-node bookkeeping.
- `src/passes/heap2local.mbt:1349-1376`
  - `h2l_delete_detached_live_nodes(...)` cleans up detached live nodes after accepted rewrites.

This is the exact local bridge from the shape pages to the code.
If you want to understand why a specific local `tee`, block-result, or array case does or does not rewrite, these helpers are the shortest path.

## 6. Direct ref-op folds that are currently local-only helpers

The local file also folds a few direct ref-operation families outside the main field/element rewrite loop.

- `src/passes/heap2local.mbt:986-1054`
  - replacement builders for fresh-struct `ref.eq` against null, descriptor `ref.get_desc`, and direct array `ref.test`.
- `src/passes/heap2local.mbt:1056-1159`
  - `h2l_try_fold_direct_ref_eq(...)`, `h2l_try_fold_direct_ref_get_desc(...)`, and `h2l_try_fold_direct_array_ref_test(...)` apply those folds.

Those helpers explain why the local pass already covers:

- direct `ref.eq` against a fresh nonescaping struct allocation and `ref.null`
- direct `ref.get_desc` on descriptor-bearing allocations
- direct array `ref.test`

but still does **not** claim the full upstream direct-ref surface.

## 7. Top-level pass driver

- `src/passes/heap2local.mbt:1379-1442`
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

A 2026-05-06 direct revalidation ran `moon info`, `moon fmt`, `moon test`, and `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass heap2local --out-dir .tmp/pass-fuzz-heap2local`. The compare lane reached 6759/10000 compared cases with 6759 normalized matches, 0 mismatches, and 20 known Binaryen empty-recursion-group parser/canonicalization command failures.

The best local proof surface is spread across several files, not just one test file.

- `src/passes/heap2local_test.mbt:86-453`
  - focused direct pass tests for struct owners, copy chains, tee owners, block flow, `ref.as_non_null`, successful `ref.cast`, direct `ref.eq`, descriptor-bearing `ref.get_desc`, array lowering, array `ref.test`, and a parameter-backed bailout.
- `src/passes/heap2local_primary_test.mbt:158-568`
  - broader Binaryen-aligned primary suite covering the main green subset plus the explicit bailout families.
- `src/passes/optimize_test.mbt:398-403` and `src/passes/optimize_test.mbt:435-446`
  - preset-order evidence showing where `heap2local` sits today and how its output reaches `simplify-locals` in the active local pipeline.
- `src/passes/registry_test.mbt:2-31`, `src/passes/registry_test.mbt:102-133`, and `src/passes/registry_test.mbt:146-160`
  - registry, descriptor, and roster coverage.

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

The old backlog used to treat this as the main remaining `heap2local` gap.
Binaryen still relies on generic pass-runner `TypeUpdating::handleNonDefaultableLocals(...)` plus in-pass refinalization and EH repair.
Current Starshine still does not advertise an equivalent automatic repair layer here.

However, the 2026-05-08 backlog-closure review moved that concern out of the active `heap2local` queue:

- validator-accepted open-world Starshine inputs still reject nondefaultable locals before `heap2local` can run,
- so this remains an upstream/source-contract note, not a live direct-parity blocker in today's pass surface.

## Current scheduler story in-tree

The local preset tests originally showed only a simplified mid-function GC slot:

- `remove-unused-brs -> heap2local -> simplify-locals`

That is no longer the whole story.
The exact neighboring cleanup cluster is now represented in-tree via the public `optimize-casts` placement and its proved follow-up chain:

- `heap2local -> optimize-casts -> local-subtyping -> coalesce-locals -> local-cse -> simplify-locals`

So the old “important neighbors are still missing” wording is now stale.
What remains outside Starshine is the broader upstream nondefaultable-local / refinalization repair surface, not the ordinary no-DWARF neighbor slot.

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
- keep the upstream nondefaultable-local / refinalization contract documented even though it is outside today's validator-accepted Starshine input surface
- keep the now-landed `optimize-casts -> local-subtyping -> coalesce-locals -> local-cse` neighbor cluster explicit whenever scheduler docs are refreshed
- keep the strong existing parity evidence visible, but do not overstate it as full upstream surface parity

## Sources

- [`../../../raw/binaryen/2026-04-25-heap2local-current-main-and-code-map.md`](../../../raw/binaryen/2026-04-25-heap2local-current-main-and-code-map.md)
- [`../../../raw/binaryen/2026-04-22-heap2local-primary-sources.md`](../../../raw/binaryen/2026-04-22-heap2local-primary-sources.md)
- [`../../../raw/research/0365-2026-04-25-heap2local-current-main-and-code-map.md`](../../../raw/research/0365-2026-04-25-heap2local-current-main-and-code-map.md)
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
- [`../../../../../src/passes/heap2local.mbt`](../../../../../src/passes/heap2local.mbt)
- [`../../../../../src/passes/heap2local_test.mbt`](../../../../../src/passes/heap2local_test.mbt)
- [`../../../../../src/passes/heap2local_primary_test.mbt`](../../../../../src/passes/heap2local_primary_test.mbt)
