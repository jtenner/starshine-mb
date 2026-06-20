# Optimize-instructions OI-I effectful ref.i31 successful ref.test preservation

Date: 2026-06-20

## Summary

Thirty-fourth `[O4Z-AUDIT-OI-I]` reference sub-slice.

This slice fixes an effectful-operand preservation gap in definitely-successful `ref.test(...)` folding. Before this slice, Starshine folded a known-match immediate `ref.i31` operand tested against an absolute supertype such as `eq` to `i32.const 1` without checking whether the `ref.i31` child expression had side effects. That was correct for pure constructors and local operands, but wrong for stack operands such as an imported call whose result is wrapped by `ref.i31`.

The now-locked shape is:

```wat
call $effect
ref.i31
ref.test (ref eq)
;; => drop(ref.i31(call $effect)); i32.const 1
```

The same focused fixture also checks that the matching successful `ref.cast` still preserves the effect by replacing the cast with the original `ref.i31(call $effect)` operand rather than dropping it.

## Binaryen oracle

Probe file: `.tmp/oi-effectful-ref-test-success-probe.wat`

Command:

```sh
wasm-opt .tmp/oi-effectful-ref-test-success-probe.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -
```

Observed output preserved the imported call as `drop(call $effect)` before `i32.const 1` for the imported-call `ref.i31` successful `ref.test (ref eq)` shape. The matching successful `ref.cast (ref eq)` output kept `ref.i31(call $effect)` and removed only the cast.

## Starshine change

Updated `src/passes/optimize_instructions.mbt` so the known-match branch in `optimize_instructions_try_fold_ref_test_null(...)` checks the operand's effect mask before replacing the whole `ref.test` with `i32.const 1`:

- pure known-match operands still fold directly to `i32.const 1`, preserving prior pure shapes;
- effectful known-match operands rewrite to `drop(operand); i32.const 1`.

The implementation uses the existing `optimize_instructions_replace_with_drop_then_const_i32(...)` helper, matching the known-miss, null-equality, and `ref.is_null` effect-preservation slices.

## TDD evidence

Red-first focused command:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*successful ref.test and ref.cast*'
```

Failed before implementation because the optimized successful `ref.test` function contained only `i32.const 1`, proving the imported call had been dropped.

After implementation, the same focused command passed:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*successful ref.test and ref.cast*'
```

Result: `Total tests: 5, passed: 5, failed: 0.`

## Focused and broader evidence

- Focused `*ref*` test:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref*'`
  - Passed: `Total tests: 41, passed: 41, failed: 0.`
- Focused `*optimize-instructions*` test:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'`
  - Passed: `Total tests: 171, passed: 171, failed: 0.`
- Broader validation:
  - `moon fmt` passed.
  - `moon test src/passes` passed: `Total tests: 2695, passed: 2695, failed: 0.`
  - `moon build --target native --release src/cmd` passed with existing warnings in `src/passes/pass_manager.mbt` and `src/passes/pass_manager_wbtest.mbt`.
  - `moon info` passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
  - `git diff --check` passed.
- Direct compare smoke:
  - Completed command:
    - `rm -rf .tmp/pass-fuzz-optimize-instructions-oi-i-effectful-ref-test-success-1 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 1 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-i-effectful-ref-test-success-1 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe`
  - Requested `1`, compared `1/1`.
  - Normalized matches: `0`.
  - Cleanup-normalized matches: `0`.
  - Raw mismatches: `1`.
  - Validation failures: `0`.
  - Property failures: `0`.
  - Generator failures: `0`.
  - Command failures: `0`.
  - Cache: wasm-smith `0` hits / `0` misses; Binaryen `1` hit / `0` misses; Binaryen failures `0` hits / `0` misses.
  - Agent classification: the single raw mismatch is a known scalar/default output-shape family from earlier OI slices, not a new reference semantic failure. Grep of final compare artifacts found no `ref.*`, `call_ref`, or `return_call_ref` occurrences.

## Boundaries

This slice does not add:

- arbitrary effect preservation for every known-success or known-miss reference fold beyond the now-covered successful `ref.test` path;
- new nullability, equality, subtype, or cast proofs beyond the already-modeled known-match `ref.test` path;
- allocation-dropping constructor identity rewrites;
- descriptor/exactness/TNH/IIT-sensitive cast behavior;
- arbitrary subtype-lattice or indexed/defined heap reasoning;
- flow-sensitive nullable-local facts.

## Evidence captured

- Binaryen oracle:
  - `wasm-opt .tmp/oi-effectful-ref-test-success-probe.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -`
  - Preserved `drop(call $effect)` before `i32.const 1` for successful `ref.test (ref eq)`, and preserved `ref.i31(call $effect)` while removing successful `ref.cast (ref eq)`.
- Focused red/green test:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*successful ref.test and ref.cast*'`
  - Failed before implementation because the call was dropped from the successful `ref.test` fold.
  - Passed after implementation: `Total tests: 5, passed: 5, failed: 0.`
- Focused tests:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref*'`
  - Passed: `Total tests: 41, passed: 41, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'`
  - Passed: `Total tests: 171, passed: 171, failed: 0.`
- Broader validation:
  - `moon fmt` passed.
  - `moon test src/passes` passed: `Total tests: 2695, passed: 2695, failed: 0.`
  - `moon build --target native --release src/cmd` passed with existing warnings in `src/passes/pass_manager.mbt` and `src/passes/pass_manager_wbtest.mbt`.
  - `moon info` passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
  - `git diff --check` passed.
- Direct compare smoke:
  - `.tmp/pass-fuzz-optimize-instructions-oi-i-effectful-ref-test-success-1` requested `1`, compared `1/1`, had `1` known scalar/default output-shape raw mismatch, and had `0` validation/property/generator/command failures. Grep found no `ref.*`, `call_ref`, or `return_call_ref` in final compare artifacts.

## Remaining work

`[O4Z-AUDIT-OI-I]` remains active for impossible equality beyond the covered subsets, broader definitely-successful and definitely-failed `ref.test` / `ref.cast` proofs, additional unreachable/drop-child and effect preservation outside the now-covered immediate-`ref.i31` known-miss, null-equality, `ref.is_null`, and successful `ref.test` paths, and default-mode trap/effect negatives. `[O4Z-AUDIT-OI-J]` and later remain open.
