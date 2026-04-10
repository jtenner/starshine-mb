---
kind: concept
status: supported
last_reviewed: 2026-04-09
sources:
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

## Metadata Rewrites

- `name_sec` is rewritten through per-kind name maps for functions, locals, labels, tables, memories, globals, elems, data, and tags.
- `func_annotation_sec` is rewritten and filtered to surviving function indices.
- `data_cnt_sec` is rebuilt to match the surviving data-section length.

## Practical Rule

- For RUME, an apparently small liveness bug usually becomes a larger rewrite bug if remaps are incomplete.
- When adding or debugging coverage, pair every "drop or keep" fixture with at least one assertion about the surviving rewritten indices.
