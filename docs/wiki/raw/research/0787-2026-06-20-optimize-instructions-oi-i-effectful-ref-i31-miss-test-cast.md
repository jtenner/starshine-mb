# Optimize-instructions OI-I effectful ref.i31 failed ref.test/ref.cast preservation

Date: 2026-06-20

## Summary

Thirty-first `[O4Z-AUDIT-OI-I]` reference sub-slice.

This slice fixes the first effectful-operand preservation gap in Starshine's narrow definitely-failed `ref.i31` cast/test proof. Before this slice, the known-miss path folded an immediate `ref.i31` operand against disjoint `struct`/`array` targets to `i32.const 0` or `unreachable` without checking whether the `ref.i31` child expression had side effects. That was correct for the existing pure local-constant fixtures, but wrong for stack operands such as an imported call whose result is wrapped by `ref.i31`.

The now-locked shapes are:

```wat
call $effect
ref.i31
ref.test (ref struct)
;; => drop(call $effect); i32.const 0

call $effect
ref.i31
ref.cast (ref struct)
;; => drop(call $effect); unreachable
```

## Binaryen oracle

Probe file: `.tmp/oi-effectful-ref-i31-miss-cast-test-probe.wat`

Command:

```sh
wasm-opt .tmp/oi-effectful-ref-i31-miss-cast-test-probe.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -
```

Observed output preserved the imported call as `drop(call $effect)` before folding the failed `ref.test` to `i32.const 0` and before rewriting the failed `ref.cast` to `unreachable`.

A pure internal callee probe let Binaryen drop the call, so the committed Starshine fixture uses an import to make the effect boundary explicit.

## Starshine change

Updated `src/passes/optimize_instructions.mbt` so the known-miss `ref.test` / `ref.cast` branches check the operand's effect mask before dropping the original operand:

- pure operands still fold directly to `i32.const 0` or `unreachable`, preserving the prior pure `ref.i31` output shape;
- effectful operands rewrite to a small block that drops the original operand before producing `i32.const 0` or `unreachable`.

Added `optimize_instructions_replace_with_drop_then_unreachable(...)` as the result-typed counterpart to the existing `drop`-then-constant helper.

Updated `src/passes/optimize_instructions_test.mbt` with direct-core coverage using an imported call feeding `ref.i31`, then failed `ref.test (ref struct)` and failed `ref.cast (ref struct)`.

## TDD evidence

Red-first focused command:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*effectful ref.i31*'
```

Failed before implementation because the optimized `ref.test` function contained only `i32.const 0`, proving the imported call had been dropped.

After implementation, the same focused command passed:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*effectful ref.i31*'
```

Result: `Total tests: 1, passed: 1, failed: 0.`

## Boundaries

This slice does not add:

- arbitrary unreachable/drop-child cleanup beyond the known-miss `ref.test` / `ref.cast` branches,
- effect preservation for unrelated OI folds,
- new disjointness proofs beyond the already-modeled immediate `ref.i31` known-miss target set,
- descriptor/exactness/TNH/IIT-sensitive cast behavior,
- arbitrary subtype-lattice or indexed/defined heap success proofs,
- flow-sensitive nullable-local facts.

## Evidence captured

- Binaryen oracle:
  - `wasm-opt .tmp/oi-effectful-ref-i31-miss-cast-test-probe.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -`
  - Preserved `drop(call $effect)` before `i32.const 0` and before `unreachable`.
- Focused red/green test:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*effectful ref.i31*'`
  - Failed before implementation because the call was dropped.
  - Passed after implementation: `Total tests: 1, passed: 1, failed: 0.`
- Focused tests:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref*'`
  - Passed: `Total tests: 38, passed: 38, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'`
  - Passed: `Total tests: 168, passed: 168, failed: 0.`
- Broader validation:
  - `moon fmt` passed.
  - `moon test src/passes` passed: `Total tests: 2692, passed: 2692, failed: 0.`
  - `moon build --target native --release src/cmd` passed with existing warnings in `src/passes/pass_manager.mbt` and `src/passes/pass_manager_wbtest.mbt`.
  - `moon info` passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
  - `git diff --check` passed.
- Direct compare:
  - Command:
    - `rm -rf .tmp/pass-fuzz-optimize-instructions-oi-i-effectful-ref-i31-miss-test-cast-10000 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-i-effectful-ref-i31-miss-test-cast-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe`
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

`[O4Z-AUDIT-OI-I]` remains active for impossible equality beyond the covered subsets, broader definitely-successful and definitely-failed `ref.test` / `ref.cast` proofs, additional unreachable/drop-child preservation outside this `ref.i31` known-miss branch, and default-mode trap/effect negatives. `[O4Z-AUDIT-OI-J]` and later remain open.
