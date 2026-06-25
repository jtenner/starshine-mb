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

# Code-pushing memory.grow segment movement

## Question

Can a pure SFA `local.set` move across an intervening `memory.grow` before a later `br_if` push point?

This extends the pure-value ordered-window probes after [`0865`](0865-2026-06-25-code-pushing-global-set-movement.md), [`0866`](0866-2026-06-25-code-pushing-table-set-movement.md), and [`0867`](0867-2026-06-25-code-pushing-memory-store-movement.md). The question is only about a pure constant value. It is not a claim that `memory.size`, loads, heap reads, or trap-sensitive values may cross memory growth.

## Binaryen v130 probe

Probe path: `.tmp/cp-probes/memory-grow-before-brif.wat`.

Input shape:

```wat
(module
  (memory 1)
  (func (param i32) (local i32)
    (block $exit
      i32.const 7
      local.set 1
      i32.const 1
      memory.grow
      drop
      local.get 0
      br_if $exit
      local.get 1
      drop)))
```

Commands:

- `wasm-tools parse .tmp/cp-probes/memory-grow-before-brif.wat -o .tmp/cp-probes/memory-grow-before-brif.wasm` — passed.
- `wasm-tools validate --features all .tmp/cp-probes/memory-grow-before-brif.wasm` — passed.
- `wasm-opt --all-features .tmp/cp-probes/memory-grow-before-brif.wat --code-pushing -S -o -` — passed under local `wasm-opt version 130 (version_130)`.

Binaryen moved the pure SFA set after the dropped `memory.grow` result and after the later `br_if`, placing the delayed constant computation next to the suffix use.

## Starshine coverage

Added focused test: `code-pushing moves pure SFA set past memory.grow before br_if push point` in `src/passes/code_pushing_test.mbt`.

The test confirms the existing Starshine segment path already matches the Binaryen-positive shape: the original `local.set` becomes `nop`, the dropped `memory.grow` root remains before the `br_if`, and the cloned `local.set` is inserted after the `br_if` before the suffix `drop` use.

No pass implementation or GenValid profile changed in this slice.

## Validation

- `moon test --target native src/passes/code_pushing_test.mbt --filter '*memory.grow before br_if*'` — passed `1/1`.

## Audit impact

This closes one narrow memory-growth ordered-window question for pure values before a later `br_if`. It does **not** allow memory-size-dependent values, loads, heap reads, or trap-sensitive operations to cross `memory.grow`. Broader memory bulk operations, multi-set windows involving memory effects, and trap-option-specific behavior remain open for `[O4Z-AUDIT-CP]`.
