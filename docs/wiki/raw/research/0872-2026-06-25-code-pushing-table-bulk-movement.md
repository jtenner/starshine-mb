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

# Code-pushing table.copy/table.fill segment movement

## Question

Can a pure SFA `local.set` move across intervening table bulk operations before a later `br_if` push point?

This extends the pure-value table ordered-window probes after [`0866`](0866-2026-06-25-code-pushing-table-set-movement.md) and [`0869`](0869-2026-06-25-code-pushing-table-grow-movement.md). The question is only about a pure constant value. It is not a claim that `table.get`, `table.size`, reference-sensitive table values, or trap-sensitive values may cross table bulk mutation.

## Binaryen v130 probes

Probe paths:

- `.tmp/cp-probes/table-copy-before-brif.wat`
- `.tmp/cp-probes/table-fill-before-brif.wat`

Representative input shape:

```wat
(module
  (table 2 funcref)
  (func (param i32) (local i32)
    (block $exit
      i32.const 7
      local.set 1
      i32.const 1
      i32.const 0
      i32.const 1
      table.copy 0 0
      local.get 0
      br_if $exit
      local.get 1
      drop)))
```

The `table.fill` probe uses `i32.const 0`, `ref.null func`, and `i32.const 1` before `table.fill 0`.

Commands:

- `wasm-tools parse .tmp/cp-probes/table-copy-before-brif.wat -o .tmp/cp-probes/table-copy-before-brif.wasm` — passed.
- `wasm-tools validate --features all .tmp/cp-probes/table-copy-before-brif.wasm` — passed.
- `wasm-opt --all-features .tmp/cp-probes/table-copy-before-brif.wat --code-pushing -S -o -` — passed under local `wasm-opt version 130 (version_130)`.
- `wasm-tools parse .tmp/cp-probes/table-fill-before-brif.wat -o .tmp/cp-probes/table-fill-before-brif.wasm` — passed.
- `wasm-tools validate --features all .tmp/cp-probes/table-fill-before-brif.wasm` — passed.
- `wasm-opt --all-features .tmp/cp-probes/table-fill-before-brif.wat --code-pushing -S -o -` — passed under local `wasm-opt version 130 (version_130)`.

Binaryen moved the pure SFA set after `table.copy` / `table.fill` and after the later `br_if`, placing the delayed constant computation next to the suffix use.

## Starshine coverage

Added focused tests in `src/passes/code_pushing_test.mbt`:

- `code-pushing moves pure SFA set past table.copy before br_if push point`
- `code-pushing moves pure SFA set past table.fill before br_if push point`

Both tests confirm the existing Starshine segment path already matches the Binaryen-positive shapes: the original `local.set` becomes `nop`, the table bulk root remains before the `br_if`, and the cloned `local.set` is inserted after the `br_if` before the suffix `drop` use.

No pass implementation or GenValid profile changed in this slice.

## Validation

- `moon test --target native src/passes/code_pushing_test.mbt --filter '*table.copy before br_if*'` — passed `1/1`.
- `moon test --target native src/passes/code_pushing_test.mbt --filter '*table.fill before br_if*'` — passed `1/1`.

## Audit impact

This closes two narrow table bulk ordered-window questions for pure values before a later `br_if`. It does **not** allow table-reading, table-size-dependent, reference-sensitive, or trap-sensitive values to cross table bulk mutation. Broader `table.init` / `elem.drop`, multi-set table windows, and reference-carrying variants remain open for `[O4Z-AUDIT-CP]`.
