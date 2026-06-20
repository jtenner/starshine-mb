# Optimize-instructions OI-I effectful non-null-source nullable-target cast/test prefix preservation

Date: 2026-06-20

## Summary

Forty-sixth `[O4Z-AUDIT-OI-I]` reference sub-slice.

This coverage slice locks existing effect ordering for non-null-source, nullable-target aggregate `ref.test` / `ref.cast` when an effectful prefix has already been evaluated before the local operand. The guarded shapes are:

```wat
call $effect
drop
local.get 0
ref.test (ref null eq)
;; => drop(call $effect); i32.const 1

call $effect
drop
local.get 0
ref.cast (ref null eq)
;; => drop(call $effect); local.get 0

call $effect
drop
local.get 0
ref.test (ref null array)
;; => drop(call $effect); i32.const 0

call $effect
drop
local.get 0
ref.cast (ref null array)
;; => drop(call $effect); unreachable
```

for a parameter declared `(ref struct)`. A non-null `struct` local satisfies nullable `eq` and cannot satisfy nullable `array`: the operand cannot be null, and non-null `struct` values are disjoint from `array` in the covered absolute-heap proof. Starshine already preserves the imported call/drop prefix while folding the suffixes, matching the Binaryen oracle for this local stack order. No optimizer implementation change was needed.

## Binaryen oracle

Probe file: `.tmp/oi-effectful-non-null-source-nullable-target-probe.wat`

Command:

```sh
wasm-opt .tmp/oi-effectful-non-null-source-nullable-target-probe.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -
```

Observed output preserved `drop(call $effect)` before `i32.const 1` for the successful test, before `local.get 0` for the successful cast, before `i32.const 0` for the failed test, and before `unreachable` for the failed cast. Binaryen removed the `ref.test` and `ref.cast` suffixes.

## Starshine change

Added a focused direct-core test in `src/passes/optimize_instructions_test.mbt` because the local WAT parser still does not accept the ordinary typed `ref.test` / `ref.cast` text surface in these fixtures:

- `optimize-instructions preserves effectful prefix for non-null-source nullable-target ref.test and ref.cast`

The test builds four functions over a non-null `struct` parameter, covering nullable `eq` success and nullable `array` miss targets. It asserts that optimized bodies remove `ref.test` / `ref.cast`, keep `call (Func 0)` and `drop`, fold successful `ref.test` to `I32(1)`, remove successful `ref.cast` to the original `local.get`, fold failed `ref.test` to `I32(0)`, and rewrite failed `ref.cast` to `unreachable`.

No implementation change was required. Existing root/prefix preservation plus the nullable-target success and miss folds from `0782` and `0783` already preserve the evaluated prefix effect.

## TDD evidence

Red-first does not apply because this is a coverage/type-surface audit for existing behavior. The direct-core fixture passed immediately after being added.

## Focused and broader evidence

- Binaryen oracle:
  - `wasm-opt .tmp/oi-effectful-non-null-source-nullable-target-probe.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -`
  - Preserved `drop(call $effect)` before the folded test/cast success and miss results.
- Focused tests:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*non-null-source nullable-target ref.test*'`
  - Passed: `Total tests: 1, passed: 1, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref.test and ref.cast*'`
  - Passed: `Total tests: 20, passed: 20, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref*'`
  - Passed: `Total tests: 53, passed: 53, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'`
  - Passed: `Total tests: 183, passed: 183, failed: 0.`
- Broader validation:
  - `moon fmt` passed.
  - `moon test src/passes` passed: `Total tests: 2713, passed: 2713, failed: 0.`
  - `moon build --target native --release src/cmd` passed.
  - `moon info` passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
  - `git diff --check && git diff --cached --check` passed.
- Direct compare smoke:
  - Completed command:
    - `rm -rf .tmp/pass-fuzz-optimize-instructions-oi-i-effectful-non-null-source-nullable-target-1 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 1 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-i-effectful-non-null-source-nullable-target-1 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe`
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

- arbitrary nullable-target proofs beyond the already-covered local absolute aggregate success and sibling-miss helpers;
- non-local, local.set-derived, or flow-sensitive facts;
- descriptor/exactness/TNH/IIT-sensitive cast behavior;
- effect preservation for cast/test shapes outside the covered already-evaluated prefix order;
- default-mode trap/effect negatives.

## Remaining work

`[O4Z-AUDIT-OI-I]` remains active for impossible equality beyond the covered subsets, broader definitely-successful and definitely-failed `ref.test` / `ref.cast` proofs, additional unreachable/drop-child and effect preservation outside the now-covered immediate-`ref.i31` known-miss, null-equality, `ref.is_null`, successful `ref.test`, represented impossible `ref.eq`, redundant `ref.as_non_null`, known-null `ref.as_non_null` prefix, known-null `ref.eq` prefix, self-local `ref.eq` prefix, same-local `ref.i31` equality prefix, same-local nullable `ref.as_non_null` equality prefix, same-local nullable `ref.cast` equality prefix, nullable-source nullable-target `ref.test` / `ref.cast` prefix paths, nullable-source non-null-target aggregate sibling miss prefix paths, non-null-source nullable-target aggregate success/miss prefix paths, and known-null non-null-target `ref.test` / `ref.cast` prefix paths, and default-mode trap/effect negatives. `[O4Z-AUDIT-OI-J]` and later remain open.
