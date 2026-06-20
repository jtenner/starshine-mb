# Optimize-instructions OI-I effectful nullable-source non-null-target cast/test miss prefix preservation

Date: 2026-06-20

## Summary

Forty-fifth `[O4Z-AUDIT-OI-I]` reference sub-slice.

This coverage slice locks existing effect ordering for nullable-source, non-null-target aggregate sibling-miss `ref.test` / `ref.cast` when an effectful prefix has already been evaluated before the local operand. The guarded shapes are:

```wat
call $effect
drop
local.get 0
ref.test (ref array)
;; => drop(call $effect); i32.const 0

call $effect
drop
local.get 0
ref.cast (ref array)
;; => drop(call $effect); unreachable
```

for a parameter declared `(ref null struct)`. A nullable `struct` local cannot satisfy a non-null `array` target: null misses the non-null target, and non-null `struct` values are disjoint from `array` in the covered absolute-heap proof. Starshine already preserves the imported call/drop prefix while folding the suffixes, matching the Binaryen oracle for this local stack order. No optimizer implementation change was needed.

## Binaryen oracle

Probe file: `.tmp/oi-effectful-nullable-source-non-null-target-miss-probe.wat`

Command:

```sh
wasm-opt .tmp/oi-effectful-nullable-source-non-null-target-miss-probe.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -
```

Observed output preserved `drop(call $effect)` before `i32.const 0` for the test and before `unreachable` for the cast. Binaryen removed the `ref.test` and `ref.cast` suffixes.

## Starshine change

Added a focused direct-core test in `src/passes/optimize_instructions_test.mbt` because the local WAT parser still does not accept the ordinary typed `ref.test` / `ref.cast` text surface in these fixtures:

- `optimize-instructions preserves effectful prefix for nullable-source non-null-target ref.test and ref.cast miss`

The test builds two functions over a nullable `struct` parameter and non-null `array` target. It asserts that optimized bodies remove `ref.test` / `ref.cast`, keep `call (Func 0)` and `drop`, fold the test to `I32(0)`, and rewrite the impossible cast to `unreachable`.

No implementation change was required. Existing root/prefix preservation plus the nullable-source, non-null-target aggregate sibling miss fold from `0784` already preserve the evaluated prefix effect.

## TDD evidence

Red-first does not apply because this is a coverage/type-surface audit for existing behavior. The direct-core fixture passed immediately after being added.

## Focused and broader evidence

- Binaryen oracle:
  - `wasm-opt .tmp/oi-effectful-nullable-source-non-null-target-miss-probe.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -`
  - Preserved `drop(call $effect)` before the folded test miss and cast trap.
- Focused tests:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*nullable-source non-null-target ref.test*'`
  - Passed: `Total tests: 1, passed: 1, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref.test and ref.cast*'`
  - Passed: `Total tests: 19, passed: 19, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref*'`
  - Passed: `Total tests: 52, passed: 52, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'`
  - Passed: `Total tests: 182, passed: 182, failed: 0.`
- Broader validation:
  - `moon fmt` passed.
  - `moon test src/passes` passed: `Total tests: 2712, passed: 2712, failed: 0.`
  - `moon build --target native --release src/cmd` passed.
  - `moon info` passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
  - `git diff --check && git diff --cached --check` passed.
- Direct compare smoke:
  - Completed command:
    - `rm -rf .tmp/pass-fuzz-optimize-instructions-oi-i-effectful-nullable-source-non-null-target-1 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 1 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-i-effectful-nullable-source-non-null-target-1 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe`
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

- arbitrary nullable-source, non-null-target proofs beyond the already-covered local absolute aggregate sibling miss helper;
- non-local, local.set-derived, or flow-sensitive facts;
- descriptor/exactness/TNH/IIT-sensitive cast behavior;
- effect preservation for cast/test shapes outside the covered already-evaluated prefix order;
- default-mode trap/effect negatives.

## Remaining work

`[O4Z-AUDIT-OI-I]` remains active for impossible equality beyond the covered subsets, broader definitely-successful and definitely-failed `ref.test` / `ref.cast` proofs, additional unreachable/drop-child and effect preservation outside the now-covered immediate-`ref.i31` known-miss, null-equality, `ref.is_null`, successful `ref.test`, represented impossible `ref.eq`, redundant `ref.as_non_null`, known-null `ref.as_non_null` prefix, known-null `ref.eq` prefix, self-local `ref.eq` prefix, same-local `ref.i31` equality prefix, same-local nullable `ref.as_non_null` equality prefix, same-local nullable `ref.cast` equality prefix, nullable-source nullable-target `ref.test` / `ref.cast` prefix paths, nullable-source non-null-target aggregate sibling miss prefix paths, and known-null non-null-target `ref.test` / `ref.cast` prefix paths, and default-mode trap/effect negatives. `[O4Z-AUDIT-OI-J]` and later remain open.
