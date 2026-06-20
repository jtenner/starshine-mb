# Optimize-instructions OI-I effectful same-local ref.cast equality prefix preservation

Date: 2026-06-20

## Summary

Forty-third `[O4Z-AUDIT-OI-I]` reference sub-slice.

This coverage slice locks existing effect ordering for same-local nullable `ref.cast(local.get)` equality when an effectful prefix has already been evaluated before the compared operands. The guarded shapes include one-sided and both-operands nullable no-op casts over an `eqref` local, plus one-sided and both-operands nullable absolute-heap upcasts from a nullable `structref` local to nullable `eqref`:

```wat
call $effect
drop
local.get 0
ref.cast (ref null eq)
local.get 0
ref.eq
;; => drop(call $effect); i32.const 1

call $effect
drop
local.get 0
ref.cast (ref null eq)
local.get 0
ref.cast (ref null eq)
ref.eq
;; => drop(call $effect); i32.const 1
```

Starshine already folds these trap-free same-local nullable cast equality suffixes while preserving the preceding imported call/drop prefix, matching the Binaryen oracle for this local stack order. No optimizer implementation change was needed.

## Binaryen oracle

Probe file: `.tmp/oi-effectful-same-local-ref-cast-probe.wat`

Command:

```sh
wasm-opt .tmp/oi-effectful-same-local-ref-cast-probe.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -
```

Observed output preserved `drop(call $effect)` before `i32.const 1` for both exact nullable no-op cast equality and nullable absolute `struct` to `eq` upcast equality. Binaryen merged equivalent function bodies in the text output, but the surviving bodies preserved the effect prefix and removed the `ref.eq` / `ref.cast` suffixes.

## Starshine change

Added a focused direct-core test in `src/passes/optimize_instructions_test.mbt` because the local WAT parser still does not accept ordinary `ref.cast` text in these fixtures:

- `optimize-instructions preserves effectful prefix while folding same-local ref.cast equality`

The test builds four functions covering exact no-op and absolute `struct`→`eq` upcast variants, with one-sided and both-operands cast forms. It asserts that optimized bodies remove `ref.eq` and `ref.cast`, keep `call (Func 0)` and `drop`, and fold each equality result to `I32(1)`.

No implementation change was required. Existing root/prefix preservation plus the same-local nullable `ref.cast(local.get)` equality folds from `0777`, `0779`, and `0780` already preserve the evaluated prefix effect for these trap-free casts.

## TDD evidence

Red-first does not apply because this is a coverage/type-surface audit for existing behavior. The direct-core fixture passed immediately after being added.

## Focused and broader evidence

- Binaryen oracle:
  - `wasm-opt .tmp/oi-effectful-same-local-ref-cast-probe.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -`
  - Preserved `drop(call $effect)` before `i32.const 1` for exact no-op and absolute upcast same-local nullable `ref.cast(local.get)` equality forms.
- Focused tests:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref.cast equality*'`
  - Passed: `Total tests: 1, passed: 1, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref.cast*'`
  - Passed: `Total tests: 21, passed: 21, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref*'`
  - Passed: `Total tests: 50, passed: 50, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'`
  - Passed: `Total tests: 180, passed: 180, failed: 0.`
- Broader validation:
  - `moon fmt` passed.
  - `moon test src/passes` passed: `Total tests: 2704, passed: 2704, failed: 0.`
  - `moon build --target native --release src/cmd` passed / no work to do.
  - `moon info` passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
- Direct compare smoke:
  - Completed command:
    - `rm -rf .tmp/pass-fuzz-optimize-instructions-oi-i-effectful-same-local-ref-cast-1 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 1 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-i-effectful-same-local-ref-cast-1 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe`
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

- arbitrary cast skipping beyond immediate nullable `ref.cast(local.get N)` shapes already covered by the narrow no-op/upcast equality helpers;
- non-null casts over nullable locals;
- descriptor/exactness/TNH/IIT-sensitive cast behavior;
- local.set-derived flow facts, arbitrary SSA identity, or non-local cast identity proofs;
- effect preservation for cast/test shapes outside the covered already-evaluated prefix order;
- default-mode trap/effect negatives.

## Remaining work

`[O4Z-AUDIT-OI-I]` remains active for impossible equality beyond the covered subsets, broader definitely-successful and definitely-failed `ref.test` / `ref.cast` proofs, additional unreachable/drop-child and effect preservation outside the now-covered immediate-`ref.i31` known-miss, null-equality, `ref.is_null`, successful `ref.test`, represented impossible `ref.eq`, redundant `ref.as_non_null`, known-null `ref.as_non_null` prefix, known-null `ref.eq` prefix, self-local `ref.eq` prefix, same-local `ref.i31` equality prefix, same-local nullable `ref.as_non_null` equality prefix, same-local nullable `ref.cast` equality prefix, and known-null non-null-target `ref.test` / `ref.cast` prefix paths, and default-mode trap/effect negatives. `[O4Z-AUDIT-OI-J]` and later remain open.
