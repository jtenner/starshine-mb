# Optimize-instructions OI-I effectful same-local ref.i31 equality prefix preservation

Date: 2026-06-20

## Summary

Forty-first `[O4Z-AUDIT-OI-I]` reference sub-slice.

This coverage slice locks existing effect/trap ordering for the same-local `ref.i31(local.get)` equality proof when an effectful prefix has already been evaluated before the compared constructors. The guarded shape is:

```wat
call $effect
drop
local.get 0
ref.i31
local.get 0
ref.i31
ref.eq
;; => drop(call $effect); i32.const 1
```

Starshine already folds the same-local `ref.i31(local.get)` equality suffix while leaving the preceding imported call and drop in place, matching the Binaryen oracle for this local stack order. No optimizer implementation change was needed.

## Binaryen oracle

Probe file: `.tmp/oi-effectful-same-local-ref-i31-probe.wat`

Command:

```sh
wasm-opt .tmp/oi-effectful-same-local-ref-i31-probe.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -
```

Observed output preserved `drop(call $effect)` before `i32.const 1` for the same-local `ref.i31(local.get)` equality form.

## Starshine change

Added a focused WAT test in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions preserves effectful prefix while folding same-local ref.i31 equality`

The test asserts that the optimized module removes `ref.eq`, keeps `call (Func 0)`, keeps `drop`, and folds the same-local `ref.i31` equality to `I32(1)`.

No implementation change was required. Existing root/prefix preservation plus the same-local `ref.i31(local.get)` equality fold from `0776` already preserve the evaluated prefix effect.

## TDD evidence

Red-first does not apply because this is a coverage/type-surface audit for existing behavior. The WAT fixture passed immediately after being added.

## Focused and broader evidence

- Binaryen oracle:
  - `wasm-opt .tmp/oi-effectful-same-local-ref-i31-probe.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -`
  - Preserved `drop(call $effect)` before `i32.const 1` for the same-local `ref.i31(local.get)` equality.
- Focused tests:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*same-local ref.i31*'`
  - Passed: `Total tests: 2, passed: 2, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref*'`
  - Passed: `Total tests: 48, passed: 48, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'`
  - Passed: `Total tests: 178, passed: 178, failed: 0.`
- Broader validation:
  - `moon fmt` passed.
  - `moon test src/passes` passed: `Total tests: 2702, passed: 2702, failed: 0.`
  - `moon build --target native --release src/cmd` passed / no work to do.
  - `moon info` passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
  - `git diff --check` and `git diff --cached --check` passed.
- Direct compare smoke:
  - Completed command:
    - `rm -rf .tmp/pass-fuzz-optimize-instructions-oi-i-effectful-same-local-ref-i31-1 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 1 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-i-effectful-same-local-ref-i31-1 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe`
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

- new identity proofs beyond direct same-local `ref.i31(local.get N)` operands;
- arbitrary effect preservation for dropped reference operands beyond previously covered local helpers and already-evaluated prefixes;
- non-local/SSA identity or flow-sensitive local facts;
- descriptor/exactness/TNH/IIT-sensitive cast behavior;
- broader unreachable/control-debris cleanup;
- constructor allocation-dropping equality rewrites beyond the locally proven `ref.i31` case.

## Remaining work

`[O4Z-AUDIT-OI-I]` remains active for impossible equality beyond the covered subsets, broader definitely-successful and definitely-failed `ref.test` / `ref.cast` proofs, additional unreachable/drop-child and effect preservation outside the now-covered immediate-`ref.i31` known-miss, null-equality, `ref.is_null`, successful `ref.test`, represented impossible `ref.eq`, redundant `ref.as_non_null`, known-null `ref.as_non_null` prefix, known-null `ref.eq` prefix, known-null non-null-target `ref.test` / `ref.cast` prefix, self-local `ref.eq` prefix, and same-local `ref.i31` equality prefix paths, and default-mode trap/effect negatives. `[O4Z-AUDIT-OI-J]` and later remain open.
