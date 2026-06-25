---
kind: research
status: supported
created: 2026-06-25
sources:
  - ../../binaryen/2026-06-20-code-pushing-version-130-source-lit-refresh.md
  - ../../../binaryen/passes/code-pushing/index.md
  - ../../../binaryen/passes/code-pushing/segment-selection-and-barriers.md
  - ../../../../../src/passes/code_pushing.mbt
  - ../../../../../src/passes/code_pushing_test.mbt
---

# Code-pushing table.set segment movement

## Question

Can a pure SFA `local.set` move across an intervening `table.set` before a later `br_if` push point?

This follows the global-state slice in [`0865`](0865-2026-06-25-code-pushing-global-set-movement.md) and narrows another ordered-effect window: `table.set` mutates table state, but the moved value is a pure constant with no table or reference-state read dependency.

## Binaryen v130 probe

Probe path: `.tmp/cp-probes/table-set-before-brif.wat`.

Input shape:

```wat
(module
  (table 1 funcref)
  (func (param i32) (local i32)
    (block $exit
      i32.const 7
      local.set 1
      i32.const 0
      ref.null func
      table.set 0
      local.get 0
      br_if $exit
      local.get 1
      drop)))
```

Commands:

- `wasm-tools parse .tmp/cp-probes/table-set-before-brif.wat -o .tmp/cp-probes/table-set-before-brif.wasm` — passed.
- `wasm-tools validate --features all .tmp/cp-probes/table-set-before-brif.wasm` — passed.
- `wasm-opt --all-features .tmp/cp-probes/table-set-before-brif.wat --code-pushing -S -o -` — passed under local `wasm-opt version 130 (version_130)`.

Binaryen moved the pure SFA set after the `table.set` and after the later `br_if`, preserving the table mutation before the branch and placing the delayed constant computation next to the suffix use.

## Starshine coverage

Added focused test: `code-pushing moves pure SFA set past table.set before br_if push point` in `src/passes/code_pushing_test.mbt`.

The test confirms the existing Starshine segment path already matches the Binaryen-positive shape: the original `local.set` becomes `nop`, the `table.set` remains before the `br_if`, and the cloned `local.set` is inserted after the `br_if` before the suffix `drop` use.

No pass implementation or GenValid profile changed in this slice.

## Validation

- `moon test --target native src/passes/code_pushing_test.mbt --filter '*table.set before br_if*'` — passed `1/1`.

## Audit impact

This closes one narrow table-state ordered-window question for pure values before a later `br_if`. It does **not** prove that table-reading values may cross table mutation, nor that all table effects are safe for broader movable values. Broader table/window combinations, memory writes, trap-sensitive table operations, and multi-set/table-state variants remain open for `[O4Z-AUDIT-CP]`.
