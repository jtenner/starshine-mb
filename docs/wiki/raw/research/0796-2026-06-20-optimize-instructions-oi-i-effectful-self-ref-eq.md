# Optimize-instructions OI-I effectful self ref.eq prefix preservation

Date: 2026-06-20

## Summary

Fortieth `[O4Z-AUDIT-OI-I]` reference sub-slice.

This coverage slice locks existing effect/trap ordering for same-local `ref.eq` cleanup when an effectful prefix has already been evaluated before the compared local references. The guarded shape is:

```wat
call $effect
drop
local.get 0
local.get 0
ref.eq
;; => drop(call $effect); i32.const 1
```

Both nullable `eqref` and non-null `(ref eq)` local parameters are covered. Starshine already folds the self equality suffix while leaving the preceding imported call and drop in place, matching the Binaryen oracle for this local stack order. No optimizer implementation change was needed.

## Binaryen oracle

Probe file: `.tmp/oi-effectful-self-ref-eq-probe.wat`

Command:

```sh
wasm-opt .tmp/oi-effectful-self-ref-eq-probe.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -
```

Observed output preserved `drop(call $effect)` before `i32.const 1` for both nullable and non-null same-local equality forms.

## Starshine change

Added a focused WAT test in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions preserves effectful prefix while folding self ref.eq`

The test asserts that the optimized module removes both `ref.eq` operations, keeps `call (Func 0)`, keeps `drop`, and folds both self-local equalities to `I32(1)`.

No implementation change was required. Existing root/prefix preservation plus the same-local `ref.eq` fold from `0775` already preserve the evaluated prefix effect.

## TDD evidence

Red-first does not apply because this is a coverage/type-surface audit for existing behavior. The WAT fixture passed immediately after being added.

## Focused and broader evidence

- Binaryen oracle:
  - `wasm-opt .tmp/oi-effectful-self-ref-eq-probe.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -`
  - Preserved `drop(call $effect)` before `i32.const 1` for nullable and non-null same-local equality.
- Focused tests:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*self ref.eq*'`
  - Passed: `Total tests: 1, passed: 1, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref.eq*'`
  - Passed: `Total tests: 4, passed: 4, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref*'`
  - Passed: `Total tests: 47, passed: 47, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'`
  - Passed: `Total tests: 177, passed: 177, failed: 0.`
- Broader validation:
  - `moon fmt` passed.
  - `moon test src/passes` passed: `Total tests: 2701, passed: 2701, failed: 0.`
  - `moon build --target native --release src/cmd` passed.
  - `moon info` passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
  - `git diff --check` and `git diff --cached --check` passed.
- Direct compare smoke:
  - Completed command:
    - `rm -rf .tmp/pass-fuzz-optimize-instructions-oi-i-effectful-self-ref-eq-1 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 1 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-i-effectful-self-ref-eq-1 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe`
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

- new identity proofs beyond direct same-local `local.get N` operands;
- arbitrary effect preservation for dropped reference operands beyond previously covered local helpers and already-evaluated prefixes;
- non-local/SSA identity or flow-sensitive nullable-local facts;
- descriptor/exactness/TNH/IIT-sensitive cast behavior;
- broader unreachable/control-debris cleanup;
- constructor allocation-dropping equality rewrites.

## Remaining work

`[O4Z-AUDIT-OI-I]` remains active for impossible equality beyond the covered subsets, broader definitely-successful and definitely-failed `ref.test` / `ref.cast` proofs, additional unreachable/drop-child and effect preservation outside the now-covered immediate-`ref.i31` known-miss, null-equality, `ref.is_null`, successful `ref.test`, represented impossible `ref.eq`, redundant `ref.as_non_null`, known-null `ref.as_non_null` prefix, known-null `ref.eq` prefix, known-null non-null-target `ref.test` / `ref.cast` prefix, and self-local `ref.eq` prefix paths, and default-mode trap/effect negatives. `[O4Z-AUDIT-OI-J]` and later remain open.
