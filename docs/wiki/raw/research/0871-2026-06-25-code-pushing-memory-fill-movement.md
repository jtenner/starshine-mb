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

# Code-pushing memory.fill segment movement

## Question

Can a pure SFA `local.set` move across an intervening `memory.fill` before a later `br_if` push point?

This extends the pure-value memory ordered-window probes after [`0867`](0867-2026-06-25-code-pushing-memory-store-movement.md), [`0868`](0868-2026-06-25-code-pushing-memory-grow-movement.md), and [`0870`](0870-2026-06-25-code-pushing-memory-copy-movement.md). The question is only about a pure constant value. It is not a claim that loads, heap reads, memory-size-dependent values, or trap-sensitive values may cross memory filling.

## Binaryen v130 probe

Probe path: `.tmp/cp-probes/memory-fill-before-brif.wat`.

Input shape:

```wat
(module
  (memory 1)
  (func (param i32) (local i32)
    (block $exit
      i32.const 7
      local.set 1
      i32.const 0
      i32.const 1
      i32.const 4
      memory.fill
      local.get 0
      br_if $exit
      local.get 1
      drop)))
```

Commands:

- `wasm-tools parse .tmp/cp-probes/memory-fill-before-brif.wat -o .tmp/cp-probes/memory-fill-before-brif.wasm` — passed.
- `wasm-tools validate --features all .tmp/cp-probes/memory-fill-before-brif.wasm` — passed.
- `wasm-opt --all-features .tmp/cp-probes/memory-fill-before-brif.wat --code-pushing -S -o -` — passed under local `wasm-opt version 130 (version_130)`.

Binaryen moved the pure SFA set after `memory.fill` and after the later `br_if`, placing the delayed constant computation next to the suffix use.

## Starshine coverage

Added focused test: `code-pushing moves pure SFA set past memory.fill before br_if push point` in `src/passes/code_pushing_test.mbt`.

The test confirms the existing Starshine segment path already matches the Binaryen-positive shape: the original `local.set` becomes `nop`, the `MemoryFill` root remains before the `br_if`, and the cloned `local.set` is inserted after the `br_if` before the suffix `drop` use.

No pass implementation or GenValid profile changed in this slice.

## Validation

- `moon test --target native src/passes/code_pushing_test.mbt --filter '*memory.fill before br_if*'` — passed `1/1`.

## Audit impact

This closes one narrow memory-fill ordered-window question for pure values before a later `br_if`. It does **not** allow loads, heap reads, memory-size-dependent values, or trap-sensitive operations to cross `memory.fill`. Broader memory bulk operations such as `memory.init`, data drops, multi-set windows involving memory effects, and trap-option-specific behavior remain open for `[O4Z-AUDIT-CP]`.
