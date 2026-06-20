# Optimize-instructions OI-I effectful nullable-source nullable-target cast/test prefix preservation

Date: 2026-06-20

## Summary

Forty-fourth `[O4Z-AUDIT-OI-I]` reference sub-slice.

This coverage slice locks existing effect ordering for nullable-source, nullable-target `ref.test` / `ref.cast` success when an effectful prefix has already been evaluated before the local operand. The guarded shapes are:

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
```

for a parameter declared `(ref null struct)`. Because null satisfies a nullable target and non-null `struct` values are in the modeled absolute `eq` hierarchy, the `ref.test` is definitely successful and the `ref.cast` is a no-op upcast. Starshine already preserves the imported call/drop prefix while folding the suffixes, matching the Binaryen oracle for this local stack order. No optimizer implementation change was needed.

## Binaryen oracle

Probe file: `.tmp/oi-effectful-nullable-source-nullable-target-cast-test-probe.wat`

Command:

```sh
wasm-opt .tmp/oi-effectful-nullable-source-nullable-target-cast-test-probe.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -
```

Observed output preserved `drop(call $effect)` before `i32.const 1` for the test and before `local.get` for the cast. Binaryen removed the `ref.test` and `ref.cast` suffixes.

## Starshine change

Added a focused direct-core test in `src/passes/optimize_instructions_test.mbt` because the local WAT parser still does not accept the ordinary typed `ref.test` / `ref.cast` text surface in these fixtures:

- `optimize-instructions preserves effectful prefix for nullable-source nullable-target ref.test and ref.cast`

The test builds two functions over a nullable `struct` parameter and nullable `eq` target. It asserts that optimized bodies remove `ref.test` / `ref.cast`, keep `call (Func 0)` and `drop`, fold the test to `I32(1)`, and preserve the cast value as `local.get`.

No implementation change was required. Existing root/prefix preservation plus the nullable-source nullable-target local-supertype success fold from `0785` already preserve the evaluated prefix effect.

## TDD evidence

Red-first does not apply because this is a coverage/type-surface audit for existing behavior. The direct-core fixture passed immediately after being added.

## Focused and broader evidence

- Binaryen oracle:
  - `wasm-opt .tmp/oi-effectful-nullable-source-nullable-target-cast-test-probe.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -`
  - Preserved `drop(call $effect)` before the folded test result and no-op cast result.
- Focused tests:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*nullable-source nullable-target ref.test*'`
  - Passed: `Total tests: 2, passed: 2, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref.test and ref.cast*'`
  - Passed: `Total tests: 18, passed: 18, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref*'`
  - Passed: `Total tests: 51, passed: 51, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'`
  - Passed: `Total tests: 181, passed: 181, failed: 0.`
- Broader validation:
  - `moon fmt` passed.
  - `moon test src/passes` passed: `Total tests: 2711, passed: 2711, failed: 0.`
  - `moon build --target native --release src/cmd` passed with existing unused-function warnings in `src/passes/pass_manager.mbt`.
  - `moon info` passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
- Direct compare smoke:
  - Completed command:
    - `rm -rf .tmp/pass-fuzz-optimize-instructions-oi-i-effectful-nullable-source-nullable-target-1 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 1 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-i-effectful-nullable-source-nullable-target-1 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe`
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

- arbitrary nullable-source nullable-target subtype proofs beyond the already-covered local absolute aggregate/i31 supertype helpers;
- non-local, local.set-derived, or flow-sensitive facts;
- descriptor/exactness/TNH/IIT-sensitive cast behavior;
- effect preservation for cast/test shapes outside the covered already-evaluated prefix order;
- default-mode trap/effect negatives.

## Remaining work

`[O4Z-AUDIT-OI-I]` remains active for impossible equality beyond the covered subsets, broader definitely-successful and definitely-failed `ref.test` / `ref.cast` proofs, additional unreachable/drop-child and effect preservation outside the now-covered immediate-`ref.i31` known-miss, null-equality, `ref.is_null`, successful `ref.test`, represented impossible `ref.eq`, redundant `ref.as_non_null`, known-null `ref.as_non_null` prefix, known-null `ref.eq` prefix, self-local `ref.eq` prefix, same-local `ref.i31` equality prefix, same-local nullable `ref.as_non_null` equality prefix, same-local nullable `ref.cast` equality prefix, nullable-source nullable-target `ref.test` / `ref.cast` prefix paths, and known-null non-null-target `ref.test` / `ref.cast` prefix paths, and default-mode trap/effect negatives. `[O4Z-AUDIT-OI-J]` and later remain open.
