---
kind: research
status: active
created: 2026-06-20
sources:
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ../../../src/passes/heap_store_optimization.mbt
  - ../../../src/passes/heap_store_optimization_test.mbt
  - ../../../.tmp/hso-v130-refresh/heap-store-optimization-v130.wast
  - ../../../.tmp/hso-v130-refresh/HeapStoreOptimization-v130.cpp
---

# `heap-store-optimization` function-return control-flow fold

Question: does Starshine match Binaryen `version_130` for the HSO `LazyLocalGraph::canMoveSet(...)` family where a moved `struct.set` value may exit the function with `return`?

## Answer

Not before this slice. Binaryen's dedicated lit file explicitly says the return arm is safe because taking the `return` exits the function, so skipping the moved local assignment cannot affect a later in-function read. The local Binaryen oracle folds a tee-wrapped fresh struct into a `local.set` whose constructor field is the `if` containing the `return`.

Starshine previously treated any `Return` inside the moved set value as `may_skip_local_set`, so it retained the `struct.set`. This was stricter than Binaryen behavior. The fix narrows `hso_subtree_may_skip_local_set_from_root(...)`: a plain function `Return` is not considered an in-function skip-local-set hazard, while throwing/catchable exits and other terminators remain conservative.

## Binaryen probe

Fixture:

```wat
(module
  (type $s (struct (field (mut i32))))
  (func (export "f") (result i32) (local $x (ref null $s))
    (block $label
      (struct.set $s 0
        (local.tee $x (struct.new_default $s))
        (if (result i32)
          (i32.const 1)
          (then (return (i32.const 42)))
          (else (i32.const 7)))))
    (struct.get $s 0 (local.get $x)))
)
```

Command:

```sh
wasm-opt --all-features --heap-store-optimization -S .tmp/hso-f-safe-return-tee.wat -o -
```

Observed result: Binaryen emits `local.set $x (struct.new $s (if ... return ...))` and no `struct.set` for this function.

## Starshine change

- Added focused regression `heap-store-optimization folds function-return set values into struct.new` in `src/passes/heap_store_optimization_test.mbt`.
- Red run: the new test failed because pretty output still contained `struct.set`.
- Implementation: `src/passes/heap_store_optimization.mbt` now treats plain `Return` as function-external for `hso_subtree_may_skip_local_set_from_root(...)` instead of as an in-function skip-local-set hazard.
- Focused result after the fix: `moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt` passed `73/73`.
- `moon fmt` passed.
- Native `src/cmd` build passed with the existing unused-function warnings in `src/passes/pass_manager.mbt`.
- Direct compare signoff: `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass heap-store-optimization --out-dir .tmp/pass-fuzz-heap-store-optimization-function-return-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures` compared `10000/10000`, normalized `10000`, compare-normalized `0`, mismatches `0`, validation/property/generator failures `0`, command failures `0`, Binaryen cache `10000` hits / `0` misses.

## Remaining HSO-F risk

This slice does **not** close all control-flow/catch behavior. The Binaryen lit family for calls whose possible throw is caught inside the function remains a high-value negative to reproduce locally. Starshine's current `Return` relaxation is intentionally narrower than treating all terminators as safe; `Throw`, `Rethrow`, `ThrowRef`, `Delegate`, and return-call forms still stay conservative pending separate Binaryen probes and focused tests.
