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

# `heap-store-optimization` target-local chain variants

Question: how does Binaryen `version_130` handle subsequent-chain folds when one store value reads or writes the constructor target local?

## Answer

Two local `wasm-opt version 130 (version_130)` probes confirm that target-local hazards remain local to each attempted movement in a chain:

- If the first moved `struct.set` value writes the target local before yielding an `i32`, Binaryen preserves that `struct.set` and also preserves a later store through the now-current target local. Folding the first store would move the target-local overwrite before the original constructor assignment and change which object later `local.get` observes.
- If an earlier store is harmless but a later store value reads the target local, Binaryen folds the earlier store into the constructor but preserves the later target-local-read `struct.set`.

Starshine already matched both shapes. This was a coverage-only HSO-E slice; no implementation behavior changed, and no native rebuild or direct compare was required.

## Probe commands

```sh
wasm-opt .tmp/hso-probe-target-local-chain-write.wat --heap-store-optimization -all -S -o -
wasm-opt .tmp/hso-probe-target-local-chain-second-read.wat --heap-store-optimization -all -S -o -
```

Observed behavior:

- `.tmp/hso-probe-target-local-chain-write.wat`: Binaryen preserved both `struct.set` operations.
- `.tmp/hso-probe-target-local-chain-second-read.wat`: Binaryen rewrote the first constructor field to `i32.const 1`, emitted `nop` for the first store, and preserved the second `struct.set` whose value reads the target local.

## Starshine tests

Added focused coverage in `src/passes/heap_store_optimization_test.mbt`:

- `heap-store-optimization keeps chain stores when a moved value writes the target local`
- `heap-store-optimization folds earlier chain stores before a later target-local read hazard`

A small test helper counts pretty-printed occurrence counts so these tests can distinguish two preserved stores from one folded/one preserved store.

Focused validation:

```text
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
Total tests: 208, passed: 208, failed: 0.
```

## Backlog impact

This narrows HSO-E by covering target-local chain variants. HSO-E still remains open for descriptor/later-field hazard combinations and any remaining moved-value hazard variants.
