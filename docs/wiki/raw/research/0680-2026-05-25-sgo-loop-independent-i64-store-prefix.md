# SGO loop independent i64 store prefix

Date: 2026-05-25

## Slice

`[SGO]003C5` / loop-specific read-only-to-write FlowScanner breadth.

## Goal

Extend the narrow value-loop prefix matcher from [`0679`](./0679-2026-05-25-sgo-loop-independent-store-prefix.md) from the already proven constant-operand `i32.store` shape to the matching Binaryen-positive constant-operand `i64.store` shape.

## Source evidence

A focused Binaryen probe with `wasm-opt --simplify-globals-optimizing -S --all-features` showed this shape removes the fake candidate-global traffic while preserving the independent store:

```wat
(module
  (memory (export "mem") 1)
  (global $g (mut i32) (i32.const 0))
  (func (export "f")
    (loop (result i32)
      i32.const 0
      i64.const 7
      i64.store
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

Binaryen rewrites `$g` to immutable and leaves `i64.store` in the function body. Starshine already had the paired candidate-derived store-address negative from the `i32.store` slice; this slice adds the corresponding `i64.store` guardrail so a candidate-derived store operand keeps the mutable global and guard traffic.

## Implementation

Renamed the narrow loop helper in `src/passes/simplify_globals_optimizing.mbt` to `sgo_loop_independent_prefix_scalar_store_matches(...)` and admitted exactly `I32Store` or `I64Store` after two literal constant operands before the final candidate `global.get`.

The matcher still requires:

- a flattened non-branching loop body;
- the final loop instruction to be the single candidate `global.get`;
- each accepted store operand to be a literal constant;
- the outer guard to be the already-supported direct no-else same-global constant-set shape.

It still does not admit candidate-derived store operands, branchy loops, trapping candidate consumers, memory/table growth, bulk effects, atomics, SIMD memory operations, calls, or broad loop FlowScanner reuse.

## Tests

Added focused regressions in `src/passes/simplify_globals_optimizing_test.mbt`:

- `simplify-globals-optimizing removes loop-wrapped independent i64 store effect prefixes` proves the independent `i64.store` remains while `$once` becomes immutable and the fake guard traffic disappears.
- `simplify-globals-optimizing keeps loop-wrapped candidate-derived i64 store prefixes conservative` proves a candidate-derived store operand keeps `$once` mutable and preserves the guard traffic.

## Validation

- TDD failure before implementation: `moon test src/passes` failed at the new independent-`i64.store` regression because `$once` remained mutable.
- Focused pass tests after implementation: `moon test src/passes` passed (`1616/1616`) with the existing DAE/pass-manager warnings.
- Standard Moon validation: `moon fmt`, `moon info`, and full `moon test` passed (`3693/3693`) with existing DAE warnings.
- Direct SGO fuzz: `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --out-dir .tmp/pass-fuzz-sgo-loop-i64-store-0680-10000` compared `6759/10000` before the configured `20` Binaryen/tool command-failure stop, with `6759` normalized matches, `0` mismatches, `0` Starshine validation failures, and `0` generator failures.

## Classification

This is a semantic-safe Binaryen-positive behavior implementation. The classification is based on the focused Binaryen positive, the paired candidate-derived negative, and the narrow transform contract: constant store operands are independent of the candidate global, and only the single final candidate read supplies the same-global guard condition. The store is preserved; only fake candidate-global guard traffic is removed.
