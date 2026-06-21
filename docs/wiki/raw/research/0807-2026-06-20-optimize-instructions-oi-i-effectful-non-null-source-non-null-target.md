# Optimize-instructions OI-I effectful non-null-source non-null-target cast/test prefix preservation

Date: 2026-06-20

## Summary

Fifty-first `[O4Z-AUDIT-OI-I]` reference sub-slice.

This coverage slice locks existing effect ordering for non-null-source, non-null-target aggregate `ref.test` / `ref.cast` when an effectful prefix has already been evaluated before the local operand. The guarded shapes are:

```wat
call $effect
drop
local.get 0 ;; (ref struct)
ref.test (ref eq)
;; => drop(call $effect); i32.const 1

call $effect
drop
local.get 0 ;; (ref struct)
ref.cast (ref eq)
;; => drop(call $effect); local.get 0

call $effect
drop
local.get 0 ;; (ref struct)
ref.test (ref array)
;; => drop(call $effect); i32.const 0

call $effect
drop
local.get 0 ;; (ref struct)
ref.cast (ref array)
;; => drop(call $effect); unreachable
```

A non-null `struct` local satisfies the non-null `eq` supertype and cannot satisfy the non-null `array` sibling target. Starshine already preserves the imported call/drop prefix while folding the suffixes, matching the Binaryen oracle for this already-evaluated prefix order. No optimizer implementation change was needed.

## Binaryen oracle

Probe file: `.tmp/oi-effectful-non-null-source-non-null-target-probe.wat`

Command:

```sh
wasm-opt .tmp/oi-effectful-non-null-source-non-null-target-probe.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -
```

Observed output preserved `drop(call $effect)` before `i32.const 1` for the successful test, before `local.get 0` for the successful cast, before `i32.const 0` for the failed test, and before `unreachable` for the failed cast. Binaryen removed the `ref.test` and `ref.cast` suffixes.

## Starshine change

Added a focused direct-core test in `src/passes/optimize_instructions_test.mbt` because the local WAT parser still does not accept the ordinary typed `ref.test` / `ref.cast` text surface in these fixtures:

- `optimize-instructions preserves effectful prefix for non-null-source non-null-target ref.test and ref.cast`

The test builds four functions over a non-null `struct` parameter, covering non-null `eq` success and non-null `array` miss targets. It asserts that optimized bodies remove `ref.test` / `ref.cast`, keep `call (Func 0)` and `drop`, fold successful `ref.test` to `I32(1)`, remove successful `ref.cast` to the original `local.get`, fold failed `ref.test` to `I32(0)`, and rewrite failed `ref.cast` to `unreachable`.

No implementation change was required. Existing root/prefix preservation plus the non-null-target exact/supertype and sibling-miss folds from `0767`, `0773`, and `0774` already preserve the evaluated prefix effect.

## TDD evidence

Red-first does not apply because this is a coverage/type-surface audit for existing behavior. The direct-core fixture passed immediately after being added.

## Focused and broader evidence

- Binaryen oracle:
  - `wasm-opt .tmp/oi-effectful-non-null-source-non-null-target-probe.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -`
  - Preserved `drop(call $effect)` before the folded test/cast success and miss results.
- Focused tests:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*non-null-source non-null-target ref.test*'`
  - Passed: `Total tests: 1, passed: 1, failed: 0.`
- Broader validation:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref.test and ref.cast*'` passed: `Total tests: 22, passed: 22, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref*'` passed: `Total tests: 58, passed: 58, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'` passed: `Total tests: 188, passed: 188, failed: 0.`
  - `moon fmt` passed.
  - `moon test src/passes` passed: `Total tests: 2718, passed: 2718, failed: 0.`
  - `moon build --target native --release src/cmd` passed.
  - `moon info` passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
  - `git diff --check && git diff --cached --check` passed.
- Direct compare smoke:
  - Completed command:
    - `rm -rf .tmp/pass-fuzz-optimize-instructions-oi-i-effectful-non-null-source-non-null-target-1 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 1 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-i-effectful-non-null-source-non-null-target-1 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe`
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

- arbitrary non-null-target proofs beyond the already-covered local absolute aggregate success and sibling-miss helpers;
- non-local, local.set-derived, or flow-sensitive facts;
- descriptor/exactness/TNH/IIT-sensitive cast behavior;
- effect preservation for cast/test shapes outside the covered already-evaluated prefix order;
- default-mode trap/effect negatives.

## Remaining work

`[O4Z-AUDIT-OI-I]` remains active for impossible equality beyond the covered subsets, broader definitely-successful and definitely-failed `ref.test` / `ref.cast` proofs, additional unreachable/drop-child and effect preservation outside the now-covered immediate-`ref.i31` known-miss, null-equality, `ref.is_null`, successful `ref.test`, represented impossible `ref.eq`, redundant `ref.as_non_null`, known-null `ref.as_non_null` prefix, known-null `ref.eq` prefix, self-local `ref.eq` prefix, same-local `ref.i31` equality prefix, same-local nullable `ref.as_non_null` equality prefix, same-local nullable `ref.cast` equality prefix, nullable-source nullable-target aggregate `ref.test` / `ref.cast` prefix paths, nullable-source non-null-target aggregate sibling miss prefix paths, non-null-source nullable-target aggregate success/miss prefix paths, non-null-source non-null-target aggregate success/miss prefix paths, exact `ref.func` reference-basic prefix paths, nullable-source nullable-target `i31` supertype prefix paths, aggregate sibling impossible `ref.eq` prefix paths, and local `i31`/struct impossible `ref.eq` prefix paths, plus default-mode trap/effect negatives. The non-null-source non-null-target aggregate `ref.test` / `ref.cast` prefix path is now covered by this note. `[O4Z-AUDIT-OI-J]` and later remain open.
