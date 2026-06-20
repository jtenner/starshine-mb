# Optimize-instructions OI-I nullable-source non-null target failed ref.test/ref.cast

Date: 2026-06-20

## Summary

Twenty-eighth `[O4Z-AUDIT-OI-I]` reference sub-slice.

This slice implements the narrow source-backed nullable-source failed cast/test proof that was left open by `0782`: when a local's declared heap is nullable absolute `struct` and the target is non-null absolute `array`, both possible runtime cases are misses. A null operand cannot satisfy a non-null target, and a non-null `struct` value cannot be an `array` value because the absolute aggregate sibling heaps are disjoint.

The locked shapes are:

```wat
local.get 0 ;; (ref null struct)
ref.test (ref array) ;; => i32.const 0

local.get 0 ;; (ref null struct)
ref.cast (ref array) ;; => unreachable
```

## Binaryen oracle

Probe file: `.tmp/oi-nullable-source-non-null-target-miss-cast-test-probe.wat`

Command:

```sh
wasm-opt .tmp/oi-nullable-source-non-null-target-miss-cast-test-probe.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -
```

Observed output folded the `ref.test (ref array)` function to `i32.const 0` and rewrote the matching `ref.cast (ref array)` function to `unreachable`.

## Starshine change

Updated `src/passes/optimize_instructions_test.mbt` with direct-core coverage for nullable-source, non-null-target failed `ref.test` / `ref.cast` on a declared nullable absolute `struct` local against non-null absolute `array`.

Updated `src/passes/optimize_instructions.mbt` with a narrow helper for local operands that can only be null or an absolute aggregate sibling miss. The helper is only used for non-null cast/test targets, so it does not incorrectly fold nullable-target forms where a null source would match.

## TDD evidence

Red-first focused command:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*non-null target ref.test*'
```

Before implementation this failed with the new fixture still containing `ref.test`. After implementation the same command passed `Total tests: 1, passed: 1, failed: 0.`

## Boundaries

This slice does not add:

- nullable-source folding for nullable targets, because null would match those targets,
- arbitrary subtype-lattice or indexed/defined heap disjointness,
- nullable-source success proofs,
- descriptor/exactness/TNH/IIT-sensitive cast behavior,
- effectful operand drop/trap preservation,
- broader unreachable/drop-child cleanup.

The committed proof is limited to direct local operands whose declared heap is an absolute `struct` / `array` sibling and whose target is the opposite non-null absolute aggregate sibling.

## Evidence captured

- Binaryen oracle:
  - `wasm-opt .tmp/oi-nullable-source-non-null-target-miss-cast-test-probe.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -`
  - Folded `ref.test (ref array)` to `i32.const 0` and matching `ref.cast` to `unreachable`.
- Red-first focused test:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*non-null target ref.test*'`
  - Failed before implementation with `ref.test` still present.
- Focused implementation test:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*non-null target ref.test*'`
  - Passed: `Total tests: 1, passed: 1, failed: 0.`
- Focused tests:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref*'`
  - Passed: `Total tests: 35, passed: 35, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'`
  - Passed: `Total tests: 165, passed: 165, failed: 0.`
- Broader validation:
  - `moon fmt` passed.
  - `moon test src/passes` passed: `Total tests: 2677, passed: 2677, failed: 0.`
  - `moon build --target native --release src/cmd` passed with existing unused-function warnings in pass-manager tests.
  - `moon info` passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
  - `git diff --check` passed.
- Direct compare:
  - First run in `.tmp/pass-fuzz-optimize-instructions-oi-i-nullable-source-non-null-target-miss-test-cast-10000` timed out before `result.json`.
  - Rerun command:
    - `rm -rf .tmp/pass-fuzz-optimize-instructions-oi-i-nullable-source-non-null-target-miss-test-cast-10000-rerun && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-i-nullable-source-non-null-target-miss-test-cast-10000-rerun --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe`
  - Requested `10000`, compared `35/10000`.
  - Normalized matches: `0`.
  - Cleanup-normalized matches: `0`.
  - Compare-normalized matches: CLI `0`, `result.json` key `null`.
  - Raw mismatches: `35`.
  - Validation failures: `0`.
  - Property failures: `0`.
  - Generator failures: `0`.
  - Command failures: `0`.
  - Cache: wasm-smith `0` hits / `0` misses; Binaryen `35` hits / `0` misses; Binaryen failures `0` hits / `0` misses.
  - Agent classification: the raw mismatches are known scalar/default output-shape families from earlier OI slices, not new reference semantic failures. Grep of final failure artifacts found no `ref.*`, `call_ref`, or `return_call_ref` occurrences.

## Remaining work

`[O4Z-AUDIT-OI-I]` remains active for impossible equality beyond the covered subsets, nullable-source successful cast/test classification or implementation, broader definitely-successful and definitely-failed `ref.test` / `ref.cast` proofs, broader unreachable/drop-child preservation, and default-mode trap/effect negatives. `[O4Z-AUDIT-OI-J]` and later remain open.
