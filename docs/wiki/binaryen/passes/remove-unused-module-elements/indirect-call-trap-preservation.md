---
kind: concept
status: supported
last_reviewed: 2026-07-11
sources:
  - ../../../raw/binaryen/2026-07-11-remove-unused-module-elements-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-22-remove-unused-module-elements-primary-sources.md
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

# RUME, `call_indirect`, and wrong-type trap preservation

## The short rule

A module cleanup pass must not remove a table initializer merely because no direct call names its function. A later `call_indirect` can observe whether the selected table entry is:

1. null, which traps because there is no function; or
2. non-null but has the wrong function type, which traps for a different reason.

Binaryen RUME preserves that distinction by retaining relevant active element segments for a mutable indirect-call table unless the optimizer is explicitly allowed to disregard traps with `trapsNeverHappen`.

This is a **trap-preservation** rule, not an assertion that every table entry is an ordinary call-graph root.

## A concrete shape

```wat
(module
  (type $want (func (result i32)))
  (type $other (func (result i64)))
  (table $t 1 funcref)
  (func $wrong (type $other) (i64.const 7))
  (elem (table $t) (i32.const 0) func $wrong)
  (func (export "run") (result i32)
    (i32.const 0)
    (call_indirect (table $t) (type $want)))
)
```

At index `0`, `$wrong` is non-null but incompatible with `$want`. Removing the active element would make the entry null instead. Both executions trap, but they are not the same table state and optimizers must not generally replace one observable trap condition with another.

Binaryen's current owner therefore treats a mutable indirect-call table specially when traps matter. The `trapsNeverHappen` mode is the explicit opt-in boundary that can allow a more aggressive cleanup result.

## What this does and does not keep

This rule can retain an active element segment and the function references it carries. It does **not** mean that RUME gives up on all table cleanup:

- null-only or otherwise semantically no-op active element shapes remain a separate retention question;
- direct table users, `table.init`, `table.copy`, and `table.get` have their own liveness edges;
- a table that cannot be modified has a narrower analysis question; and
- the non-function sibling still uses the same liveness model while preserving defined functions by mode.

Read [`wat-shapes.md`](wat-shapes.md) for the broader module-shape catalog and [`roots-reference-only-and-nullification.md`](roots-reference-only-and-nullification.md) for the strong-use versus reference-only model.

## Starshine mapping

Starshine has an active module pass in [`src/passes/remove_unused_module_elements.mbt`](../../../../../src/passes/remove_unused_module_elements.mbt):

- `rume_scan_instruction(...)` marks a table used for `CallIndirect` and `ReturnCallIndirect`.
- `rume_process_table(...)` walks the local table-to-active-element map and marks every active element segment for that used table.
- `rume_process_elem(...)` then retains the active parent and its function/expression dependencies.

That conservative flow preserves the relevant default trap-sensitive table state. It is intentionally less precise than Binaryen's source-level distinction because Starshine currently applies active-element retention to every used table and has no `trapsNeverHappen` variant.

## Current evidence and gap status

The focused local suite covers active-element keep/drop and imported-parent retention, but no test currently isolates the wrong-type `call_indirect` trap shape above. Therefore:

- **not a known semantic mismatch:** the current local table policy is conservative for this shape;
- **not a parity win claim:** no size or pass-local measurement proves that the coarser local policy is better;
- **open coverage/output-shape boundary:** add direct wrong-type-versus-null indirect-call fixtures before making table-retention cleanup more aggressive or adding a traps-never-happen mode.

A future fixture should assert both that the module validates after RUME and that the element/function needed to preserve the wrong-type table state remains present under default semantics. If a traps-never-happen mode is added, it needs a separately documented policy and must not reuse default-mode parity evidence.

## Sources

- [`../../../raw/binaryen/2026-07-11-remove-unused-module-elements-current-main-recheck.md`](../../../raw/binaryen/2026-07-11-remove-unused-module-elements-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-22-remove-unused-module-elements-primary-sources.md`](../../../raw/binaryen/2026-04-22-remove-unused-module-elements-primary-sources.md)
- [`../../../../../src/passes/remove_unused_module_elements.mbt`](../../../../../src/passes/remove_unused_module_elements.mbt)
- [`../../../../../src/passes/remove_unused_module_elements_test.mbt`](../../../../../src/passes/remove_unused_module_elements_test.mbt)
