# Optimize-instructions OI-I effectful known-null ref.as_non_null prefix preservation

Date: 2026-06-20

## Summary

Thirty-seventh `[O4Z-AUDIT-OI-I]` reference sub-slice.

This coverage slice locks the existing effect/trap ordering for a known-null `ref.as_non_null` fold when an effectful prefix instruction has already been evaluated before the trapped known-null reference. The guarded shape is:

```wat
call $effect
drop
ref.null eq
ref.as_non_null
;; => drop(call $effect); unreachable
```

Starshine already rewrote the `ref.as_non_null(ref.null)` suffix to `unreachable` while leaving the preceding imported call and drop in place, matching the Binaryen oracle for this local stack order. No optimizer implementation change was needed.

## Binaryen oracle

Probe file: `.tmp/oi-effectful-prefix-ref-as-non-null-null-probe.wat`

Command:

```sh
wasm-opt .tmp/oi-effectful-prefix-ref-as-non-null-null-probe.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -
```

Observed output preserved `drop(call $effect)` before the final `unreachable` and removed `ref.as_non_null`.

## Starshine change

Added a focused WAT test in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions preserves effectful prefix while folding known-null ref.as_non_null`

The test asserts that the optimized public-pipeline function removes `ref.as_non_null`, keeps `call (Func 0)`, keeps a `drop`, and ends in `unreachable`.

No implementation change was required. Existing root/child preservation plus the `ref.as_non_null(ref.null) -> unreachable` fold from `0758` already preserved the prefix effect.

## TDD evidence

Red-first does not apply because this is a coverage/type-surface audit for existing behavior. The newly added focused test passed immediately.

## Focused and broader evidence

- Binaryen oracle:
  - `wasm-opt .tmp/oi-effectful-prefix-ref-as-non-null-null-probe.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -`
  - Preserved `drop(call $effect)` before `unreachable`.
- Focused tests:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*known-null ref.as_non_null*'`
  - Passed: `Total tests: 1, passed: 1, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref.as_non_null*'`
  - Passed: `Total tests: 5, passed: 5, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref*'`
  - Passed: `Total tests: 44, passed: 44, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'`
  - Passed: `Total tests: 174, passed: 174, failed: 0.`
- Broader validation:
  - `moon fmt` passed.
  - `moon test src/passes` passed: `Total tests: 2698, passed: 2698, failed: 0.`
  - `moon build --target native --release src/cmd` passed with existing warnings in `src/passes/pass_manager.mbt` and `src/passes/pass_manager_wbtest.mbt`.
  - `moon info` passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
  - `git diff --check` passed.
- Direct compare smoke:
  - Completed command:
    - `rm -rf .tmp/pass-fuzz-optimize-instructions-oi-i-effectful-known-null-ref-as-non-null-1 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 1 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-i-effectful-known-null-ref-as-non-null-1 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe`
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

- new `ref.as_non_null` known-null proofs beyond direct `ref.null` suffixes;
- select/block/if-known-null reasoning for `ref.as_non_null` operands;
- arbitrary effect preservation for dropped reference operands beyond previously covered local helpers;
- descriptor/exactness/TNH/IIT-sensitive cast behavior;
- broader unreachable/control-debris cleanup;
- flow-sensitive nullable-local facts.

## Remaining work

`[O4Z-AUDIT-OI-I]` remains active for impossible equality beyond the covered subsets, broader definitely-successful and definitely-failed `ref.test` / `ref.cast` proofs, additional unreachable/drop-child and effect preservation outside the now-covered immediate-`ref.i31` known-miss, null-equality, `ref.is_null`, successful `ref.test`, represented impossible `ref.eq`, redundant `ref.as_non_null`, and known-null `ref.as_non_null` prefix paths, and default-mode trap/effect negatives. `[O4Z-AUDIT-OI-J]` and later remain open.
