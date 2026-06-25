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

# Code-pushing table.grow segment movement

## Question

Can a pure SFA `local.set` move across an intervening `table.grow` before a later `br_if` push point?

This follows the pure-value state-write/growth ordered-window probes through [`0868`](0868-2026-06-25-code-pushing-memory-grow-movement.md). The question is only about a pure constant value. It is not a claim that `table.size`, `table.get`, reference-producing table reads, or trap-sensitive values may cross table growth.

## Binaryen v130 probe

Probe path: `.tmp/cp-probes/table-grow-before-brif.wat`.

Input shape:

```wat
(module
  (table 1 funcref)
  (func (param i32) (local i32)
    (block $exit
      i32.const 7
      local.set 1
      ref.null func
      i32.const 1
      table.grow 0
      drop
      local.get 0
      br_if $exit
      local.get 1
      drop)))
```

Commands:

- `wasm-tools parse .tmp/cp-probes/table-grow-before-brif.wat -o .tmp/cp-probes/table-grow-before-brif.wasm` — passed.
- `wasm-tools validate --features all .tmp/cp-probes/table-grow-before-brif.wasm` — passed.
- `wasm-opt --all-features .tmp/cp-probes/table-grow-before-brif.wat --code-pushing -S -o -` — passed under local `wasm-opt version 130 (version_130)`.

Binaryen moved the pure SFA set after the dropped `table.grow` result and after the later `br_if`, placing the delayed constant computation next to the suffix use.

## Starshine coverage

Added focused test: `code-pushing moves pure SFA set past table.grow before br_if push point` in `src/passes/code_pushing_test.mbt`.

The test confirms the existing Starshine segment path already matches the Binaryen-positive shape: the original `local.set` becomes `nop`, the dropped `table.grow` root remains before the `br_if`, and the cloned `local.set` is inserted after the `br_if` before the suffix `drop` use.

No pass implementation or GenValid profile changed in this slice.

## Validation

- `moon test --target native src/passes/code_pushing_test.mbt --filter '*table.grow before br_if*'` — passed `1/1`.

## Audit impact

This closes one narrow table-growth ordered-window question for pure values before a later `br_if`. It does **not** allow table-size-dependent values, table reads, reference-sensitive table state, or trap-sensitive operations to cross `table.grow`. Broader table bulk operations, multi-set windows involving table effects, and trap-option-specific behavior remain open for `[O4Z-AUDIT-CP]`.
