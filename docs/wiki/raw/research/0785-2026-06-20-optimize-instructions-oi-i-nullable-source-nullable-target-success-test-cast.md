# Optimize-instructions OI-I nullable-source nullable-target successful ref.test/ref.cast

Date: 2026-06-20

## Summary

Twenty-ninth `[O4Z-AUDIT-OI-I]` reference sub-slice.

This slice implements the narrow source-backed nullable-source successful cast/test proof left open by `0783` and `0784`: when a local's declared heap is nullable absolute `struct` and the target is nullable absolute `eq`, all possible runtime values match. A null operand matches a nullable target, and a non-null `struct` value is in the modeled absolute `eq` hierarchy.

The locked shapes are:

```wat
local.get 0 ;; (ref null struct)
ref.test (ref null eq) ;; => i32.const 1

local.get 0 ;; (ref null struct)
ref.cast (ref null eq) ;; => local.get 0
```

## Binaryen oracle

Probe file: `.tmp/oi-nullable-source-nullable-target-success-cast-test-probe.wat`

Command:

```sh
wasm-opt .tmp/oi-nullable-source-nullable-target-success-cast-test-probe.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -
```

Observed output folded the exported `ref.test (ref null eq)` function to `i32.const 1` and removed the matching `ref.cast (ref null eq)`, returning the original `local.get`.

## Starshine change

Updated `src/passes/optimize_instructions_test.mbt` with direct-core coverage for nullable-source, nullable-target successful `ref.test` / `ref.cast` on a declared nullable absolute `struct` local against nullable absolute `eq`.

Updated `src/passes/optimize_instructions.mbt` with a narrow `optimize_instructions_ref_is_known_match_for_nullable_target(...)` helper. The helper only fires for local operands whose declared source is nullable and whose declared heap exactly equals the nullable target heap, is absolute `i31` accepted by the existing `i31` supertype helper, or is absolute `struct` / `array` accepted by the existing aggregate-to-`eq` / `any` helper. The `ref.test` and `ref.cast` visitors call it only when the target is nullable.

## TDD evidence

Red-first focused command:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*nullable-source nullable-target ref.test*'
```

Before implementation this failed with the new fixture still containing `ref.test`. After implementation the same command passed `Total tests: 1, passed: 1, failed: 0.`

## Boundaries

This slice does not add:

- non-null target success proofs for nullable sources, because null would miss those targets,
- arbitrary subtype-lattice or indexed/defined heap success proofs,
- flow-sensitive nullable-local facts beyond the local declaration,
- descriptor/exactness/TNH/IIT-sensitive cast behavior,
- effectful operand drop/trap preservation,
- broader unreachable/drop-child cleanup.

The committed proof is limited to direct local operands whose declared heap is accepted by the existing absolute `i31` or absolute aggregate supertype helpers, and only when the cast/test target itself is nullable.

## Evidence captured

- Binaryen oracle:
  - `wasm-opt .tmp/oi-nullable-source-nullable-target-success-cast-test-probe.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -`
  - Folded `ref.test (ref null eq)` to `i32.const 1` and removed matching `ref.cast`, returning `local.get`.
- Red-first focused test:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*nullable-source nullable-target ref.test*'`
  - Failed before implementation with `ref.test` still present.
- Focused implementation test:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*nullable-source nullable-target ref.test*'`
  - Passed: `Total tests: 1, passed: 1, failed: 0.`
- Focused tests:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref*'`
  - Passed: `Total tests: 36, passed: 36, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'`
  - Passed: `Total tests: 166, passed: 166, failed: 0.`
- Broader validation:
  - `moon fmt` passed.
  - `moon test src/passes` passed: `Total tests: 2690, passed: 2690, failed: 0.`
  - `moon build --target native --release src/cmd` passed with existing unused-function warnings in pass-manager tests.
  - `moon info` passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
  - `git diff --check` passed.
- Direct compare:
  - Command:
    - `rm -rf .tmp/pass-fuzz-optimize-instructions-oi-i-nullable-source-nullable-target-success-test-cast-10000 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-i-nullable-source-nullable-target-success-test-cast-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe`
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

`[O4Z-AUDIT-OI-I]` remains active for impossible equality beyond the covered subsets, broader definitely-successful and definitely-failed `ref.test` / `ref.cast` proofs, broader unreachable/drop-child preservation, and default-mode trap/effect negatives. `[O4Z-AUDIT-OI-J]` and later remain open.
