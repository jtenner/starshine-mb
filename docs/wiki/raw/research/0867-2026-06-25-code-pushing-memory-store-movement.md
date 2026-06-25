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

# Code-pushing memory.store segment movement

## Question

Can a pure SFA `local.set` move across an intervening `i32.store` before a later `br_if` push point?

This follows the global/table-state slices in [`0865`](0865-2026-06-25-code-pushing-global-set-movement.md) and [`0866`](0866-2026-06-25-code-pushing-table-set-movement.md). The narrowed question is intentionally about a pure constant value with no memory-read dependency; it is not a claim that heap reads may cross memory writes.

## Binaryen v130 probe

Probe path: `.tmp/cp-probes/memory-store-before-brif.wat`.

Input shape:

```wat
(module
  (memory 1)
  (func (param i32) (local i32)
    (block $exit
      i32.const 7
      local.set 1
      i32.const 0
      i32.const 42
      i32.store
      local.get 0
      br_if $exit
      local.get 1
      drop)))
```

Commands:

- `wasm-tools parse .tmp/cp-probes/memory-store-before-brif.wat -o .tmp/cp-probes/memory-store-before-brif.wasm` — passed.
- `wasm-tools validate --features all .tmp/cp-probes/memory-store-before-brif.wasm` — passed.
- `wasm-opt --all-features .tmp/cp-probes/memory-store-before-brif.wat --code-pushing -S -o -` — passed under local `wasm-opt version 130 (version_130)`.

Binaryen moved the pure SFA set after the `i32.store` and after the later `br_if`, preserving the memory write before the branch and placing the delayed constant computation next to the suffix use.

## Starshine coverage

Added focused test: `code-pushing moves pure SFA set past memory.store before br_if push point` in `src/passes/code_pushing_test.mbt`.

The test confirms the existing Starshine segment path already matches the Binaryen-positive shape: the original `local.set` becomes `nop`, the `Store` remains before the `br_if`, and the cloned `local.set` is inserted after the `br_if` before the suffix `drop` use.

No pass implementation or GenValid profile changed in this slice.

## Validation

- `moon test --target native src/passes/code_pushing_test.mbt --filter '*memory.store before br_if*'` — passed `1/1`.

## Audit impact

This closes one narrow memory-write ordered-window question for pure values before a later `br_if`. It does **not** reopen heap-read movement across memory writes; the existing non-null `struct.get`/atomic-store and heap-read memory-write boundaries still stand. Broader memory operations, trap-sensitive stores, loads/heap reads, multi-set windows involving memory effects, and trap-option-specific behavior remain open for `[O4Z-AUDIT-CP]`.
