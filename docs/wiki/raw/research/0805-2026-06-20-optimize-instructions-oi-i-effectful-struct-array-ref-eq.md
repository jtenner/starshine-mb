# Optimize-instructions OI-I effectful struct/array ref.eq prefix preservation

Date: 2026-06-20

## Summary

Forty-ninth `[O4Z-AUDIT-OI-I]` reference sub-slice.

This coverage slice locks existing effect ordering for impossible `ref.eq` folds between absolute aggregate sibling locals when at least one operand is declared non-null and an effectful prefix has already been evaluated before the equality operands. The guarded shapes are:

```wat
call $effect
drop
local.get 0 ;; (ref struct)
local.get 1 ;; (ref null array)
ref.eq
;; => drop(call $effect); i32.const 0

call $effect
drop
local.get 0 ;; (ref null struct)
local.get 1 ;; (ref array)
ref.eq
;; => drop(call $effect); i32.const 0
```

A non-null absolute `struct` reference cannot be equal to an `array` reference, and a non-null absolute `array` reference cannot be equal to a `struct` reference. Nullable-both aggregate equality remains intentionally outside this proof because both operands may be null. Starshine already preserves the imported call/drop prefix while folding the impossible equality suffix, matching the Binaryen oracle for this already-evaluated prefix order. No optimizer implementation change was needed.

## Binaryen oracle

Probe file: `.tmp/oi-effectful-struct-array-ref-eq-probe.wat`

Command:

```sh
wasm-opt .tmp/oi-effectful-struct-array-ref-eq-probe.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -
```

Observed output preserved `drop(call $effect)` before `i32.const 0` for both the non-null-struct-vs-nullable-array and nullable-struct-vs-non-null-array equality misses. Binaryen removed each impossible `ref.eq` suffix.

## Starshine change

Added a focused WAT pipeline test in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions preserves effectful prefix while folding struct array ref.eq miss`

The test imports `effect` returning `i32` and defines two functions with `(ref struct)` / `(ref null array)` and `(ref null struct)` / `(ref array)` parameters. Each function executes `call $effect; drop` before the `ref.eq` operands. It asserts that optimized bodies remove `ref.eq`, keep `call (Func 0)`, keep `drop`, and fold the equality miss to `I32(0)`.

No implementation change was required. Existing root/prefix preservation plus the absolute aggregate sibling equality proof from `0772` already preserve the evaluated prefix effect.

## TDD evidence

Red-first does not apply because this is a coverage/type-surface audit for existing behavior. The WAT fixture passed immediately after being added.

## Focused and broader evidence

- Binaryen oracle:
  - `wasm-opt .tmp/oi-effectful-struct-array-ref-eq-probe.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -`
  - Preserved `drop(call $effect)` before both folded impossible aggregate equality results.
- Focused tests:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*struct array ref.eq miss*'`
  - Passed: `Total tests: 1, passed: 1, failed: 0.`
- Broader validation:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref.eq*'` passed: `Total tests: 5, passed: 5, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref*'` passed: `Total tests: 56, passed: 56, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'` passed: `Total tests: 186, passed: 186, failed: 0.`
  - `moon fmt` passed.
  - `moon test src/passes` passed: `Total tests: 2716, passed: 2716, failed: 0.`
  - `moon build --target native --release src/cmd` passed.
  - `moon info` passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
  - `git diff --check && git diff --cached --check` passed.
- Direct compare smoke:
  - Completed command:
    - `rm -rf .tmp/pass-fuzz-optimize-instructions-oi-i-effectful-struct-array-ref-eq-1 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 1 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-i-effectful-struct-array-ref-eq-1 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe`
  - Requested `1`, compared `1/1`.
  - Normalized matches: `0`.
  - Cleanup-normalized matches: `0`.
  - Raw mismatches: `1`.
  - Validation failures: `0`.
  - Property failures: `0`.
  - Generator failures: `0`.
  - Command failures: `0`.
  - Cache: wasm-smith `0` hits / `0` misses; Binaryen `1` hit / `0` misses; Binaryen failures `0` hits / `0` misses.
  - Agent classification: the single raw mismatch is a known scalar/default output-shape family from earlier OI slices, not a new reference semantic failure. Grep of final compare failure artifacts found no `ref.*`, `call_ref`, or `return_call_ref` occurrences.

## Boundaries

This slice does not add:

- new pure impossible equality behavior beyond the `0772` absolute aggregate sibling proof;
- nullable-both aggregate equality folding, because both operands may be null;
- indexed/defined heap subtype or disjointness reasoning;
- constructor identity, allocation dropping, local.set-derived flow facts, or non-local SSA equality;
- descriptor/exactness/TNH/IIT-sensitive behavior;
- effect preservation for reference shapes outside the covered already-evaluated prefix order;
- default-mode trap/effect negatives.

## Remaining work

`[O4Z-AUDIT-OI-I]` remains active for impossible equality beyond the covered subsets, broader definitely-successful and definitely-failed `ref.test` / `ref.cast` proofs, additional unreachable/drop-child and effect preservation outside the now-covered immediate-`ref.i31` known-miss, null-equality, `ref.is_null`, successful `ref.test`, represented immediate-`ref.i31` impossible `ref.eq`, redundant `ref.as_non_null`, known-null `ref.as_non_null` prefix, known-null `ref.eq` prefix, self-local `ref.eq` prefix, same-local `ref.i31` equality prefix, same-local nullable `ref.as_non_null` equality prefix, same-local nullable `ref.cast` equality prefix, nullable-source nullable-target aggregate `ref.test` / `ref.cast` prefix paths, nullable-source non-null-target aggregate sibling miss prefix paths, non-null-source nullable-target aggregate success/miss prefix paths, exact `ref.func` reference-basic prefix paths, and nullable-source nullable-target `i31` supertype prefix paths, plus default-mode trap/effect negatives. The non-null aggregate sibling impossible `ref.eq` prefix path is now covered by this note. `[O4Z-AUDIT-OI-J]` and later remain open.
