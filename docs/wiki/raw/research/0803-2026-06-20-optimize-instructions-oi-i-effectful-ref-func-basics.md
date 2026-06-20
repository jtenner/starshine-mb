# Optimize-instructions OI-I effectful ref.func reference basics prefix preservation

Date: 2026-06-20

## Summary

Forty-seventh `[O4Z-AUDIT-OI-I]` reference sub-slice.

This coverage slice locks existing effect ordering for `ref.func`-derived reference basics when an effectful prefix has already been evaluated before the constructor operand. The guarded shapes are:

```wat
call $effect
drop
ref.func $callee
ref.test (ref func)
;; => drop(call $effect); i32.const 1

call $effect
drop
ref.func $callee
ref.cast (ref func)
;; => drop(call $effect); ref.func $callee

call $effect
drop
ref.func $callee
ref.is_null
;; => drop(call $effect); i32.const 0

call $effect
drop
ref.func $callee
ref.as_non_null
;; => drop(call $effect); ref.func $callee
```

A `ref.func` value is a known non-null function reference, so the exact `func` cast/test succeeds, `ref.is_null` is false, and `ref.as_non_null` is redundant. Starshine already preserves the imported call/drop prefix while folding or removing the reference suffixes, matching the Binaryen oracle for this local stack order. No optimizer implementation change was needed.

## Binaryen oracle

Probe file: `.tmp/oi-effectful-ref-func-test-cast-probe.wat`

Command:

```sh
wasm-opt .tmp/oi-effectful-ref-func-test-cast-probe.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -
```

Observed output preserved `drop(call $effect)` before `i32.const 1` for `ref.test (ref func)`, before `ref.func $callee` for `ref.cast (ref func)`, before `i32.const 0` for `ref.is_null`, and before `ref.func $callee` for `ref.as_non_null`. Binaryen removed the redundant `ref.test`, `ref.cast`, `ref.is_null`, and `ref.as_non_null` suffixes.

## Starshine change

Added a focused direct-core test in `src/passes/optimize_instructions_test.mbt` because the local WAT parser does not accept the ordinary typed `ref.test` / `ref.cast` text surface used by the Binaryen probe:

- `optimize-instructions preserves effectful prefix for ref.func reference basics`

The test builds an imported `effect`, a declared `$callee`, and four functions covering exact `func` `ref.test` / `ref.cast`, `ref.is_null`, and `ref.as_non_null` on `ref.func $callee` after `call $effect; drop`. It asserts that the optimized bodies remove the suffix reference instruction, keep `call (Func 0)` and `drop`, fold the test to `I32(1)`, preserve the cast/as-non-null `ref.func`, and fold `ref.is_null` to `I32(0)`.

No implementation change was required. Existing root/prefix preservation plus the known non-null `ref.func`, exact `func` cast/test, and `ref.as_non_null` folds already preserve the evaluated prefix effect.

## TDD evidence

Red-first does not apply because this is a coverage/type-surface audit for existing behavior. The direct-core fixture passed immediately after being added.

## Focused and broader evidence

- Binaryen oracle:
  - `wasm-opt .tmp/oi-effectful-ref-func-test-cast-probe.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -`
  - Preserved `drop(call $effect)` before the folded or simplified `ref.func` reference-basics results.
- Focused tests:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref.func reference basics*'`
  - Passed: `Total tests: 1, passed: 1, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref.func*'`
  - Passed: `Total tests: 6, passed: 6, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref*'`
  - Passed: `Total tests: 54, passed: 54, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'`
  - Passed: `Total tests: 184, passed: 184, failed: 0.`
- Broader validation:
  - `moon fmt` passed.
  - `moon test src/passes` passed: `Total tests: 2714, passed: 2714, failed: 0.`
  - `moon build --target native --release src/cmd` passed.
  - `moon info` passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
  - `git diff --check && git diff --cached --check` passed.
- Direct compare smoke:
  - Completed command:
    - `rm -rf .tmp/pass-fuzz-optimize-instructions-oi-i-effectful-ref-func-basics-1 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 1 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-i-effectful-ref-func-basics-1 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe`
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

- `ref.eq` coverage for `ref.func`; `ref.eq` requires eq-compatible reference operands and the Binaryen WAT probe rejected `funcref` equality;
- target-supertypes or arbitrary function-subtype facts beyond the exact absolute `func` target;
- non-local, local.set-derived, or flow-sensitive function-reference facts;
- descriptor/exactness/TNH/IIT-sensitive cast behavior;
- effect preservation for reference shapes outside the covered already-evaluated prefix order;
- default-mode trap/effect negatives.

## Remaining work

`[O4Z-AUDIT-OI-I]` remains active for impossible equality beyond the covered subsets, broader definitely-successful and definitely-failed `ref.test` / `ref.cast` proofs, additional unreachable/drop-child and effect preservation outside the now-covered immediate-`ref.i31` known-miss, null-equality, `ref.is_null`, successful `ref.test`, represented impossible `ref.eq`, redundant `ref.as_non_null`, known-null `ref.as_non_null` prefix, known-null `ref.eq` prefix, self-local `ref.eq` prefix, same-local `ref.i31` equality prefix, same-local nullable `ref.as_non_null` equality prefix, same-local nullable `ref.cast` equality prefix, nullable-source nullable-target `ref.test` / `ref.cast` prefix paths, nullable-source non-null-target aggregate sibling miss prefix paths, non-null-source nullable-target aggregate success/miss prefix paths, and known-null non-null-target `ref.test` / `ref.cast` prefix paths, plus default-mode trap/effect negatives. Exact `ref.func` reference-basic prefix paths are now covered by this note. `[O4Z-AUDIT-OI-J]` and later remain open.
