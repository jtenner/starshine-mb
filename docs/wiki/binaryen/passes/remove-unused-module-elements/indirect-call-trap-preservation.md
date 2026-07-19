---
kind: concept
status: supported
last_reviewed: 2026-07-18
sources:
  - ../../release-horizon-and-oracles.md
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/RemoveUnusedModuleElements.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_131/test/lit/passes/remove-unused-module-elements-tables-init.wast
  - https://github.com/WebAssembly/binaryen/blob/version_131/test/lit/passes/remove-unused-module-elements-closed-tnh.wast
  - ../../../../../src/passes/remove_unused_module_elements.mbt
  - ../../../../../src/passes/remove_unused_module_elements_test.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./roots-reference-only-and-nullification.md
  - ./wat-shapes.md
  - ./starshine-hot-ir-strategy.md
  - ./retention-and-index-rewrites.md
  - ./parity.md
---

# RUME, table defaults, overlaps, and `call_indirect` traps

## The short rule

Binaryen v131 asks whether removing an element write can change a trapping `call_indirect` into a successful call. A table-level `ref.func` initializer is a possible callee. If an element segment overwrites that default with null or a wrong-type function, the write may be needed solely to preserve the trap. Likewise, overlapping segments can overwrite a callable value with null or a wrong-type value.

This is a **trap-preservation** rule, not an assertion that every written function is callable. If removing a wrong-type write merely changes the trap to a null-entry trap because no callable default exists, Binaryen may still prune it. `trapsNeverHappen` is the explicit mode that permits more aggressive removal of trap-only writes.

## A concrete shape

```wat
(module
  (type $want (func (result i32)))
  (type $other (func (result i64)))
  (table $t 1 funcref (ref.func $ok))
  (func $ok (type $want) (i32.const 1))
  (func $wrong (type $other) (i64.const 7))
  (elem (table $t) (i32.const 0) func $wrong)
  (func (export "run") (result i32)
    (i32.const 0)
    (call_indirect (table $t) (type $want)))
)
```

At index `0`, `$wrong` overwrites the compatible table default `$ok`. The original call traps on the wrong type. Removing the active element would expose `$ok` and make the call succeed, so default v131 RUME must retain the segment. Without the callable default, replacing the wrong-type entry with null would still trap and can be legal under Binaryen's trap model.

V131 also conservatively retains all active segments for a table when their spans may overlap and traps matter, because a later null or wrong-type write may be the only reason an indirect call traps. The `trapsNeverHappen` mode is the explicit opt-in boundary for more aggressive cleanup.

## What this does and does not keep

This rule can retain an active element segment and the function references it carries. It does **not** mean that RUME gives up on all table cleanup:

- null-only or otherwise semantically no-op active element shapes remain a separate retention question;
- direct table users, `table.init`, `table.copy`, and `table.get` have their own liveness edges;
- a table that cannot be modified has a narrower analysis question; and
- the non-function sibling still uses the same liveness model while preserving defined functions by mode.

Read [`wat-shapes.md`](wat-shapes.md) for the broader module-shape catalog and [`roots-reference-only-and-nullification.md`](roots-reference-only-and-nullification.md) for the strong-use versus reference-only model.

## Starshine mapping

Starshine's module pass in [`src/passes/remove_unused_module_elements.mbt`](../../../../../src/passes/remove_unused_module_elements.mbt) now follows the v131 call-indirect policy:

- `rume_use_indirect_call(...)` keeps the table, uses matching-type callable table-init / elem functions, and only references matching-type element segments.
- When traps may happen and the table has a `ref.func` init or possibly overlapping active segments, every active element for that table is referenced so trap-producing overwrites survive.
- Reference-only functions kept solely for those trap writes are emptied to `unreachable`, matching Binaryen's used-versus-referenced split for this family.
- `traps_never_happen` is threaded from `HotPipelineOptions` into RUME and skips the trap-preserving all-elem retention, so trap-only overwrites can be dropped.

Focused fixtures cover compatible-default overwritten by wrong-type, no-init wrong-type drop, non-overlapping drop, overlapping keep-plus-empty, and the TNH drop boundary.

## Sources

- Binaryen v131 [`RemoveUnusedModuleElements.cpp`](https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/RemoveUnusedModuleElements.cpp), [`remove-unused-module-elements-tables-init.wast`](https://github.com/WebAssembly/binaryen/blob/version_131/test/lit/passes/remove-unused-module-elements-tables-init.wast), and [`remove-unused-module-elements-closed-tnh.wast`](https://github.com/WebAssembly/binaryen/blob/version_131/test/lit/passes/remove-unused-module-elements-closed-tnh.wast)
- [`../../../../../src/passes/remove_unused_module_elements.mbt`](../../../../../src/passes/remove_unused_module_elements.mbt)
- [`../../../../../src/passes/remove_unused_module_elements_test.mbt`](../../../../../src/passes/remove_unused_module_elements_test.mbt)
