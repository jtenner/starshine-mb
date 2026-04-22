---
kind: concept
status: supported
last_reviewed: 2026-04-22
sources:
  - ../../../raw/binaryen/2026-04-22-remove-unused-module-elements-primary-sources.md
  - ../../../raw/research/0243-2026-04-22-remove-unused-module-elements-primary-sources-and-code-map-followup.md
  - ../../../../../src/passes/remove_unused_module_elements.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/remove_unused_module_elements_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./roots-reference-only-and-nullification.md
  - ./retention-and-index-rewrites.md
  - ./parity.md
---

# Starshine strategy for `remove-unused-module-elements`

## First correction

Despite the historical filename, this is **not** a HOT-IR pass in Starshine today.
It is an active **module pass**.
That is the honest description for both the upstream Binaryen contract and the current local implementation.

## Why Starshine keeps it module-scoped

Even upstream Binaryen RUME is whole-module:

- it roots from exports, start, module-level segment structure, and reachable code
- it needs whole-module reachability across functions, globals, tables, memories, tags, elem segments, and data segments
- it rewrites surviving indices across bodies and module sections
- it performs cleanup that cannot be explained as one isolated function-local HOT rewrite

Current Starshine keeps the same module-scoped shape and adds one more local reality:

- after pruning and remapping module elements, the pass also performs dead-type cleanup over the surviving module surface

So the practical rule is simple:

- keep `remove-unused-module-elements` documented and tested as a module pass
- do not force it into HOT-IR terminology just for symmetry with the hot-pass folders

## Public code-location map

### 1. Registry and dispatcher surface

- `src/passes/optimize.mbt:231-240`
  - registers `remove-unused-module-elements` as an active **module pass** entry, not a hot pass
- `src/passes/pass_manager.mbt:8627-8640`
  - dispatches the module-pass name directly to `rume_run_module_pass(...)`
- `src/passes/optimize.mbt:379-402`
  - current public `optimize` / `shrink` presets do **not** include RUME

That already tells readers two important local facts:

- the pass is public and runnable by name
- but its implementation ownership is module-level rather than HOT-function-level

### 2. Root seeding and imported-parent retention

The local root-policy helpers that are easiest to miss live near the middle of `src/passes/remove_unused_module_elements.mbt`:

- `rume_mark_imported_parent_segments(...)` at `:785-835`
- `rume_collect_liveness_with_import_parent_policy(...)` at `:837-953`
- `rume_collect_liveness(...)` at `:955-968`

This is where current Starshine makes the key policy decisions about:

- start-function rooting, including the Binaryen-style no-op start-section drop
- export rooting across all module-element kinds
- active imported-table / imported-memory parent retention for semantically meaningful elem/data initializers
- whether extraction mode should keep or suppress that imported-parent policy

If a future mismatch looks like a keep-versus-drop decision, start here before looking at the remap code.

### 3. Queue-driven whole-module liveness walk

The actual liveness engine is spread across a compact scan/process cluster in the same file:

- `rume_scan_expr(...)` at `:426-445`
- `rume_scan_instruction(...)` at `:447-594`
- `rume_process_func(...)` at `:596-626`
- `rume_process_global(...)` at `:628-658`
- `rume_process_table(...)` at `:660-694`
- `rume_process_mem(...)` at `:696-707`
- `rume_process_elem(...)` at `:709-754`
- `rume_process_data(...)` at `:756-783`

This cluster is the current local equivalent of the upstream `Analyzer` fixed point.
It is where Starshine walks:

- direct calls and `ref.func`
- global/table/memory/tag users
- elem/data segment user ops
- active segment parents
- catch tags and memargs
- nested expression children that keep other module elements alive

The important teaching point is not one individual matcher.
It is the structure: **seed roots, push queue items, then process module elements until the queue stops growing**.

### 4. Surviving-index remap and rewrite surface

The remap and rewrite machinery is the largest local surface because RUME correctness is not just about deciding what is dead.
The main owner cluster is:

- remap builders at `src/passes/remove_unused_module_elements.mbt:970-1128`
- instruction rewrite core at `:1130-1484`
- expression and elem-kind rewrites at `:1486-1554`
- name-section rewrite at `:1657-1717`
- function-annotation rewrite at `:1719-1747`
- module rebuild entrypoint `rume_apply_module_rewrite(...)` at `:2293-2647`

This is where current Starshine rewrites surviving carriers for:

- function, global, table, memory, and tag indices
- elem and data indices
- exports and start
- active segment parents
- code bodies and initializers
- name maps and function annotations
- data-count bookkeeping

Cross-read this page with [`./retention-and-index-rewrites.md`](./retention-and-index-rewrites.md) when you need the shape catalog instead of the code map.

### 5. Post-prune type cleanup

Current Starshine also performs dead-type cleanup after the ordinary module-element rewrite.
That local stage is easy to miss if you stop reading too early.

The key owners are:

- `rume_collect_used_type_flags(...)` at `src/passes/remove_unused_module_elements.mbt:2097-2212`
- `rume_compact_type_sec(...)` at `:2275-2291`

The important local detail is that `rume_compact_type_sec(...)` reuses the wider type-rewrite support through `dfe_rewrite_module_type_idxs(...)` after computing which type entries are still needed.

That gives the current Starshine pass a slightly broader “final cleanup” story than the old strategy page made obvious: it is not only pruning module elements, it is also compacting type-section fallout caused by that pruning.

### 6. Public entrypoints and extraction helper

The public pass entrypoint and the nearby extraction helper sit at the end of the file:

- `rume_extract_functions(...)` at `src/passes/remove_unused_module_elements.mbt:3221-3248`
- `rume_run_module_pass(...)` at `:3250-3260`

The extraction helper is not the public pass itself, but it matters for maintainers because it reuses the same liveness and rewrite machinery with a different root-normalization path and `keep_import_parent_segments = false`.

## Current strengths

- imported-parent retention policy is explicit instead of accidental
- no-op start-section dropping is local, visible, and test-backed
- broad surviving-index rewrite coverage is centralized in one file
- dead imported functions and dead type entries are cleaned up together
- CLI coverage exists in addition to direct module-pass tests

## Current local boundaries

- this is a direct module rewrite, not a lifted per-function HOT pass
- any future HOT-IR-adjacent work would still need a module reconciliation phase at the end
- the boundary-only sibling `remove-unused-non-function-elements` is **not** the same thing as the active implemented pass; keep that split explicit in docs

## Read-along test map

Focused local pass tests live in `src/passes/remove_unused_module_elements_test.mbt`:

- `:779-880`
  - broad survivor remapping across functions, globals, tables, memories, tags, elem segments, data segments, exports, and start
- `:882-908`
  - explicit memarg memory-index rewrite coverage
- `:910-965`
  - imported-parent active segment retention
- `:967-1096`
  - unused imported module-element drop plus survivor remap
- `:1098-1184`
  - imported-function drop plus dead function-type cleanup
- `:1186-1349`
  - Binaryen-style no-op start-section handling families
- `:1352-1447`
  - active data / active elem keep-vs-drop distinctions

CLI coverage lives in `src/cmd/cmd_wbtest.mbt:4046-4183`, which proves the explicit `--remove-unused-module-elements` surface and the unchanged-bytes fast path.

## Practical validation rule

When you need to validate or review current Starshine behavior, read the code in this order:

1. `src/passes/optimize.mbt:231-240`
2. `src/passes/pass_manager.mbt:8627-8640`
3. `src/passes/remove_unused_module_elements.mbt:785-953`
4. `src/passes/remove_unused_module_elements.mbt:426-783`
5. `src/passes/remove_unused_module_elements.mbt:2293-2647`
6. `src/passes/remove_unused_module_elements.mbt:2097-2291`
7. `src/passes/remove_unused_module_elements_test.mbt:779-1447`

That path gives the cleanest local explanation from registry -> dispatcher -> root policy -> liveness engine -> remap engine -> type cleanup -> proof tests.
