# SGO loop independent subword store prefix

Date: 2026-05-25

## Slice

`[SGO]003C5` / loop-specific read-only-to-write FlowScanner breadth.

## Goal

Extend the narrow value-loop prefix matcher from the prior constant-operand `i32.store` / `i64.store` loop slices to the matching Binaryen-positive integer subword store family: `i32.store8`, `i32.store16`, `i64.store8`, `i64.store16`, and `i64.store32`.

## Source evidence

Focused `wasm-opt version_129` probes with `wasm-opt --simplify-globals-optimizing -S --all-features` showed that each constant-address / constant-value subword store prefix removes fake candidate-global traffic while preserving the independent store. Probe summary:

- `i32.store8`: global becomes immutable, no remaining `global.get` / `global.set`, store preserved.
- `i32.store16`: global becomes immutable, no remaining `global.get` / `global.set`, store preserved.
- `i64.store8`: global becomes immutable, no remaining `global.get` / `global.set`, store preserved.
- `i64.store16`: global becomes immutable, no remaining `global.get` / `global.set`, store preserved.
- `i64.store32`: global becomes immutable, no remaining `global.get` / `global.set`, store preserved.

Representative positive:

```wat
(module
  (memory (export "mem") 1)
  (global $g (mut i32) (i32.const 0))
  (func (export "f")
    (loop (result i32)
      i32.const 0
      i32.const 7
      i32.store8
      global.get $g)
    (if (then i32.const 1 global.set $g))))
```

Binaryen rewrites `$g` to immutable and leaves the independent `i32.store8` in the body. Starshine already had full-store candidate-derived negatives; this slice adds a subword-specific candidate-derived negative so a store operand fed by the candidate global keeps the mutable global and guard traffic.

## Implementation

`src/passes/simplify_globals_optimizing.mbt` now admits the integer subword scalar stores in `sgo_loop_independent_prefix_scalar_store_matches(...)` when both consumed operands are literal constants before the final candidate `global.get`.

The matcher still requires:

- a flattened non-branching loop body;
- the final loop instruction to be the single candidate `global.get`;
- each accepted store operand to be a literal constant;
- the outer guard to be the already-supported direct no-else same-global constant-set shape.

It still does not admit candidate-derived store operands, branchy loops, trapping candidate consumers, memory/table growth, bulk effects, atomics, SIMD memory operations, calls, or broad loop FlowScanner reuse.

## Tests

Added focused regressions in `src/passes/simplify_globals_optimizing_test.mbt`:

- `simplify-globals-optimizing removes loop-wrapped independent subword store effect prefixes` proves independent `i32.store8` and `i64.store32` prefixes remain while `$once` becomes immutable and fake guard traffic disappears.
- `simplify-globals-optimizing keeps loop-wrapped candidate-derived subword store prefixes conservative` proves a candidate-derived `i32.store8` operand keeps `$once` mutable and preserves guard traffic.

## Validation

- TDD failure before implementation: `moon test src/passes` failed at the new independent-subword-store regression because `$once` remained mutable.
- Focused pass tests after implementation: `moon test src/passes` passed (`1619/1619`) with existing DAE/pass-manager warnings.
- Standard Moon validation: `moon fmt`, `moon info`, and full `moon test` passed (`3695/3695`) with existing DAE warnings.
- Direct SGO fuzz: `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --out-dir .tmp/pass-fuzz-sgo-loop-subword-store-0681-10000` compared `6759/10000` before the configured `20` Binaryen/tool command-failure stop, with `6759` normalized matches, `0` mismatches, `0` Starshine validation failures, `0` generator failures, and `20` Binaryen/tool command failures (`17` `binaryen-rec-group-zero`, plus one each `binaryen-bad-section-size`, `binaryen-table-index-out-of-range`, and `binaryen-invalid-tag-index`).

## Classification

This is a semantic-safe Binaryen-positive behavior implementation. The classification is based on focused Binaryen positives for each integer subword store, the paired candidate-derived negative, and the narrow transform contract: constant store operands are independent of the candidate global, and only the single final candidate read supplies the same-global guard condition. The store is preserved; only fake candidate-global guard traffic is removed.
