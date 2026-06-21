# Optimize-instructions OI-I effectful non-null aggregate ref.is_null prefix preservation

Date: 2026-06-20

## Summary

Fifty-second `[O4Z-AUDIT-OI-I]` reference sub-slice.

This coverage slice locks existing effect ordering for declared non-null aggregate local `ref.is_null` folds when an effectful prefix has already been evaluated before the local operand. The guarded shapes are:

```wat
call $effect
drop
local.get 0 ;; (ref struct)
ref.is_null
;; => drop(call $effect); i32.const 0

call $effect
drop
local.get 0 ;; (ref array)
ref.is_null
;; => drop(call $effect); i32.const 0
```

A declared non-null `struct` or `array` local cannot be null. Starshine already preserves the imported call/drop prefix while folding the `ref.is_null` suffix to `i32.const 0`, matching the Binaryen oracle for this already-evaluated prefix order. No optimizer implementation change was needed.

## Binaryen oracle

Probe file: `.tmp/oi-effectful-non-null-aggregate-ref-is-null-probe.wat`

Command:

```sh
wasm-opt .tmp/oi-effectful-non-null-aggregate-ref-is-null-probe.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -
```

Observed output preserved `drop(call $effect)` before `i32.const 0` for both the `(ref struct)` and `(ref array)` local cases. Binaryen removed both `ref.is_null` suffixes.

## Starshine change

Added a focused direct-core test in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions preserves effectful prefix while folding non-null aggregate ref.is_null`

The test builds two functions over non-null `struct` and non-null `array` parameters. Each function executes `call effect; drop; local.get 0; ref.is_null`. It asserts that optimized bodies remove `ref.is_null`, keep `call (Func 0)` and `drop`, and fold the suffix to `I32(0)`.

No implementation change was required. Existing root/prefix preservation plus the declared-non-null local proof from `0766` already preserve the evaluated prefix effect.

## TDD evidence

Red-first does not apply because this is a coverage/type-surface audit for existing behavior. The direct-core fixture passed immediately after being added.

## Focused and broader evidence

- Binaryen oracle:
  - `wasm-opt .tmp/oi-effectful-non-null-aggregate-ref-is-null-probe.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -`
  - Preserved `drop(call $effect)` before `i32.const 0` for both non-null aggregate locals.
- Focused tests:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*non-null aggregate ref.is_null*'`
  - Passed: `Total tests: 1, passed: 1, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref.is_null*'`
  - Passed: `Total tests: 5, passed: 5, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref*'`
  - Passed: `Total tests: 59, passed: 59, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'`
  - Passed: `Total tests: 189, passed: 189, failed: 0.`
- Broader validation:
  - `moon fmt` passed.
  - `moon test src/passes` passed: `Total tests: 2719, passed: 2719, failed: 0.`
  - `moon build --target native --release src/cmd` passed.
  - `moon info` passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
  - `git diff --check && git diff --cached --check` passed.
- Direct compare smoke:
  - Completed command:
    - `rm -rf .tmp/pass-fuzz-optimize-instructions-oi-i-effectful-non-null-aggregate-ref-is-null-1 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 1 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-i-effectful-non-null-aggregate-ref-is-null-1 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe`
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

- new non-null proofs beyond already-declared non-null local reference types;
- non-local, local.set-derived, or flow-sensitive facts;
- descriptor/exactness/TNH/IIT-sensitive cast behavior;
- effect preservation for reference shapes outside the covered already-evaluated prefix order;
- default-mode trap/effect negatives.

## Remaining work

`[O4Z-AUDIT-OI-I]` remains active for impossible equality beyond the covered subsets, broader definitely-successful and definitely-failed `ref.test` / `ref.cast` proofs, additional unreachable/drop-child and effect preservation outside the now-covered immediate-`ref.i31` known-miss, null-equality, `ref.is_null`, successful `ref.test`, represented impossible `ref.eq`, redundant `ref.as_non_null`, known-null `ref.as_non_null` prefix, known-null `ref.eq` prefix, self-local `ref.eq` prefix, same-local `ref.i31` equality prefix, same-local nullable `ref.as_non_null` equality prefix, same-local nullable `ref.cast` equality prefix, nullable-source nullable-target aggregate `ref.test` / `ref.cast` prefix paths, nullable-source non-null-target aggregate sibling miss prefix paths, non-null-source nullable-target aggregate success/miss prefix paths, non-null-source non-null-target aggregate success/miss prefix paths, exact `ref.func` reference-basic prefix paths, nullable-source nullable-target `i31` supertype prefix paths, aggregate sibling impossible `ref.eq` prefix paths, local `i31`/struct impossible `ref.eq` prefix paths, and non-null aggregate `ref.is_null` prefix paths, plus default-mode trap/effect negatives. The declared non-null aggregate `ref.is_null` prefix path is now covered by this note. `[O4Z-AUDIT-OI-J]` and later remain open.
