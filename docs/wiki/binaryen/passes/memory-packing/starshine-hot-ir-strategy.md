---
kind: concept
status: supported
last_reviewed: 2026-04-22
sources:
  - ../../../raw/binaryen/2026-04-22-memory-packing-primary-sources.md
  - ../../../raw/research/0137-2026-04-20-memory-packing-binaryen-research.md
  - ../../../raw/research/0204-2026-04-21-memory-packing-source-confirmation-followup.md
  - ../../../raw/research/0252-2026-04-22-memory-packing-primary-sources-and-code-map-followup.md
  - ../../../../../src/passes/memory_packing.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/memory_packing_test.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../../agent-todo.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./segment-op-rewrites-and-traps.md
  - ./wat-shapes.md
  - ./parity.md
  - ../remove-unused-module-elements/index.md
  - ../once-reduction/index.md
---

# Starshine `memory-packing` strategy today

This page describes the **current in-tree Starshine implementation**, not the full upstream Binaryen `version_129` contract.

## Short version

Starshine currently implements a deliberately narrow **module-pass** subset of `memory-packing` focused on:

- one-memory-only legality gating
- constant i32/i64 active data offsets
- zero/nonzero range collection for active segments
- merging back across small zero runs with a fixed threshold of `8`
- top-byte retention when startup trap behavior must survive
- overlap bailout for active segments
- `data_count` section repair after segment-count changes

That is already useful and artifact-proven.

But it is still much smaller than upstream Binaryen `MemoryPacking.cpp`, which also rewrites active segment ops, analyzes passive segment users, inserts `memory.fill`, rewrites `data.drop`, creates lazy drop-state globals, honors `zeroFilledMemory` for imported memory, and enforces `MaxDataSegments` limits.

## Current rule about the filename

Despite the folder schema name `starshine-hot-ir-strategy.md`, this pass does **not** currently have a HOT-IR implementation.
It is intentionally a module pass.

That is the right shape for this pass because even the narrow local implementation still needs whole-module access to:

- memory declarations and imports
- all data segments together
- active-segment overlap checks
- output `data_count` repair
- preset/module-pass scheduling boundaries

## Exact local code map

## 1. Public summary and registry identity

The user-visible local pass identity starts in [`src/passes/memory_packing.mbt`](../../../../../src/passes/memory_packing.mbt):

- `memory_packing_summary()`
  - currently promises: “Split active data segments around profitable zero ranges while preserving startup memory semantics.”

That summary is intentionally narrower than upstream Binaryen and still matches the code.

The pass also appears in the registry and preset expansions in [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt):

- `pass_registry_entries()`
  - exposes `memory-packing` as an active **module pass**
- the `optimize` preset list
- the `shrink` preset list
  - both place `memory-packing` at the front of the current module-pass prefix, before `once-reduction`, `global-refining`, and `global-struct-inference`

The module-pass category is also locked in [`src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt) by:

- `pass_registry_category("memory-packing") == module_pass`
- the preset-expansion test that keeps `memory-packing` at the front of both public presets

## 2. Memory and offset helpers

The first helper cluster in [`src/passes/memory_packing.mbt`](../../../../../src/passes/memory_packing.mbt) is the module-shape and offset layer:

- `mp_imported_mem_count(...)`
  - counts imported memories and currently forces a hard local bailout when nonzero
- `mp_defined_mem_count(...)`
  - counts defined memories
- `mp_defined_memory_size_bytes(...)`
  - computes the defined memory's initial size in bytes for either memory32 or memory64 declarations
- `mp_parse_base_offset(...)`
  - accepts only exact `i32.const` and exact `i64.const` active offsets
- `mp_base_offset_u64(...)`
- `mp_shift_base_offset(...)`
  - turn parsed offsets back into rewritten active data offsets after a kept-range shift

This cluster is the first big Binaryen/Starshine divergence:
local Starshine has no generic segment-user analysis and no broader offset reasoning here.
It only knows how to reason about exact constant active offsets.

## 3. Range collection and profitability helpers

The second helper cluster in [`src/passes/memory_packing.mbt`](../../../../../src/passes/memory_packing.mbt) owns the current active-segment rewrite mechanics:

- `mp_slice_bytes(...)`
  - extracts a surviving kept range
- `mp_collect_ranges(...)`
  - scans one active segment into alternating zero and nonzero ranges
- `mp_merge_small_zero_ranges(...)`
  - merges back across zero runs whose width is `<= 8`
- `mp_preserve_trapping_top_byte(...)`
  - rewrites a final all-zero tail so the last byte still gets written when trap preservation matters
- `mp_should_preserve_trap(...)`
  - decides whether the active write might extend past the defined initial memory and therefore must keep the top-byte write effect

This is the local equivalent of only a thin slice of upstream `calculateRanges(...)`.
It models:

- active-only profitability
- a fixed small-zero threshold
- top-byte trap retention

It does **not** model:

- passive edge thresholds
- passive metadata/code-size overhead
- drop-state bookkeeping
- `memory.init` replacement planning
- `MaxDataSegments`

## 4. The actual active-segment rewrite

The active-segment transformer in [`src/passes/memory_packing.mbt`](../../../../../src/passes/memory_packing.mbt) is:

- `mp_active_rewrite(...)`

That function owns the current local rewrite contract:

- bail out unchanged on empty segments
- bail out unchanged on nonconstant active offsets
- collect zero/nonzero runs
- merge small zero runs back into neighbors
- preserve the top byte if startup trap behavior must remain observable
- emit only nonzero kept ranges as rewritten active data segments with shifted offsets

So the local pass is genuinely doing a semantics-aware active split.
But it is still just the active subset.
There is no local equivalent here of upstream:

- `optimizeSegmentOps(...)`
- `getSegmentReferrers(...)`
- `dropUnusedSegments(...)`
- `createReplacements(...)`
- `replaceSegmentOps(...)`

## 5. Whole-module legality gate

The next critical owner in [`src/passes/memory_packing.mbt`](../../../../../src/passes/memory_packing.mbt) is:

- `mp_can_optimize(...)`

This function is the real current Starshine legality proof.
It requires:

- no imported memories
- exactly one total memory when defined plus imported memories are counted together
- memory index `0` for every active segment
- exact constant active offsets when multiple active segments exist
- no active-segment overlap
- no unsigned overflow while computing active segment end offsets

That is narrower than upstream Binaryen in two important ways:

- imported memory is always a hard local bailout, instead of an optional `zeroFilledMemory` mode
- passive-segment users are not analyzed at all, because passive segments are not rewritten locally

## 6. Module-pass driver and output repair

The actual public module-pass entry point in [`src/passes/memory_packing.mbt`](../../../../../src/passes/memory_packing.mbt) is:

- `memory_packing_run_module_pass(...)`

That driver owns:

- reading the module `data_sec`
- applying `mp_can_optimize(...)`
- rewriting active segments through `mp_active_rewrite(...)`
- leaving passive segments untouched
- detecting whether anything changed
- rebuilding `data_sec`
- recomputing `data_cnt_sec` when the module already had one
- rebuilding the full `@lib.Module`

The `data_count` rewrite matters because it is part of why the current local subset can still be a correct module pass rather than only a byte-array helper.

## 7. Pipeline dispatch

The actual module-pass dispatcher is in [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt):

- `"memory-packing" => memory_packing_run_module_pass(mod_)`

That is the exact code location where the public pipeline turns the registry name into the module rewrite.

Unlike some other recently refreshed implemented-pass dossiers, `memory-packing` does **not** currently have a dedicated artifact-failure guard cluster in `pass_manager.mbt`.
The interesting local story here is the explicit module-pass dispatch, not extra writeback hardening.

## What the current proof surface looks like

## 1. Main pass-local behavior tests

[`src/passes/memory_packing_test.mbt`](../../../../../src/passes/memory_packing_test.mbt) is the primary local semantic proof lane.

Important focused tests include:

- `run_hot_pipeline applies memory-packing to profitable active zero ranges`
  - proves the active leading-zero trim that keeps only the `ABC` suffix at offset `9`
- `memory-packing preserves trapping active segments by keeping the top byte`
  - proves the out-of-bounds-startup-trap family by keeping the final byte at offset `65536`
- `memory-packing bails out when active segments overlap`
  - proves the whole-module overlap bailout and leaves `data_sec` unchanged

Those tests are small, but they lock the real currently implemented subset.

## 2. Registry and preset proof

[`src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt) proves the public registry surface:

- `memory-packing` is categorized as a module pass
- both public presets begin with the same early module-pass prefix that includes `memory-packing`

[`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) is the source of truth for that same preset order.

## 3. CLI replay evidence

[`src/cmd/cmd_wbtest.mbt`](../../../../../src/cmd/cmd_wbtest.mbt) does not currently have a dedicated single-pass `memory-packing` replay lane.
The nearest committed CLI evidence is the debug-artifact optimize-prefix replay that includes:

- `--memory-packing`
- `--once-reduction`
- `--global-refining`
- `--global-struct-inference`
- and the early hot-pass prefix after them

That is weaker than a dedicated pass-local replay, so future parity work should keep that limitation explicit instead of overstating the current proof surface.

## Current semantic boundary versus upstream Binaryen

## What Starshine does implement today

Current Starshine `memory-packing` implements:

- active constant-offset segment scanning
- active zero/nonzero range splitting
- small-zero-run merge-back with threshold `8`
- startup-trap-preserving top-byte retention
- one-memory-only and overlap legality gating
- passive-segment pass-through
- `data_count` repair after rewritten segment counts
- explicit module-pass scheduling in the public presets

## What Starshine still does **not** implement

Compared with upstream Binaryen `version_129`, the local pass still lacks:

- active-segment `memory.init` / `data.drop` simplification
- passive-segment splitting and referrer collection
- `memory.init` replacement planning
- `memory.fill` insertion for zero slices
- `data.drop` expansion into surviving split segments
- lazy drop-state globals
- imported-memory `zeroFilledMemory` mode
- GC `array.new_data` / `array.init_data` conservative boundaries
- `MaxDataSegments` limiting

So the honest short description of current Starshine remains:

- **active constant-offset module-level segment packing with overlap and trap guards**

not:

- a full port of Binaryen `MemoryPacking.cpp`

## Practical follow-along path

If you want to read the local implementation in code order, use this path:

1. [`src/passes/memory_packing.mbt`](../../../../../src/passes/memory_packing.mbt)
   - summary, memory/offset helpers, range helpers, legality gate, and module-pass driver
2. [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
   - module-pass dispatch inside the public pipeline
3. [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
   - registry entry plus early preset placement
4. [`src/passes/memory_packing_test.mbt`](../../../../../src/passes/memory_packing_test.mbt)
   - focused active-split, trap-preservation, and overlap-bailout tests
5. [`src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt)
   - module-pass category and preset-expansion proof
6. [`src/cmd/cmd_wbtest.mbt`](../../../../../src/cmd/cmd_wbtest.mbt)
   - nearest committed optimize-prefix artifact replay evidence

## Bottom line

The local page is more useful now as an exact code map:

- what file owns which behavior,
- where the module legality and active-range logic live,
- where the public scheduler slot is defined,
- which tests lock the current contract,
- and which major Binaryen surfaces are still missing.

That keeps the Starshine side beginner-readable while still giving advanced readers a concrete path from the living wiki into the MoonBit implementation.
