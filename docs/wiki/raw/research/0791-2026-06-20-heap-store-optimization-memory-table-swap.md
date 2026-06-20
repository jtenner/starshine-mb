---
kind: research
status: active
created: 2026-06-20
sources:
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/binaryen-strategy.md
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0790-2026-06-20-heap-store-optimization-explicit-non-goals.md
  - ../../../src/passes/heap_store_optimization.mbt
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# HSO memory/table blocker swap parity

Question: does Binaryen `version_130` treat ordinary memory/table stores as hard HSO boundaries, or can `trySwap(...)` move a pure fresh-struct local assignment past them to reach a later `struct.set`?

## Answer

Binaryen `version_130` folds through ordinary memory and table store blockers when the fresh constructor has no operand effect that must remain before the blocker. The earlier `0790` memory-store boundary note was too conservative and is superseded for ordinary memory/table blockers.

The pass is still not generic memory/table dead-store elimination or load forwarding: the only optimized store remains the later `struct.set` into the fresh struct. The ordinary `i32.store` / `table.set` remains in the output; Binaryen just swaps the fresh `local.set(struct.new_default)` past it and then folds the later `struct.set` into the constructor.

## Binaryen probes

Memory-store blocker probe:

```wat
(module
  (type $pair (struct (field (mut i32))))
  (memory 1)
  (func (result i32)
    (local $p (ref null $pair))
    (struct.new_default $pair)
    (local.set $p)
    (i32.const 0)
    (i32.const 99)
    (i32.store)
    (local.get $p)
    (i32.const 7)
    (struct.set $pair 0)
    (local.get $p)
    (struct.get $pair 0)))
```

`wasm-opt --all-features --heap-store-optimization -S` keeps `i32.store`, removes `struct.set`, and emits `local.set $p (struct.new $pair (i32.const 7))` after the store.

Table-store blocker probe:

```wat
(module
  (type $pair (struct (field (mut i32))))
  (table 1 funcref)
  (func (result i32)
    (local $p (ref null $pair))
    (struct.new_default $pair)
    (local.set $p)
    (i32.const 0)
    (ref.null func)
    (table.set 0)
    (local.get $p)
    (i32.const 7)
    (struct.set $pair 0)
    (local.get $p)
    (struct.get $pair 0)))
```

`wasm-opt --all-features --heap-store-optimization -S` keeps `table.set`, removes `struct.set`, and emits `local.set $p (struct.new $pair (i32.const 7))` after the table store.

A call blocker probe still retains `struct.set`, so this slice does not broaden swapping across calls or arbitrary control effects.

## Starshine change

Added red-first focused tests:

- `heap-store-optimization folds through ordinary memory stores`
- `heap-store-optimization folds through ordinary table stores`

Both failed before the implementation because Starshine retained the later `struct.set` behind the `i32.store` / `table.set` blockers.

Implementation change:

- `hso_root_can_swap_before_local_struct_new(...)` now follows Binaryen's `trySwap(...)` direction more closely for pure constructors: after the constructor operand effects do not need to remain before the blocker, non-call, non-throw, non-control blockers may be crossed even when they read/write memory/table state or may trap.
- The existing target-local touch guard remains.
- The existing constructor ping-pong guard is preserved explicitly: a `local.set` whose value is another supported `struct.new*` still blocks swapping, matching Binaryen's `trySwap(...)` rejection.

## Validation

Focused red run before implementation:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result: `68/70` passed; the two new memory/table store tests failed with retained `struct.set`.

Focused run after implementation:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result: `70/70` passed.

Additional signoff:

```sh
moon fmt
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass heap-store-optimization --out-dir .tmp/pass-fuzz-heap-store-optimization-memory-table-swap-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Results:

- `moon fmt`: passed.
- Native `src/cmd` build: passed with existing unused-function warnings in `src/passes/pass_manager.mbt`.
- Direct compare: `10000/10000` compared, `10000` normalized matches, `0` compare-normalized matches, `0` mismatches, `0` validation/property/generator failures, `0` command failures. Cache counters: wasm-smith `0/0`, Binaryen `10000` hits / `0` misses, Binaryen failures `0/0`.

## Remaining risk

This closes one `[O4Z-AUDIT-HSO-G/H]` swap/boundary misclassification: ordinary memory/table blockers are not HSO non-goals when they only need to be crossed to reach a later fresh-struct `struct.set`.

Still open:

- explicit unreachable constructor/set no-fold coverage;
- exact descriptor `ref.cast` local-surface/decode blocker;
- broader descriptor and later-field expression review;
- safe function-external exits versus unsafe in-function branch/catch skip-local-set hazards;
- final-element swap coverage and O4z slot/neighborhood evidence;
- final 100000-case direct closeout later.
