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

# Code-pushing table.init/elem.drop root movement

## Question

Can a pure SFA `local.set` move across intervening `table.init` / `elem.drop` roots before a later `br_if` push point?

This distinguishes pure-value movement across table-segment roots from moving table-reading, table-size-dependent, reference-sensitive, or trap-sensitive candidate values. The question is only about a pure constant value whose computation does not read table, element-segment, or reference state.

## Binaryen v130 probes

Probe paths:

- `.tmp/cp-probes/table-init-before-brif.wat`
- `.tmp/cp-probes/elem-drop-before-brif.wat`

Representative `table.init` input shape:

```wat
(module
  (type $t (func))
  (func $f)
  (table 2 funcref)
  (elem $e func $f)
  (func (param i32) (local i32)
    (block $exit
      i32.const 7
      local.set 1
      i32.const 0
      i32.const 0
      i32.const 1
      table.init $e
      local.get 0
      br_if $exit
      local.get 1
      drop)))
```

The `elem.drop` probe uses the same local/block/suffix shape with `elem.drop $e` in the intervening root position.

Commands:

- `wasm-tools parse .tmp/cp-probes/table-init-before-brif.wat -o .tmp/cp-probes/table-init-before-brif.wasm` — passed.
- `wasm-tools validate --features all .tmp/cp-probes/table-init-before-brif.wasm` — passed.
- `wasm-opt --all-features .tmp/cp-probes/table-init-before-brif.wat --code-pushing -S -o -` — passed under local `wasm-opt version 130 (version_130)`.
- `wasm-tools parse .tmp/cp-probes/elem-drop-before-brif.wat -o .tmp/cp-probes/elem-drop-before-brif.wasm` — passed.
- `wasm-tools validate --features all .tmp/cp-probes/elem-drop-before-brif.wasm` — passed.
- `wasm-opt --all-features .tmp/cp-probes/elem-drop-before-brif.wat --code-pushing -S -o -` — passed under local `wasm-opt version 130 (version_130)`.

Binaryen moved the pure SFA set after the table-segment root and after the later `br_if`, placing the delayed constant computation next to the suffix use.

## Starshine coverage

Added focused tests in `src/passes/code_pushing_test.mbt`:

- `code-pushing moves pure SFA set past table.init before br_if push point`
- `code-pushing moves pure SFA set past elem.drop before br_if push point`

Both tests confirm the existing Starshine segment path already matches the Binaryen-positive shapes: the original `local.set` becomes `nop`, the table-segment root remains before the `br_if`, and the cloned `local.set` is inserted after the `br_if` before the suffix `drop` use.

No pass implementation or GenValid profile changed in this slice.

## Validation

- `moon test --target native src/passes/code_pushing_test.mbt --filter '*table.init before br_if*'` — passed `1/1`.
- `moon test --target native src/passes/code_pushing_test.mbt --filter '*elem.drop before br_if*'` — passed `1/1`.

## Audit impact

This closes the narrow pure-value movement question across `table.init` and `elem.drop` roots before a later `br_if`. It does **not** permit table-reading, element-segment-dependent, table-size-dependent, reference-sensitive, or trap-sensitive candidate values to cross table-segment roots. Broader ordered windows, local-copy dependency chains, and mixed table/read-write windows remain open for `[O4Z-AUDIT-CP]`.
