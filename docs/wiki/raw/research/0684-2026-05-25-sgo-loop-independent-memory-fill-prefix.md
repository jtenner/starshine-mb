# SGO loop independent memory-fill prefix

Date: 2026-05-25

## Question

Can the narrow `[SGO]003C5` direct-loop read-only-to-write prefix matcher safely admit an independent `memory.fill` side effect before the yielded candidate-global read, matching Binaryen's `SimplifyGlobals.cpp` behavior without enabling broad loop FlowScanner reuse?

## Binaryen probe

Fixture shape:

```wat
(module
  (memory (export "mem") 1)
  (global $once (mut i32) (i32.const 0))
  (func (export "run")
    loop (result i32)
      i32.const 0
      i32.const 7
      i32.const 1
      memory.fill
      global.get $once
    end
    if
      i32.const 1
      global.set $once
    end))
```

`wasm-opt --all-features --simplify-globals-optimizing -S` promotes `$once` to immutable and removes the fake `global.get` / `global.set` traffic while preserving the independent memory side effect. Binaryen's nested cleanup may print the single-byte fill as an equivalent `i32.store8`, but the SGO-relevant fact is that the independent effect remains and the fake candidate-global guard traffic disappears. A paired tainted-destination probe with `global.get $once; i32.const 7; i32.const 1; memory.fill; global.get $once` stays conservative in Starshine so candidate-derived memory targets are not admitted.

## Implementation

- Added focused positive and negative tests in `src/passes/simplify_globals_optimizing_test.mbt`.
- Added a narrow `sgo_loop_independent_prefix_triple_effect_matches(...)` helper in `src/passes/simplify_globals_optimizing.mbt` for three-constant loop prefixes and admitted only `@lib.MemoryFill(_)` in this slice.
- Kept the loop matcher narrow: no branch/control bodies, `br_if`, returns, trapping candidate-derived consumers, memory/table growth, atomics, SIMD memory operations, other bulk operations, or call operands are admitted by this slice.

## TDD and validation

- TDD failure before implementation: `moon test src/passes` failed on `simplify-globals-optimizing removes loop-wrapped independent memory-fill effect prefixes`; `$once` stayed mutable.
- Focused pass tests after implementation: `moon test src/passes` passed (`1625/1625`) with existing DAE/pass-manager unused warnings.
- Full validation after docs: `moon fmt`, `moon info`, and full `moon test` passed (`3701/3701`) with existing DAE unused warnings.
- Direct SGO fuzz: `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --out-dir .tmp/pass-fuzz-sgo-loop-memory-fill-0684-10000` compared `6759/10000`, with `6759` normalized matches, `0` mismatches, `0` Starshine validation failures, and `20` Binaryen/tool command failures under the configured stop.

## Classification

The implemented family is classified as semantic-safe and Binaryen-positive because the destination, fill byte, and length operands are independent constants, so the memory side effect still occurs in order while the removed global traffic is fake state used only for the final same-global guard. The tainted operand guardrail keeps cases where the candidate global can affect a trap, destination, fill value, or length conservative.
