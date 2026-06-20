# Optimize-instructions OI-I effectful nullable i31 supertype prefix preservation

Date: 2026-06-20

## Summary

Forty-eighth `[O4Z-AUDIT-OI-I]` reference sub-slice.

This coverage slice locks existing effect ordering for nullable-source, nullable-target `i31` supertype `ref.test` / `ref.cast` folds when an effectful prefix has already been evaluated before the local reference operand. The guarded shapes are:

```wat
call $effect
drop
local.get 0 ;; (ref null i31)
ref.test (ref null eq)
;; => drop(call $effect); i32.const 1

call $effect
drop
local.get 0 ;; (ref null i31)
ref.cast (ref null eq)
;; => drop(call $effect); local.get 0
```

A nullable `i31` local is always inside the nullable `eq` target: null matches the nullable target, and non-null `i31` values are `eq` references. Starshine already preserves the imported call/drop prefix while folding the test and removing the no-op supertype cast, matching the Binaryen oracle for this local stack order. No optimizer implementation change was needed.

## Binaryen oracle

Probe file: `.tmp/oi-effectful-nullable-i31-supertype-probe.wat`

Command:

```sh
wasm-opt .tmp/oi-effectful-nullable-i31-supertype-probe.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -
```

Observed output preserved `drop(call $effect)` before `i32.const 1` for `ref.test (ref null eq)` and before `local.get $0` for `ref.cast (ref null eq)`. Binaryen removed the redundant `ref.test` and `ref.cast` suffixes.

## Starshine change

Added a focused direct-core test in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions preserves effectful prefix for nullable-source nullable-target i31 ref.test and ref.cast`

The test builds an imported `effect` and two functions whose parameter is `(ref null i31)`. Each function executes `call $effect; drop; local.get 0` before either `ref.test (ref null eq)` or `ref.cast (ref null eq)`. It asserts that the optimized bodies remove the reference suffix, keep `call (Func 0)` and `drop`, fold the test to `I32(1)`, and preserve `local.get` for the cast result.

No implementation change was required. Existing root/prefix preservation plus the nullable-source, nullable-target `i31` supertype proof from `0786` already preserve the evaluated prefix effect.

## TDD evidence

Red-first does not apply because this is a coverage/type-surface audit for existing behavior. The direct-core fixture passed immediately after being added.

## Focused and broader evidence

- Binaryen oracle:
  - `wasm-opt .tmp/oi-effectful-nullable-i31-supertype-probe.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -`
  - Preserved `drop(call $effect)` before the folded/simplified nullable `i31` supertype results.
- Focused tests:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*nullable-source nullable-target i31*'`
  - Passed: `Total tests: 2, passed: 2, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref*'`
  - Passed: `Total tests: 55, passed: 55, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'`
  - Passed: `Total tests: 185, passed: 185, failed: 0.`
- Broader validation:
  - `moon fmt` passed.
  - `moon test src/passes` passed: `Total tests: 2715, passed: 2715, failed: 0.`
  - `moon build --target native --release src/cmd` passed.
  - `moon info` passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
  - `git diff --check && git diff --cached --check` passed.
- Direct compare smoke:
  - Completed command:
    - `rm -rf .tmp/pass-fuzz-optimize-instructions-oi-i-effectful-nullable-i31-supertype-1 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 1 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-i-effectful-nullable-i31-supertype-1 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe`
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

- new pure cast/test behavior beyond the `0786` nullable-source, nullable-target absolute `i31` supertype subset;
- non-local, local.set-derived, or flow-sensitive nullable-`i31` facts;
- non-null-target casts/tests for nullable `i31` sources;
- descriptor/exactness/TNH/IIT-sensitive cast behavior;
- effect preservation for reference shapes outside the covered already-evaluated prefix order;
- default-mode trap/effect negatives.

## Remaining work

`[O4Z-AUDIT-OI-I]` remains active for impossible equality beyond the covered subsets, broader definitely-successful and definitely-failed `ref.test` / `ref.cast` proofs, additional unreachable/drop-child and effect preservation outside the now-covered immediate-`ref.i31` known-miss, null-equality, `ref.is_null`, successful `ref.test`, represented impossible `ref.eq`, redundant `ref.as_non_null`, known-null `ref.as_non_null` prefix, known-null `ref.eq` prefix, self-local `ref.eq` prefix, same-local `ref.i31` equality prefix, same-local nullable `ref.as_non_null` equality prefix, same-local nullable `ref.cast` equality prefix, nullable-source nullable-target aggregate `ref.test` / `ref.cast` prefix paths, nullable-source non-null-target aggregate sibling miss prefix paths, non-null-source nullable-target aggregate success/miss prefix paths, exact `ref.func` reference-basic prefix paths, and known-null non-null-target `ref.test` / `ref.cast` prefix paths, plus default-mode trap/effect negatives. The nullable-source nullable-target `i31` supertype prefix path is now covered by this note. `[O4Z-AUDIT-OI-J]` and later remain open.
