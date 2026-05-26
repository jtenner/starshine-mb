# SGO loop independent memory-copy prefix

Date: 2026-05-25
Slice: `[SGO]003C5`

## Question

Can Starshine's narrow loop-specific read-only-to-write matcher accept a `loop (result i32)` whose body performs an independent constant-operand `memory.copy` before yielding the candidate `global.get`, without enabling broad loop FlowScanner reuse?

## Binaryen probe

A reduced positive with exported memory:

```wat
(module
  (memory (export "mem") 1)
  (global $once (mut i32) (i32.const 0))
  (func (export "run")
    loop (result i32)
      i32.const 16
      i32.const 0
      i32.const 4
      memory.copy
      global.get $once
    end
    if
      i32.const 1
      global.set $once
    end))
```

`wasm-opt --all-features --simplify-globals-optimizing -S` removes the fake mutable global traffic, making `$once` immutable. Binaryen's nested cleanup may lower the tiny copy to load/store, but the SGO decision is still positive for the independent prefix.

A paired negative where the copy destination is `global.get $once` keeps `$once` mutable and preserves the `global.get` / `global.set` traffic. That confirms the operand-independence guard must stay in place.

## Implementation

- Added focused positive and candidate-derived destination negative tests in `src/passes/simplify_globals_optimizing_test.mbt`.
- Extended the existing loop-only triple-effect prefix matcher in `src/passes/simplify_globals_optimizing.mbt` from `memory.fill` to `memory.fill | memory.copy` when all three operands are constants.
- Did not reuse the broader block FlowScanner inside loops.

## Validation

- TDD failure before implementation: `moon test src/passes` failed only the new positive test because `$once` remained mutable.
- Focused validation after implementation: `moon test src/passes` passed (`1627/1627`).
- Standard Moon validation: `moon fmt`, `moon info`, and full `moon test` passed (`3703/3703`; existing DAE/pass-manager unused warnings only).
- Direct SGO fuzz: `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --out-dir .tmp/pass-fuzz-sgo-loop-memory-copy-0685-10000` compared `6759/10000` before the configured command-failure stop, with `6759` normalized matches, `0` mismatches, `0` Starshine validation failures, and `20` Binaryen/tool command failures (`17` `binaryen-rec-group-zero`, `1` `binaryen-bad-section-size`, `1` `binaryen-table-index-out-of-range`, `1` `binaryen-invalid-tag-index`).

## Remaining work

`memory.init`, `table.fill`, `table.init`, `table.copy`, operandless segment drops, growth operations, atomics, SIMD memory operations, branch/control loop bodies, and calls in this loop-specific prefix position still require separate Binaryen-positive probes plus paired negatives before implementation.
