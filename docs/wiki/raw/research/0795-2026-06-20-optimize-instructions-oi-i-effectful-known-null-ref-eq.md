# Optimize-instructions OI-I effectful known-null ref.eq prefix preservation

Date: 2026-06-20

## Summary

Thirty-ninth `[O4Z-AUDIT-OI-I]` reference sub-slice.

This coverage slice locks existing effect/trap ordering for known-null `ref.eq` cleanup when an effectful prefix instruction has already been evaluated before the compared references. The guarded shapes are:

```wat
call $effect
drop
ref.null eq
ref.null eq
ref.eq
;; => drop(call $effect); i32.const 1

call $effect
drop
ref.null eq
i32.const 1
ref.i31
ref.eq
;; => drop(call $effect); i32.const 0
```

The symmetric known-null/right-hand known-non-null form is covered too. Starshine already folds the `ref.eq` suffix while leaving the preceding imported call and drop in place, matching the Binaryen oracle for this local stack order. No optimizer implementation change was needed.

## Binaryen oracle

Probe file: `.tmp/oi-effectful-known-null-ref-eq-probe.wat`

Command:

```sh
wasm-opt .tmp/oi-effectful-known-null-ref-eq-probe.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -
```

Observed output preserved `drop(call $effect)` before `i32.const 1` for the known-null/known-null equality, and before `i32.const 0` for both known-null versus immediate `ref.i31` miss directions.

## Starshine change

Added a focused WAT test in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions preserves effectful prefix while folding known-null ref.eq`

The test asserts that the optimized module removes all three `ref.eq` operations, keeps `call (Func 0)`, keeps `drop`, folds the known-null/known-null case to `I32(1)`, and folds both known-null/known-non-null miss directions to `I32(0)`.

No implementation change was required. Existing root/prefix preservation plus the known-null and known-non-null `ref.eq` folds from earlier OI-I slices already preserve the evaluated prefix effect.

## TDD evidence

Red-first does not apply because this is a coverage/type-surface audit for existing behavior. The WAT fixture passed immediately after being added.

## Focused and broader evidence

- Binaryen oracle:
  - `wasm-opt .tmp/oi-effectful-known-null-ref-eq-probe.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -`
  - Preserved `drop(call $effect)` before `i32.const 1` / `i32.const 0`.
- Focused tests:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*known-null ref.eq*'`
  - Passed: `Total tests: 1, passed: 1, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref.eq*'`
  - Passed: `Total tests: 3, passed: 3, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref*'`
  - Passed: `Total tests: 46, passed: 46, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'`
  - Passed: `Total tests: 176, passed: 176, failed: 0.`
- Broader validation:
  - `moon fmt` passed.
  - `moon test src/passes` passed: `Total tests: 2700, passed: 2700, failed: 0.`
  - `moon build --target native --release src/cmd` passed.
  - `moon info` passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
  - `git diff --check` and `git diff --cached --check` passed.
- Direct compare smoke:
  - Completed command:
    - `rm -rf .tmp/pass-fuzz-optimize-instructions-oi-i-effectful-known-null-ref-eq-1 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 1 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-i-effectful-known-null-ref-eq-1 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe`
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

- new known-null proofs beyond direct `ref.null` suffixes;
- arbitrary effect preservation for dropped reference operands beyond previously covered local helpers and already-evaluated prefixes;
- non-local/SSA identity or flow-sensitive nullable-local facts;
- descriptor/exactness/TNH/IIT-sensitive cast behavior;
- broader unreachable/control-debris cleanup;
- constructor allocation-dropping equality rewrites beyond the already covered `ref.i31` value cases.

## Remaining work

`[O4Z-AUDIT-OI-I]` remains active for impossible equality beyond the covered subsets, broader definitely-successful and definitely-failed `ref.test` / `ref.cast` proofs, additional unreachable/drop-child and effect preservation outside the now-covered immediate-`ref.i31` known-miss, null-equality, `ref.is_null`, successful `ref.test`, represented impossible `ref.eq`, redundant `ref.as_non_null`, known-null `ref.as_non_null` prefix, known-null `ref.eq` prefix, and known-null non-null-target `ref.test` / `ref.cast` prefix paths, and default-mode trap/effect negatives. `[O4Z-AUDIT-OI-J]` and later remain open.
