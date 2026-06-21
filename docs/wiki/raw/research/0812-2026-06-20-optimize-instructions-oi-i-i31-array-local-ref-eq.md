# Optimize-instructions OI-I i31/array local ref.eq miss

Date: 2026-06-20

## Summary

Fifty-fifth `[O4Z-AUDIT-OI-I]` reference sub-slice.

This coverage slice closes the array half of the narrow local disjoint-equality proof for declared `i31` values:

```wat
local.get $i31   ;; (ref i31)
local.get $array ;; (ref null array)
ref.eq
;; => i32.const 0

call $effect
drop
local.get $i31
local.get $array
ref.eq
;; => drop(call $effect); i32.const 0
```

Binaryen folds the equality because a non-null `i31` reference cannot equal an array reference, even when the array operand is nullable. Starshine already had this proof through `optimize_instructions_ref_cannot_be_i31(...)` and `optimize_instructions_try_rewrite_ref_eq_null(...)`; this slice adds explicit array coverage and records the oracle evidence. Red-first does not apply because this is a coverage/type-surface audit slice for already-implemented behavior, not a new implementation gap.

## Binaryen oracle

Probe file: `.tmp/oi-i-i31-array-ref-eq-probe.wat`

Command:

```sh
wasm-opt .tmp/oi-i-i31-array-ref-eq-probe.wat --enable-gc --enable-reference-types -S -O --optimize-instructions -o -
```

Observed output folded the pure `(ref i31)` vs nullable `arrayref` equality to `i32.const 0` and preserved `drop(call $effect)` before the same folded result for both operand orders.

## Starshine change

No optimizer implementation change was required. Added the focused WAT pipeline test:

- `optimize-instructions preserves effectful prefix while folding i31 array local ref.eq miss`

The test asserts that the `ref.eq` node is removed, `call (Func 0)` and `drop` remain, and the folded suffix is `I32(0)` for both `(ref i31)` left / nullable-array right and nullable-array left / `(ref i31)` right operand orders.

## Evidence

- Binaryen oracle:
  - `wasm-opt .tmp/oi-i-i31-array-ref-eq-probe.wat --enable-gc --enable-reference-types -S -O --optimize-instructions -o -`
  - Folded pure and effect-prefix `(ref i31)` vs nullable `arrayref` equality shapes as expected.
- Focused coverage:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*i31 array local*'` passed immediately: `Total tests: 1, passed: 1, failed: 0.`
  - This immediate pass is expected and documented as coverage-only evidence for already-implemented behavior, not a red-first behavior gap.
- Broader validation:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref.eq*'` passed: `Total tests: 7, passed: 7, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref*'` passed: `Total tests: 64, passed: 64, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'` passed: `Total tests: 194, passed: 194, failed: 0.`
  - `moon fmt` passed.
  - `moon test src/passes` passed: `Total tests: 2724, passed: 2724, failed: 0.`
  - `moon build --target native --release src/cmd` passed (`moon: no work to do`).
  - `moon info` passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
  - `git diff --check && git diff --cached --check` passed.
- Direct compare smoke:
  - Completed command:
    - `rm -rf .tmp/pass-fuzz-optimize-instructions-oi-i-i31-array-ref-eq-1 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 1 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-i-i31-array-ref-eq-1 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe`
  - Requested `1`, compared `1/1`.
  - Normalized matches: `0`.
  - Cleanup/compare-normalized matches: `0`.
  - Raw mismatches: `1`.
  - Validation failures: `0`.
  - Property failures: `0`.
  - Generator failures: `0`.
  - Command failures: `0`.
  - Cache: wasm-smith `0` hits / `0` misses; Binaryen `1` hit / `0` misses; Binaryen failures `0` hits / `0` misses.
  - Agent classification: the single raw mismatch is a known scalar/default output-shape family from earlier OI slices, not a new reference semantic failure. Grep of final compare failure artifacts found no `ref.*`, `call_ref`, or `return_call_ref` occurrences.

## Boundaries

This slice does not add:

- indexed heap-type disjointness beyond the existing absolute `i31` vs absolute aggregate helper facts;
- broader descriptor, exactness, TNH, or IIT reasoning;
- new `ref.test` / `ref.cast` behavior;
- default-mode trap/effect negatives beyond preserving the already-evaluated `drop(call $effect)` prefix.

## Remaining work

`[O4Z-AUDIT-OI-I]` remains active for impossible equality beyond the covered null-vs-known-non-null, literal-`ref.i31`, same-local identity, same-local `ref.i31(local.get)`, same-local cast/as_non_null, absolute aggregate sibling, i31/struct, and this i31/array local subset; additional successful and failed `ref.test` / `ref.cast` cases; broader unreachable/drop-child and effect preservation; and default-mode trap/effect negatives. `[O4Z-AUDIT-OI-G]`, `[O4Z-AUDIT-OI-H]`, `[O4Z-AUDIT-OI-J]`, and later remain open.
