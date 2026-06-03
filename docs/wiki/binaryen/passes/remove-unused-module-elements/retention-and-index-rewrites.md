---
kind: concept
status: supported
last_reviewed: 2026-06-03
sources:
  - ../../../raw/research/0243-2026-04-22-remove-unused-module-elements-primary-sources-and-code-map-followup.md
  - ../../../../../src/passes/remove_unused_module_elements.mbt
  - ../../../../../src/passes/remove_unused_module_elements_test.mbt
related:
  - ./index.md
  - ./wat-shapes.md
  - ./parity.md
---

# `remove-unused-module-elements` Retention And Index Rewrites

## Why This Is Its Own Topic

- RUME correctness is not only about deciding what is dead.
- The pass also has to keep the right imported parents alive and rewrite every surviving module index surface consistently.

## Imported-Parent Retention Rules

- Active element segments can keep imported tables alive.
- Active data segments can keep imported memories alive.
- Zero-byte active data should not keep a memory alive by itself.
- Effect-free null-only active elem initializers should not keep an imported table alive by themselves.
- A live `ref.func` still needs a declaration source after function compaction; declaration-only active elem segments whose parent table is otherwise dead should be rewritten to declarative elems instead of retaining the dead table.

## Current In-Tree Rewrite Surface

- Function indices:
  `call`, `return_call`, `ref.func`, exports, start, element kinds, globals, tables, data initializers, name maps, and function annotations.
- Global indices:
  `global.get`, `global.set`, exports, and name maps.
- Table indices:
  direct table ops, `call_indirect`, `table.init`, `table.copy`, `table.fill`, exports, active elem parents, and name maps.
- Memory indices:
  memargs for loads, stores, atomics, SIMD memory ops, `memory.size`, `memory.grow`, `memory.init`, `memory.copy`, `memory.fill`, active data parents, exports, and name maps.
- Tag indices:
  `throw`, catch arms, exports, and name maps.
- Elem and data indices:
  `array.new_elem`, `array.init_elem`, `elem.drop`, `array.new_data`, `array.init_data`, `data.drop`, `memory.init`, `table.init`, name maps, and count sections.
- Function-declaration element modes:
  declaration-only `ref.func` elem users may keep an elem segment solely as a declaration source; if such an elem was active on a dropped table, Starshine rewrites the mode to declarative while remapping the surviving function indices.

## Metadata Rewrites

- `name_sec` is rewritten through per-kind name maps for functions, locals, labels, tables, memories, globals, elems, data, and tags.
- `func_annotation_sec` is rewritten and filtered to surviving function indices.
- `data_cnt_sec` is rebuilt to match the surviving data-section length.

## Type-section Cleanup After Pruning

- Current Starshine RUME also compacts dead type entries after ordinary module-element pruning.
- The local owner path is:
  - `rume_collect_used_type_flags(...)` in `src/passes/remove_unused_module_elements.mbt`
  - `rume_compact_type_sec(...)` in the same file
  - `dfe_rewrite_module_type_idxs(...)` reused underneath to repair surviving type-index carriers
- This matters because local RUME correctness is not only about value/index carriers like `call`, `memory.init`, or exports.
- Once dead imported functions and dead defined functions disappear, their now-unused function types can disappear too, and every surviving type-bearing surface must stay coherent.

## Practical Rule

- For RUME, an apparently small liveness bug usually becomes a larger rewrite bug if remaps are incomplete.
- When adding or debugging coverage, pair every "drop or keep" fixture with at least one assertion about the surviving rewritten indices.
