# Optimize-instructions OI-I effectful i31/struct local ref.eq prefix preservation

Date: 2026-06-20

## Summary

Fiftieth `[O4Z-AUDIT-OI-I]` reference sub-slice.

This coverage slice locks existing effect ordering for impossible `ref.eq` folds between a declared non-null `i31` local and a nullable struct local after an effectful prefix has already been evaluated. The guarded shapes are:

```wat
call $effect
drop
local.get 0 ;; (ref i31)
local.get 1 ;; (ref null $s)
ref.eq
;; => drop(call $effect); i32.const 0

call $effect
drop
local.get 0 ;; (ref null $s)
local.get 1 ;; (ref i31)
ref.eq
;; => drop(call $effect); i32.const 0
```

A non-null `i31` reference cannot be equal to a struct reference, and the nullable struct operand does not make the equality possible because the other operand is non-null. Starshine already preserves the imported call/drop prefix while folding the impossible equality suffix, matching the Binaryen oracle for this already-evaluated prefix order. No optimizer implementation change was needed.

## Binaryen oracle

Probe file: `.tmp/oi-effectful-i31-struct-local-ref-eq-probe.wat`

Command:

```sh
wasm-opt .tmp/oi-effectful-i31-struct-local-ref-eq-probe.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -
```

Observed output preserved `drop(call $effect)` before `i32.const 0` for both `(ref i31)` vs `(ref null $s)` and `(ref null $s)` vs `(ref i31)` equality misses. Binaryen removed each impossible `ref.eq` suffix.

## Starshine change

Added a focused WAT pipeline test in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions preserves effectful prefix while folding i31 struct local ref.eq miss`

The test imports `effect` returning `i32` and defines two functions with `(ref i31)` / `(ref null $s)` operands in both orders. Each function executes `call $effect; drop` before the `ref.eq` operands. It asserts that optimized bodies remove `ref.eq`, keep `call (Func 0)`, keep `drop`, and fold the equality miss to `I32(0)`.

No implementation change was required. Existing root/prefix preservation plus the impossible local `i31`/struct equality proof from `0771` already preserve the evaluated prefix effect.

## TDD evidence

Red-first does not apply because this is a coverage/type-surface audit for existing behavior. The WAT fixture passed immediately after being added.

## Focused and broader evidence

- Binaryen oracle:
  - `wasm-opt .tmp/oi-effectful-i31-struct-local-ref-eq-probe.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -`
  - Preserved `drop(call $effect)` before both folded impossible local equality results.
- Focused tests:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*i31 struct local ref.eq miss*'`
  - Passed: `Total tests: 1, passed: 1, failed: 0.`
- Broader validation:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref.eq*'` passed: `Total tests: 6, passed: 6, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref*'` passed: `Total tests: 57, passed: 57, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'` passed: `Total tests: 187, passed: 187, failed: 0.`
  - `moon fmt` passed.
  - `moon test src/passes` passed: `Total tests: 2717, passed: 2717, failed: 0.`
  - `moon build --target native --release src/cmd` passed with existing unused-function warnings in `src/passes/pass_manager.mbt`.
  - `moon info` passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
  - `git diff --check && git diff --cached --check` passed.
- Direct compare smoke:
  - Completed command:
    - `rm -rf .tmp/pass-fuzz-optimize-instructions-oi-i-effectful-i31-struct-local-ref-eq-1 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 1 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-i-effectful-i31-struct-local-ref-eq-1 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe`
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

- new pure impossible equality behavior beyond the `0771` local `i31`/struct proof;
- nullable-both equality folding, because both operands may be null in those unrelated shapes;
- aggregate struct/array sibling behavior beyond `0805`;
- indexed/defined heap subtype or disjointness reasoning beyond the already-covered local proof;
- constructor identity, allocation dropping, local.set-derived flow facts, or non-local SSA equality;
- descriptor/exactness/TNH/IIT-sensitive behavior;
- effect preservation for reference shapes outside the covered already-evaluated prefix order;
- default-mode trap/effect negatives.

## Remaining work

`[O4Z-AUDIT-OI-I]` remains active for impossible equality beyond the covered subsets, broader definitely-successful and definitely-failed `ref.test` / `ref.cast` proofs, additional unreachable/drop-child and effect preservation outside the now-covered immediate-`ref.i31` known-miss, null-equality, `ref.is_null`, successful `ref.test`, represented immediate-`ref.i31` impossible `ref.eq`, redundant `ref.as_non_null`, known-null `ref.as_non_null` prefix, known-null `ref.eq` prefix, self-local `ref.eq` prefix, same-local `ref.i31` equality prefix, same-local nullable `ref.as_non_null` equality prefix, same-local nullable `ref.cast` equality prefix, nullable-source nullable-target aggregate `ref.test` / `ref.cast` prefix paths, nullable-source non-null-target aggregate sibling miss prefix paths, non-null-source nullable-target aggregate success/miss prefix paths, exact `ref.func` reference-basic prefix paths, nullable-source nullable-target `i31` supertype prefix paths, and non-null aggregate sibling impossible `ref.eq` prefix paths, plus default-mode trap/effect negatives. The local `i31`/struct impossible `ref.eq` prefix path is now covered by this note. `[O4Z-AUDIT-OI-J]` and later remain open.
