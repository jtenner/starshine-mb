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

# `heap-store-optimization` descriptor target-local write hazard

Question: does Binaryen `version_130` keep the target-local write hazard when the fresh constructor is a descriptor form?

## Answer

Yes. A local `wasm-opt version 130 (version_130)` probe with `struct.new_desc` followed by a `struct.set` whose moved value writes the target local preserves the `struct.set`. Descriptor constructors do not relax Binaryen's core target-local write hazard: moving the value into the original constructor would perform the replacement `local.set` before the original fresh-struct assignment is safely consumed.

Starshine already matched this shape. This was a coverage-only HSO-E slice; no implementation behavior changed, and no native rebuild or direct compare was required.

## Probe command

```sh
wasm-opt .tmp/hso-probe-desc-target-local-write.wat --heap-store-optimization -all -S -o -
```

Observed behavior:

- Binaryen preserved the initial `struct.new_desc` and `local.set $p`.
- Binaryen preserved the later `struct.set $pair 0` whose value block assigns a new `struct.new_desc` to `$p` before yielding `i32.const 9`.
- Binaryen still canonicalized the empty descriptor global initializer to `struct.new_default $desc`, which is unrelated to the HSO fold decision.

## Starshine test

Added focused coverage in `src/passes/heap_store_optimization_test.mbt`:

- `heap-store-optimization keeps descriptor store when moved value writes target local`

Focused validation:

```text
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
Total tests: 212, passed: 212, failed: 0.
```

## Backlog impact

This narrows HSO-E by covering the descriptor-constructor variant of the moved-value target-local write hazard. HSO-E remains open for descriptor/later-field hazard combinations beyond the direct descriptor target-local read/write cases and any remaining moved-value hazard variants not already covered by `0854`, `0855`, `0857`, and this note.
