# Optimize-instructions OI-I effectful same-local ref.as_non_null equality prefix preservation

Date: 2026-06-20

## Summary

Forty-second `[O4Z-AUDIT-OI-I]` reference sub-slice.

This coverage slice locks existing effect/trap ordering for same-local nullable `ref.as_non_null(local.get)` equality when an effectful prefix has already been evaluated before the compared operands. The guarded shapes are:

```wat
call $effect
drop
local.get 0
ref.as_non_null
local.get 0
ref.eq
;; => drop(call $effect); drop(ref.as_non_null(local.get 0)); i32.const 1

call $effect
drop
local.get 0
ref.as_non_null
local.get 0
ref.as_non_null
ref.eq
;; => drop(call $effect); one preserved non-null check; i32.const 1
```

Starshine already folds the same-local nullable `ref.as_non_null(local.get)` equality suffix while leaving the preceding imported call/drop prefix and one required non-null trap check in place, matching the Binaryen oracle for this local stack order. No optimizer implementation change was needed.

## Binaryen oracle

Probe file: `.tmp/oi-effectful-same-local-ref-as-non-null-probe.wat`

Command:

```sh
wasm-opt .tmp/oi-effectful-same-local-ref-as-non-null-probe.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -
```

Observed output preserved `drop(call $effect)` before the folded `i32.const 1` and kept one non-null trap check for both the one-sided and both-operands `ref.as_non_null(local.get)` equality forms.

## Starshine change

Added a focused WAT test in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions preserves effectful prefix while folding same-local ref.as_non_null equality`

The test asserts that the optimized module removes `ref.eq`, keeps `call (Func 0)`, keeps `drop`, keeps `ref.as_non_null` for the required non-null trap, and folds each equality result to `I32(1)`.

No implementation change was required. Existing root/prefix preservation plus the same-local nullable `ref.as_non_null(local.get)` equality fold from `0778` already preserve the evaluated prefix effect and the required trap.

## TDD evidence

Red-first does not apply because this is a coverage/type-surface audit for existing behavior. The WAT fixture passed immediately after being added.

## Focused and broader evidence

- Binaryen oracle:
  - `wasm-opt .tmp/oi-effectful-same-local-ref-as-non-null-probe.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -`
  - Preserved `drop(call $effect)` and one non-null trap check before `i32.const 1` for both same-local nullable `ref.as_non_null(local.get)` equality forms.
- Focused tests:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref.as_non_null equality*'`
  - Passed: `Total tests: 2, passed: 2, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref.as_non_null*'`
  - Passed: `Total tests: 6, passed: 6, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref*'`
  - Passed: `Total tests: 49, passed: 49, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'`
  - Passed: `Total tests: 179, passed: 179, failed: 0.`
- Broader validation:
  - `moon fmt` passed.
  - `moon test src/passes` passed: `Total tests: 2703, passed: 2703, failed: 0.`
  - `moon build --target native --release src/cmd` passed / no work to do.
  - `moon info` passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
  - `git diff --check` and `git diff --cached --check` passed.
- Direct compare smoke:
  - Completed command:
    - `rm -rf .tmp/pass-fuzz-optimize-instructions-oi-i-effectful-same-local-ref-as-non-null-1 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 1 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-i-effectful-same-local-ref-as-non-null-1 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe`
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

- new identity proofs beyond direct same-local nullable `ref.as_non_null(local.get N)` operands;
- arbitrary `ref.as_non_null` skipping or trap removal;
- non-local/SSA identity or flow-sensitive local facts;
- descriptor/exactness/TNH/IIT-sensitive cast behavior;
- broader unreachable/control-debris cleanup;
- constructor allocation-dropping equality rewrites beyond already covered local proof subsets.

## Remaining work

`[O4Z-AUDIT-OI-I]` remains active for impossible equality beyond the covered subsets, broader definitely-successful and definitely-failed `ref.test` / `ref.cast` proofs, additional unreachable/drop-child and effect preservation outside the now-covered immediate-`ref.i31` known-miss, null-equality, `ref.is_null`, successful `ref.test`, represented impossible `ref.eq`, redundant `ref.as_non_null`, known-null `ref.as_non_null` prefix, known-null `ref.eq` prefix, self-local `ref.eq` prefix, same-local `ref.i31` equality prefix, same-local nullable `ref.as_non_null` equality prefix, and known-null non-null-target `ref.test` / `ref.cast` prefix paths, and default-mode trap/effect negatives. `[O4Z-AUDIT-OI-J]` and later remain open.
