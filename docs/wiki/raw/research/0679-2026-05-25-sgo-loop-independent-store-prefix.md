# SGO loop independent store prefix

Date: 2026-05-25

## Slice

`[SGO]003C5` / loop-specific read-only-to-write FlowScanner breadth.

## Goal

Extend the narrow value-loop prefix matcher from [`0677`](./0677-2026-05-25-sgo-loop-independent-global-set-prefix.md) and [`0678`](./0678-2026-05-25-sgo-loop-independent-local-set-prefix.md) to one more exact Binaryen-positive independent side effect: a scalar store with constant operands before the yielded candidate-global read.

## Source evidence

A focused Binaryen probe with `wasm-opt --simplify-globals-optimizing -S --all-features` showed this shape removes the fake candidate-global traffic while preserving the independent memory store:

```wat
(module
  (memory (export "mem") 1)
  (global $g (mut i32) (i32.const 0))
  (func (export "f")
    (loop (result i32)
      i32.const 0
      i32.const 7
      i32.store
      global.get $g
    )
    (if
      (then
        i32.const 1
        global.set $g
      )
    )
  )
)
```

Binaryen rewrites `$g` to immutable and leaves the `i32.store` in the function body. A paired candidate-derived store-address probe remains conservative in Binaryen: when `global.get $g` feeds the store address before the final yielded `global.get $g`, Binaryen preserves the mutable global and guard traffic.

## Implementation

Updated `src/passes/simplify_globals_optimizing.mbt` with a small `sgo_loop_independent_prefix_i32_store_matches(...)` helper. The loop-specific matcher now allows the exact prefix triple `const; const; i32.store` before the final candidate `global.get`. This covers the probed `i32.store` shape without enabling the full block FlowScanner or unprobed store/table effect families inside loops.

The matcher still requires:

- a flattened non-branching loop body;
- the final loop instruction to be the single candidate `global.get`;
- each accepted effect operand to be a literal constant;
- the outer guard to be the already-supported direct no-else same-global constant-set shape.

It does not admit candidate-derived store operands, branchy loops, trapping candidate consumers, calls, memory/table growth, bulk effects, atomics, SIMD memory operations, or broad loop FlowScanner reuse.

## Tests

Added focused regressions in `src/passes/simplify_globals_optimizing_test.mbt`:

- `simplify-globals-optimizing removes loop-wrapped independent store effect prefixes` proves the independent `i32.store` remains while `$once` becomes immutable and the fake guard traffic disappears.
- `simplify-globals-optimizing keeps loop-wrapped candidate-derived store prefixes conservative` proves a candidate-derived store operand keeps `$once` mutable and preserves the guard traffic.

## Validation

- TDD failure before implementation: `moon test src/passes` failed at the new independent-store regression because `$once` remained mutable.
- Focused pass tests after implementation: `moon test src/passes` passed (`1615/1615`) with the existing DAE/pass-manager warnings.
- Standard Moon validation: `moon fmt`, `moon info`, and full `moon test` passed (`3691/3691`) with existing DAE/pass-manager warnings.
- Direct SGO fuzz: `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --out-dir .tmp/pass-fuzz-sgo-loop-store-0679-10000` compared `6759/10000` before the configured `20` Binaryen/tool command-failure stop, with `6759` normalized matches, `0` mismatches, `0` Starshine validation failures, and `0` generator failures.

## Classification

This is a semantic-safe Binaryen-positive behavior implementation. The classification is based on the focused Binaryen positive plus paired negative and the narrow transform contract: constant store operands are independent of the candidate global, and only the single final candidate read supplies the same-global guard condition. The store is preserved; only fake candidate-global guard traffic is removed. No fuzz mismatch is attributed to this slice.
