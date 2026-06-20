---
kind: research
status: supported
created: 2026-06-20
sources:
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0791-2026-06-20-heap-store-optimization-memory-table-swap.md
  - ./0818-2026-06-20-heap-store-optimization-table-size-table-set-swap.md
  - ./0819-2026-06-20-heap-store-optimization-memory-size-memory-bulk-boundaries.md
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# `heap-store-optimization` cross-family store swap coverage

Question: after Binaryen `version_130` proved that `heap-store-optimization` folds through ordinary memory/table stores when the constructor has no ordered effect conflict, and separately blocks same-family table/memory effects such as `table.size` before `table.set` and `memory.size` before bulk-memory roots, what happens for cross-family ordinary stores?

## Answer

Binaryen folds the later `struct.set` into the constructor for both cross-family store shapes probed here:

- constructor `memory.size $m` crossing an intervening `table.set $t`;
- constructor `table.size $t` crossing an intervening `i32.store` to memory.

That means these ordinary store roots are not blanket barriers. The relevant `trySwap(...)` question is directional effect ordering: memory-size does not need to stay before an ordinary table write, and table-size does not need to stay before an ordinary memory write.

Starshine already matched these `version_130` probes. This slice only added focused coverage and did not change implementation behavior.

## Binaryen probes

Fixtures were written under `.tmp/hso-br-table-wrapper-probe/`:

```sh
wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-br-table-wrapper-probe/memory-size-table-set.wat \
  -o .tmp/hso-br-table-wrapper-probe/memory-size-table-set.opt.wat
wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-br-table-wrapper-probe/table-size-i32-store.wat \
  -o .tmp/hso-br-table-wrapper-probe/table-size-i32-store.opt.wat
```

The optimized WAT for each fixture retained the constructor operand and intervening store root, but no longer had a `struct.set`. The folded constructors still contained `memory.size` / `table.size` respectively.

Agent classification: Binaryen behavior is a cross-effect-family swap/fold positive. This is not a Starshine-only win and not a non-goal.

## Starshine coverage

Added focused tests:

- `heap-store-optimization folds memory.size constructors across table stores`
- `heap-store-optimization folds table.size constructors across memory stores`

The tests construct a module with both memory and table sections, keep the intervening ordinary store visible, and assert the final optimized function no longer contains `struct.set`.

Validation:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result: `195/195` passed.

## Follow-up

This narrows HSO-G's broader swap/effect matrix by covering cross-family ordinary store positives. Remaining HSO-G work still includes broader swap operands/effects and additional HOT wrapper variants beyond the already-covered direct, wrapped, nested, deep-nested, and branch-containing roots. Final HSO-B evidence still needs saved early/late O4z slot or neighborhood replay.
