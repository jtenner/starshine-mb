# Optimize-instructions OI-I nullable-target failed ref.test/ref.cast coverage

Date: 2026-06-20

## Summary

Twenty-sixth `[O4Z-AUDIT-OI-I]` reference sub-slice.

This is a coverage/source-backed audit slice for an already-implemented local proof: when the operand is a declared non-null absolute `struct` local, a nullable absolute `array` target still cannot match because the operand can never be null and the absolute aggregate sibling heaps are disjoint.

The locked shapes are:

```wat
local.get 0 ;; (ref struct)
ref.test (ref null array) ;; => i32.const 0

local.get 0 ;; (ref struct)
ref.cast (ref null array) ;; => unreachable
```

## Binaryen oracle

Probe file: `.tmp/oi-non-null-local-nullable-target-failed-cast-test-probe.wat`

Command:

```sh
wasm-opt .tmp/oi-non-null-local-nullable-target-failed-cast-test-probe.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -
```

Observed output folded the `ref.test (ref null $array)` function to `i32.const 0` and rewrote the matching `ref.cast (ref null $array)` function to `unreachable`.

An exploratory broader probe also showed Binaryen folds nullable-source disjoint local forms when the target is non-null, but that surface was not committed here because the current Starshine direct-core validator rejects those disjoint nullable-source fixtures before the optimizer can run. That validation/type-surface question remains a later boundary/classification item rather than part of this coverage slice.

## Starshine change

Updated `src/passes/optimize_instructions_test.mbt` with direct-core coverage for nullable-target failed `ref.test` / `ref.cast` on a declared non-null absolute `struct` local against absolute `array`.

No optimizer implementation changed. The existing `optimize_instructions_ref_is_known_miss_for_target(...)` proof already treated non-null locals whose absolute heap is disjoint from the target heap as known misses, regardless of target nullability.

## TDD note

Red-first does not apply: this is an explicit coverage/type-surface audit of existing behavior, like earlier OI-I coverage sub-slices. The new focused test passed immediately:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*nullable-target ref.test*'
```

## Boundaries

This slice does not add:

- nullable-source failed cast/test folding,
- validation widening for disjoint nullable-source cast/test fixtures,
- indexed/defined heap subtype disjointness,
- descriptor/exactness/TNH/IIT-sensitive cast behavior,
- effectful operand drop/trap preservation,
- arbitrary subtype-lattice reasoning.

The committed coverage is limited to a declared non-null local whose absolute heap is `struct` and a nullable target whose absolute heap is the disjoint aggregate sibling `array`.

## Evidence captured

- Binaryen oracle:
  - `wasm-opt .tmp/oi-non-null-local-nullable-target-failed-cast-test-probe.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -`
  - Folded `ref.test (ref null array)` to `i32.const 0` and matching `ref.cast` to `unreachable`.
- Focused coverage test:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*nullable-target ref.test*'`
  - Passed immediately: `Total tests: 1, passed: 1, failed: 0.`
- Focused tests:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref*'`
  - Passed: `Total tests: 33, passed: 33, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'`
  - Passed: `Total tests: 163, passed: 163, failed: 0.`
- Broader validation:
  - `moon fmt` passed.
  - `moon test src/passes` passed: `Total tests: 2675, passed: 2675, failed: 0.`
  - `moon build --target native --release src/cmd` passed with no work to do.
  - `moon info` passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
  - `git diff --check` passed.
- Direct compare:
  - First run in `.tmp/pass-fuzz-optimize-instructions-oi-i-nullable-target-disjoint-test-cast-10000` timed out before `result.json`.
  - Rerun command:
    - `rm -rf .tmp/pass-fuzz-optimize-instructions-oi-i-nullable-target-disjoint-test-cast-10000-rerun && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-i-nullable-target-disjoint-test-cast-10000-rerun --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe`
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

`[O4Z-AUDIT-OI-I]` remains active for impossible equality beyond the covered subsets, nullable-source failed cast/test classification or implementation, broader definitely-successful and definitely-failed `ref.test` / `ref.cast` proofs, broader unreachable/drop-child preservation, and default-mode trap/effect negatives. `[O4Z-AUDIT-OI-J]` and later remain open.
