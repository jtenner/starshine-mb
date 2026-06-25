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

# Code-pushing memory.init/data.drop root movement

## Question

Can a pure SFA `local.set` move across intervening `memory.init` / `data.drop` roots before a later `br_if` push point?

This distinguishes pure-value movement across memory-segment roots from moving memory-reading, memory-size-dependent, or trap-sensitive candidate values. The question is only about a pure constant value whose computation does not read memory, data-segment state, or trap.

## Binaryen v130 probes

Probe paths:

- `.tmp/cp-probes/memory-init-before-brif.wat`
- `.tmp/cp-probes/data-drop-before-brif.wat`

Representative `memory.init` input shape:

```wat
(module
  (memory 1)
  (data $d "abcd")
  (func (param i32) (local i32)
    (block $exit
      i32.const 7
      local.set 1
      i32.const 0
      i32.const 0
      i32.const 4
      memory.init $d
      local.get 0
      br_if $exit
      local.get 1
      drop)))
```

The `data.drop` probe uses the same local/block/suffix shape with `data.drop $d` in the intervening root position.

Commands:

- `wasm-tools parse .tmp/cp-probes/memory-init-before-brif.wat -o .tmp/cp-probes/memory-init-before-brif.wasm` — passed.
- `wasm-tools validate --features all .tmp/cp-probes/memory-init-before-brif.wasm` — passed.
- `wasm-opt --all-features .tmp/cp-probes/memory-init-before-brif.wat --code-pushing -S -o -` — passed under local `wasm-opt version 130 (version_130)`.
- `wasm-tools parse .tmp/cp-probes/data-drop-before-brif.wat -o .tmp/cp-probes/data-drop-before-brif.wasm` — passed.
- `wasm-tools validate --features all .tmp/cp-probes/data-drop-before-brif.wasm` — passed.
- `wasm-opt --all-features .tmp/cp-probes/data-drop-before-brif.wat --code-pushing -S -o -` — passed under local `wasm-opt version 130 (version_130)`.

Binaryen moved the pure SFA set after the memory-segment root and after the later `br_if`, placing the delayed constant computation next to the suffix use.

## Starshine coverage

Added focused tests in `src/passes/code_pushing_test.mbt`:

- `code-pushing moves pure SFA set past memory.init before br_if push point`
- `code-pushing moves pure SFA set past data.drop before br_if push point`

Both tests confirm the existing Starshine segment path already matches the Binaryen-positive shapes: the original `local.set` becomes `nop`, the memory-segment root remains before the `br_if`, and the cloned `local.set` is inserted after the `br_if` before the suffix `drop` use.

No pass implementation or GenValid profile changed in this slice.

## Validation

- `moon test --target native src/passes/code_pushing_test.mbt --filter '*memory.init before br_if*'` — passed `1/1`.
- `moon test --target native src/passes/code_pushing_test.mbt --filter '*data.drop before br_if*'` — passed `1/1`.

## Audit impact

This closes the narrow pure-value movement question across `memory.init` and `data.drop` roots before a later `br_if`. It does **not** permit memory-reading, memory-size-dependent, data-segment-dependent, or trap-sensitive candidate values to cross memory initialization or data-segment state changes. Broader ordered windows, local-copy dependency chains, and mixed memory/read-write windows remain open for `[O4Z-AUDIT-CP]`.
