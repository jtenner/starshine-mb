# Optimize-instructions OI-I i31 upcast ref.eq

Date: 2026-06-20

## Summary

Twenty-fifth `[O4Z-AUDIT-OI-I]` reference sub-slice.

This sub-slice widens the same-local nullable `ref.cast(local.get)` equality proof from exact same-heap and absolute `struct` / `array` upcast operands to the narrow absolute `i31` upcast subset:

```wat
local.get 0 ;; (ref null i31)
ref.cast (ref null eq)
local.get 0
ref.eq
```

and the both-operands variant where both sides are immediate nullable `ref.cast (ref null eq)` nodes from the same local. A nullable upcast from absolute `i31` to `eq` preserves the reference identity and accepts null, so comparing the cast result against the original same local is always true.

## Binaryen oracle

Probe file: `.tmp/oi-i31-upcast-ref-eq-probe.wat`

Command:

```sh
wasm-opt .tmp/oi-i31-upcast-ref-eq-probe.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -
```

Observed output folded both exported functions to a shared body containing only `i32.const 1`.

The probe also tried one `(ref null any)` cast operand, which Binaryen accepted and folded. This Starshine slice intentionally implements and tests only the locally validating `eq` target surface because `ref.eq` operands must validate as `eq` references under Starshine's current typechecker.

## Starshine change

Updated `src/passes/optimize_instructions_test.mbt` with direct-core coverage for same-local equality through nullable `ref.cast` from absolute `i31` to `eq`, covering both one-cast and both-cast operand shapes.

Updated `optimize_instructions_ref_eq_same_local_operand(...)` so nullable `ref.cast(local.get N)` can participate in the same-local identity proof when the local declared heap is absolute `i31` and the cast target is accepted by the existing `i31` target-supertype helper.

## TDD note

Red-first command:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*i31 equality through nullable upcast ref.cast*'
```

After correcting an initially invalid direct-core fixture that cast one operand to `(ref null any)`, the new locally valid `eq`-target test failed because the optimized function still contained the `ref.eq` / cast shape. After implementation the same focused test passed.

## Boundaries

This is still a narrow same-local identity proof. It does not add:

- arbitrary cast skipping,
- non-null cast trap removal for nullable locals,
- local.set-derived or SSA value identity,
- descriptor/exactness/TNH/IIT-sensitive cast behavior,
- constructor allocation identity or allocation dropping beyond the already covered immediate `ref.i31` equality subsets,
- broader nullable-local flow facts,
- broader `any`-typed `ref.eq` operand support in Starshine validation.

The implemented widening is limited to immediate nullable `ref.cast(local.get N)` nodes whose local declared heap is absolute `i31` and whose target is an already-modeled `i31` supertype.

## Evidence captured

- Binaryen oracle:
  - `wasm-opt .tmp/oi-i31-upcast-ref-eq-probe.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -`
  - Folded one-cast and both-cast same-local i31 upcast equality shapes to `i32.const 1`.
- Red-first focused test:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*i31 equality through nullable upcast ref.cast*'`
  - Failed before implementation because `ref.eq` remained.
- Focused tests after implementation:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*i31 equality through nullable upcast ref.cast*'`
  - Passed: `Total tests: 1, passed: 1, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref*'`
  - Passed: `Total tests: 32, passed: 32, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'`
  - Passed: `Total tests: 162, passed: 162, failed: 0.`
- Broader validation:
  - `moon fmt` passed.
  - `moon test src/passes` passed: `Total tests: 2674, passed: 2674, failed: 0.`
  - `moon build --target native --release src/cmd` passed with existing pass-manager unused-function warnings.
  - `moon info` passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
  - `git diff --check` passed.
- Direct compare:
  - `rm -rf .tmp/pass-fuzz-optimize-instructions-oi-i-i31-upcast-ref-eq-10000 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-i-i31-upcast-ref-eq-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe`
  - Requested `10000`, compared `35/10000`.
  - Normalized matches: `0`.
  - Cleanup-normalized matches: `0`.
  - Compare-normalized matches: CLI `0`, `result.json` key `null`.
  - Raw mismatches: `35`.
  - Validation failures: `0`.
  - Property failures: `0`.
  - Generator failures: `0`.
  - Command failures: `0`.
  - Cache: wasm-smith `0` hits / `0` misses; Binaryen `28` hits / `7` misses; Binaryen failures `0` hits / `0` misses.
  - Agent classification: the raw mismatches are known scalar/default output-shape families from earlier OI slices, not new reference semantic failures. Grep of final failure artifacts found no `ref.*`, `call_ref`, or `return_call_ref` occurrences.

## Remaining work

`[O4Z-AUDIT-OI-I]` remains active for impossible equality beyond the covered subsets, broader definitely-successful and definitely-failed `ref.test` / `ref.cast` proofs, broader unreachable/drop-child preservation, and default-mode trap/effect negatives. `[O4Z-AUDIT-OI-J]` and later remain open.
