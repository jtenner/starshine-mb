---
kind: research
status: active
created: 2026-06-20
sources:
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0793-2026-06-20-heap-store-optimization-function-return-control.md
  - ../../../src/passes/heap_store_optimization.mbt
  - ../../../src/passes/heap_store_optimization_test.mbt
  - ../../../.tmp/hso-v130-refresh/heap-store-optimization-v130.wast
---

# `heap-store-optimization` in-function catch control-flow negative

Question: does Starshine match Binaryen `version_130` for the HSO `LazyLocalGraph::canMoveSet(...)` family where a moved `struct.set` value is a call whose throw may be caught inside the same function?

## Answer

Not before this slice. Binaryen's dedicated lit file keeps the `struct.set` in `$control-flow-in-set-value-unsafe-call` because the call may throw to an in-function `try_table` catch. In the original shape, the `local.tee` has already assigned the fresh struct to the local before the call can throw; after an unsafe fold, the local assignment would be delayed until after the call-valued constructor field, so a caught throw could skip the assignment and change a later in-function read.

Starshine previously treated plain calls as safe function-external exits in all contexts, so it folded the in-function `try_table` negative. The fix threads an `active_catch_depth` through HSO region traversal. When optimizing inside a catchable `try`/`try_table` body, a moved set value that may escape to the active catch (`call`, `call_indirect`, `call_ref`, return-call forms, `throw`, `rethrow`, `throw_ref`, or `delegate`) blocks the fold. Plain function `return` remains safe from follow-up `0793`, because taking the return exits the function instead of resuming at a later in-function read.

## Binaryen source/lit evidence

The `version_130` lit fixture says the call's possible throw could be caught inside the function and therefore must not optimize. The expected output preserves:

```wat
(try_table (catch $tag $label)
  (struct.set $struct 0
    (local.tee $ref (struct.new $struct (i32.const 1)))
    (call $helper-i32 (i32.const 42))))
```

This is the complementary negative to `0793`'s function-external return positive.

## Starshine change

- Added focused regression `heap-store-optimization keeps struct.set for calls caught inside the function` in `src/passes/heap_store_optimization_test.mbt`.
- Red run: the new test failed because Starshine folded the caught-call `struct.set` into a `local.set (struct.new (call ...))` and removed `struct.set`.
- Implementation: `src/passes/heap_store_optimization.mbt` now tracks when region traversal is inside an active in-function catch body and rejects folds whose moved value can call/throw/return-call to that catch.
- Focused result after the fix: `moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt` passed `74/74`.
- `moon fmt` passed.
- Native `src/cmd` build passed with the existing unused-function warnings in `src/passes/pass_manager.mbt`.
- Direct compare signoff: `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass heap-store-optimization --out-dir .tmp/pass-fuzz-heap-store-optimization-catch-negative-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures` compared `10000/10000`, normalized `10000`, compare-normalized `0`, mismatches `0`, validation/property/generator failures `0`, command failures `0`, Binaryen cache `10000` hits / `0` misses.

## Remaining HSO-F risk

This closes the lit-backed caught-call negative and the prior plain function-return positive, but not every control-flow corner. Return-call classification remains conservative in active catch contexts because return-call can still throw before returning. Safe external throw/call shapes outside active in-function catch contexts need broader focused coverage, and Binaryen's one-disappearing-bad-get `LazyLocalGraph` exception still needs review before HSO-F can close.
