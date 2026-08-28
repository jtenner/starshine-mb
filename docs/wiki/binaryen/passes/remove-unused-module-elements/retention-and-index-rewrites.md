---
kind: concept
status: supported
last_reviewed: 2026-08-28
sources:
  - ../../release-horizon-and-oracles.md
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/RemoveUnusedModuleElements.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_131/test/lit/passes/remove-unused-module-elements-tables-init.wast
  - ./index.md
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
- Null-only active elem writes can be removed only when doing so cannot expose a callable default or earlier overlapping value and eliminate a trap; imported-table defaults remain unknown.
- A live `ref.func` still needs a declaration source after function compaction; declaration-only active elem segments whose parent table is otherwise dead should be rewritten to declarative elems instead of retaining the dead table.
- A used `call_indirect` / `return_call_indirect` table is kept and analyzed through `rume_use_indirect_call(...)`: matching-type callables are used, matching elems are referenced, and when traps may happen with a table init or possible overlap every active elem is referenced. Strong table users (`table.get` / export / etc.) still queue the table and retain mapped active elems. `traps_never_happen` skips trap-only retention; see [`./indirect-call-trap-preservation.md`](./indirect-call-trap-preservation.md).

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
  `throw`, legacy and typed catch arms, `suspend`, `resume`, `resume_throw`, `resume_throw_ref`, `stack.switch`, resume-handler entries, exports, and name maps.
- Elem and data indices:
  `array.new_elem`, `array.init_elem`, `elem.drop`, `array.new_data`, `array.init_data`, `data.drop`, `memory.init`, `table.init`, name maps, and count sections.
- Function-declaration element modes:
  declaration-only `ref.func` elem users may keep an elem segment solely as a declaration source; if such an elem was active on a dropped table, Starshine rewrites the mode to declarative. The rewrite removes payload entries for dead functions before it remaps survivors, so a large shared declaration segment cannot retain invalid `-1` function remaps. If a retained expression is composite—such as `ref.func; ref.func; struct.new`—all function references inside that indivisible expression remain reference-live together; other independent elem entries can still be pruned. If a segment later becomes runtime-used through `table.init`, `elem.drop`, an active table, or a GC array element operation, liveness clears its declaration-only state and processes the complete payload.

## Metadata Rewrites

- `name_sec` is rewritten through per-kind name maps for functions, locals, labels, tables, memories, globals, elems, data, and tags.
- `func_annotation_sec` is rewritten and filtered to surviving function indices.
- `data_cnt_sec` is rebuilt to match the surviving data-section length.

## Type-section Cleanup After Pruning

The 2026-08-28 implementation fuses direct type-use marking into the existing liveness instruction scan, then adds surviving section roots after element pruning and closes external dependencies with a one-visit worklist. This replaces the dispatcher-level DFE helper that formerly rescanned the full module once per type. Multi-member recursive groups retain the previous fail-closed boundary.

- Current Starshine RUME also compacts dead type entries after ordinary module-element pruning.
- Type liveness and remapping include block/function types, call/ref-call types, GC struct/array/cast/atomic carriers, descriptor relationships, continuation construction/binding, and stack-switching forms.
- The local owner path is:
  - `rume_collect_used_type_flags(...)` in `src/passes/remove_unused_module_elements.mbt`
  - `rume_compact_type_sec(...)` in the same file
  - `dfe_rewrite_module_type_idxs(...)` reused underneath to repair surviving type-index carriers
- This matters because local RUME correctness is not only about value/index carriers like `call`, `memory.init`, or exports.
- Once dead imported functions and dead defined functions disappear, their now-unused function types can disappear too, and every surviving type-bearing surface must stay coherent.

## Practical Rule

- For RUME, an apparently small liveness bug usually becomes a larger rewrite bug if remaps are incomplete.
- When adding or debugging coverage, pair every "drop or keep" fixture with at least one assertion about the surviving rewritten indices.
- For table cleanup, state whether removing a default or overlapping write can expose a callable value and eliminate an indirect-call trap. Binaryen may change one trap kind into another; it may not silently remove the trap under default semantics.
- For EH or stack switching, pair reachability assertions with catch/resume-handler tag remap assertions; keeping the declaration without rewriting the nested carrier is still incorrect.
