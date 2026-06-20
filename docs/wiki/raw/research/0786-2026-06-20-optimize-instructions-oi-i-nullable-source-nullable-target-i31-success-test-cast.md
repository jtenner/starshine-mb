# Optimize-instructions OI-I nullable-source nullable-target i31 successful ref.test/ref.cast coverage

Date: 2026-06-20

## Summary

Thirtieth `[O4Z-AUDIT-OI-I]` reference sub-slice.

This is a coverage/type-surface slice for the nullable-source, nullable-target successful cast/test proof added by `0785`. The implementation from `0785` already handled nullable absolute `i31` locals through the existing `i31` supertype helper, but the committed direct-core fixture only locked the absolute aggregate (`struct` to `eq`) spelling. This slice adds the missing nullable `i31` local coverage.

The locked shapes are:

```wat
local.get 0 ;; (ref null i31)
ref.test (ref null eq) ;; => i32.const 1

local.get 0 ;; (ref null i31)
ref.cast (ref null eq) ;; => local.get 0
```

Null matches the nullable target, and every non-null `i31` value is in the modeled absolute `eq` hierarchy.

## Binaryen oracle

Probe file: `.tmp/oi-nullable-source-nullable-target-i31-success-cast-test-probe.wat`

Command:

```sh
wasm-opt .tmp/oi-nullable-source-nullable-target-i31-success-cast-test-probe.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -
```

Observed output folded the exported `ref.test (ref null eq)` function to `i32.const 1` and removed the matching `ref.cast (ref null eq)`, returning the original `local.get`.

## Starshine change

Updated `src/passes/optimize_instructions_test.mbt` with direct-core coverage for nullable-source, nullable-target successful `ref.test` / `ref.cast` on a declared nullable absolute `i31` local against nullable absolute `eq`.

No optimizer implementation change was needed: `0785` already routed nullable-target local proofs through `optimize_instructions_ref_is_known_match_for_nullable_target(...)`, and that helper already delegates absolute `i31` source heaps to the existing `i31` supertype matcher.

## TDD evidence

Red-first does not apply to this coverage/type-surface sub-slice because the positive behavior was intentionally implemented by `0785` and this slice only locks the missing `i31` fixture. The focused coverage command passed immediately:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*nullable-source nullable-target i31*'
```

Result: `Total tests: 1, passed: 1, failed: 0.`

## Boundaries

This slice does not add:

- new optimizer generalization beyond the existing `0785` nullable-source nullable-target helper,
- non-null target success proofs for nullable sources, because null would miss those targets,
- arbitrary subtype-lattice or indexed/defined heap success proofs,
- flow-sensitive nullable-local facts beyond the local declaration,
- descriptor/exactness/TNH/IIT-sensitive cast behavior,
- effectful operand drop/trap preservation,
- broader unreachable/drop-child cleanup.

## Evidence captured

- Binaryen oracle:
  - `wasm-opt .tmp/oi-nullable-source-nullable-target-i31-success-cast-test-probe.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -`
  - Folded `ref.test (ref null eq)` to `i32.const 1` and removed matching `ref.cast`, returning `local.get`.
- Focused coverage test:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*nullable-source nullable-target i31*'`
  - Passed: `Total tests: 1, passed: 1, failed: 0.`
- Focused tests:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref*'`
  - Passed: `Total tests: 37, passed: 37, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'`
  - Passed: `Total tests: 167, passed: 167, failed: 0.`
- Broader validation:
  - `moon fmt` passed.
  - `moon test src/passes` passed: `Total tests: 2691, passed: 2691, failed: 0.`
  - `moon build --target native --release src/cmd` passed with no work to do.
  - `moon info` passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
  - `git diff --check` passed.
- Direct compare:
  - Command:
    - `rm -rf .tmp/pass-fuzz-optimize-instructions-oi-i-nullable-source-nullable-target-i31-success-test-cast-10000 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-i-nullable-source-nullable-target-i31-success-test-cast-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe`
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
