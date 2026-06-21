---
kind: research
status: supported
created: 2026-06-20
sources:
  - ../../../src/passes/heap_store_optimization_test.mbt
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
---

# `heap-store-optimization` descriptor/default old-field combinations

Question: how does Binaryen `version_130` combine descriptor constructors, default materialization, old-field preservation, and later-field effect barriers?

## Answer

Two local `wasm-opt version 130 (version_130)` probes confirm the expected source-backed split:

- For `struct.new_default_desc`, Binaryen can materialize defaults, fold an earlier plain store, and fold a later call-valued store into `struct.new_desc`. The call side effect is preserved as a constructor operand and the redundant stores become `nop`s.
- For `struct.new_desc` with a later constructor field that calls before the candidate field, Binaryen preserves a later call-valued `struct.set` to an earlier field. Moving that call before the later constructor field call would violate the directional `orderedBefore(...)` barrier.

Starshine already matched both shapes. This was a coverage-only HSO-D slice; no implementation behavior changed, and no native rebuild or direct compare was required.

## Probe commands

```sh
wasm-opt .tmp/hso-probe-default-desc-old-field.wat --heap-store-optimization -all -S -o -
wasm-opt .tmp/hso-probe-default-desc-old-field-conflict.wat --heap-store-optimization -all -S -o -
```

Observed behavior:

- `.tmp/hso-probe-default-desc-old-field.wat`: Binaryen rewrote `struct.new_default_desc` to `struct.new_desc`, inserted the folded `i32.const 9` and `call $side` operands, and removed both `struct.set` operations.
- `.tmp/hso-probe-default-desc-old-field-conflict.wat`: Binaryen preserved the later `struct.set` because a later constructor field call orders before the moved call value.

## Starshine tests

Added focused coverage in `src/passes/heap_store_optimization_test.mbt`:

- `heap-store-optimization folds default descriptor chain stores and preserves moved call`
- `heap-store-optimization keeps descriptor struct.set when later field call orders before moved call`

Focused validation:

```text
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
Total tests: 210, passed: 210, failed: 0.
```

## Backlog impact

This narrows HSO-D by covering one default+descriptor materialization positive and one descriptor old-field/later-field call-order negative. HSO-D remains open for arbitrary descriptor expressions, remaining later-field directional barriers, and broader old-field side-effect negatives.
