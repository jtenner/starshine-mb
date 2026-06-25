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

# Code-pushing memory.size/table.size root movement

## Question

Can a pure SFA `local.set` move across intervening dropped `memory.size` / `table.size` roots before a later `br_if` push point?

This distinguishes pure-value movement across size-read roots from moving size-dependent candidate values. The question is only about a pure constant value whose computation does not read memory or table state. It is not a claim that a `memory.size`, `table.size`, `memory.grow`, `table.grow`, load, or table-read candidate value may cross matching state changes.

## Binaryen v130 probes

Probe paths:

- `.tmp/cp-probes/memory-size-before-brif.wat`
- `.tmp/cp-probes/table-size-before-brif.wat`

Representative input shape:

```wat
(module
  (memory 1)
  (func (param i32) (local i32)
    (block $exit
      i32.const 7
      local.set 1
      memory.size
      drop
      local.get 0
      br_if $exit
      local.get 1
      drop)))
```

The `table.size` probe uses `(table 1 funcref)` and `table.size 0` in the same dropped-root position.

Commands:

- `wasm-tools parse .tmp/cp-probes/memory-size-before-brif.wat -o .tmp/cp-probes/memory-size-before-brif.wasm` — passed.
- `wasm-tools validate --features all .tmp/cp-probes/memory-size-before-brif.wasm` — passed.
- `wasm-opt --all-features .tmp/cp-probes/memory-size-before-brif.wat --code-pushing -S -o -` — passed under local `wasm-opt version 130 (version_130)`.
- `wasm-tools parse .tmp/cp-probes/table-size-before-brif.wat -o .tmp/cp-probes/table-size-before-brif.wasm` — passed.
- `wasm-tools validate --features all .tmp/cp-probes/table-size-before-brif.wasm` — passed.
- `wasm-opt --all-features .tmp/cp-probes/table-size-before-brif.wat --code-pushing -S -o -` — passed under local `wasm-opt version 130 (version_130)`.

Binaryen moved the pure SFA set after the dropped size-read root and after the later `br_if`, placing the delayed constant computation next to the suffix use.

## Starshine coverage

Added focused tests in `src/passes/code_pushing_test.mbt`:

- `code-pushing moves pure SFA set past memory.size before br_if push point`
- `code-pushing moves pure SFA set past table.size before br_if push point`

Both tests confirm the existing Starshine segment path already matches the Binaryen-positive shapes: the original `local.set` becomes `nop`, the dropped size-read root remains before the `br_if`, and the cloned `local.set` is inserted after the `br_if` before the suffix `drop` use.

No pass implementation or GenValid profile changed in this slice.

## Validation

- `moon test --target native src/passes/code_pushing_test.mbt --filter '*memory.size before br_if*'` — passed `1/1`.
- `moon test --target native src/passes/code_pushing_test.mbt --filter '*table.size before br_if*'` — passed `1/1`.

## Audit impact

This closes the narrow pure-value movement question across dropped size-read roots before a later `br_if`. It does **not** permit size-dependent candidate values to cross memory/table growth or mutation. Broader mixed read/write windows, multi-set size-read windows, and trap-option-sensitive roots remain open for `[O4Z-AUDIT-CP]`.
