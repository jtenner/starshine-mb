# Optimize-instructions OI-H call-indexed table.get call_ref boundary

Date: 2026-06-20

## Summary

Eighth `[O4Z-AUDIT-OI-H]` `call_ref` sub-slice.

This boundary slice classifies a source/oracle-backed `table.get` known-target shape that Starshine does not yet directize safely:

```wat
local.get 0
call $index
table.get 0
call_ref $callee
;; Binaryen => call_indirect $0 (type $callee) (local.get 0) (call $index)
;; Starshine today => intentionally unchanged
```

The same boundary applies to `return_call_ref`. Binaryen `version_130` rewrites the target `table.get` to `call_indirect` / `return_call_indirect` while preserving the table-index call in the indirect-call index slot. Starshine's already-covered direct-core `table.get` lowering handles constant-index targets, but this call-indexed table target currently remains unchanged. This slice records that as an explicit fail-closed OI-H boundary rather than hiding it inside generic remaining `call_ref` work.

## Binaryen oracle

Probe file: `.tmp/oi-h-table-get-effectful-index-probe.wat`

Command:

```sh
wasm-opt .tmp/oi-h-table-get-effectful-index-probe.wat --enable-reference-types --enable-gc --enable-tail-call -S -O --optimize-instructions -o -
```

The final probe uses an imported `$index` function returning `i32`, a table typed as `(ref null $callee)`, and an active typed element segment:

```wat
(elem (i32.const 0) (ref null $callee) (ref.func $target))
```

Observed output rewrote `call_ref $callee` to `call_indirect $0 (type $callee)` and rewrote `return_call_ref $callee` to `return_call_indirect $0 (type $callee)`, preserving `(call $index)` as the indirect-call table index in both forms.

## Starshine change

Added one focused boundary test in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions intentionally keeps call-indexed table.get call_ref targets`

The test builds the shape directly because existing OI-H direct-core fixtures are the most reliable way to construct typed `call_ref` / `return_call_ref` surfaces. It asserts that Starshine keeps `call_ref` / `return_call_ref`, keeps the table-index `call (Func 1)`, keeps `table.get`, and does not introduce `call_indirect` / `return_call_indirect` for this call-indexed table target.

No optimizer implementation change was made. A red-first attempt to demand Binaryen-style directization failed before implementation, showing that this is not already covered by the existing constant-index `table.get` directization path. The landed test is intentionally fail-closed because directizing this shape requires a separate local proof that the HOT/lowering representation can preserve the evaluated argument order and the effectful table index in the indirect-call callee-index slot.

## Evidence

- Binaryen oracle:
  - `wasm-opt .tmp/oi-h-table-get-effectful-index-probe.wat --enable-reference-types --enable-gc --enable-tail-call -S -O --optimize-instructions -o -`
  - Directized both call and tail-call forms to indirect calls while preserving `(call $index)` as the table index.
- Red-first positive attempt:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*table.get index effects*'`
  - Failed before any implementation because the optimized body still contained `call_ref` / `table.get`, proving the Binaryen-style directization was not already implemented for the call-indexed table target.
- Landed boundary test:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*call-indexed table.get*'`
  - Passed: `Total tests: 1, passed: 1, failed: 0.`
- Focused and broader validation:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*call_ref*'`
  - Passed: `Total tests: 8, passed: 8, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'`
  - Passed: `Total tests: 193, passed: 193, failed: 0.`
  - `moon fmt` passed.
  - `moon test src/passes` passed: `Total tests: 2723, passed: 2723, failed: 0.`
  - `moon build --target native --release src/cmd` passed with existing warnings in `src/passes/pass_manager.mbt` and `src/passes/pass_manager_wbtest.mbt`.
  - `moon info` passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
  - `git diff --check && git diff --cached --check` passed.
- Direct compare smoke:
  - `rm -rf .tmp/pass-fuzz-optimize-instructions-oi-h-call-indexed-table-get-boundary-1 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 1 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-h-call-indexed-table-get-boundary-1 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe`
  - Requested `1`, compared `1/1`.
  - Normalized matches: `0`.
  - Compare-normalized matches: `0`.
  - Raw mismatches: `1`.
  - Validation failures: `0`.
  - Property failures: `0`.
  - Generator failures: `0`.
  - Command failures: `0`.
  - Cache: wasm-smith `0` hits / `0` misses; Binaryen `1` hit / `0` misses; Binaryen failures `0` hits / `0` misses.
  - Agent classification: the single raw mismatch is a known scalar/default output-shape family from earlier OI slices, not a new `call_ref` semantic failure. Grep of final compare failure artifacts found no `ref.*`, `call_ref`, or `return_call_ref` occurrences.

## Boundaries

This slice does not add:

- a new `table.get` directization implementation for effectful or nonconstant table indices;
- argument or index localization for call-indexed table targets;
- broader `call_ref` known-target reasoning beyond recording this explicit fail-closed boundary;
- changes to the existing constant-index `table.get` directization tests or implementation.

## Remaining work

`[O4Z-AUDIT-OI-H]` remains active for further source-backed known-target shapes beyond the covered direct `ref.func`, direct constant-index `table.get`, select-of-`ref.func`, localized argument select, zero-argument fallthrough-known target, mixed-arm boundary, argument-bearing fallthrough boundary, and this call-indexed `table.get` boundary. A future OI-H slice can reopen this boundary by proving a safe HOT/localizing lowering from call-indexed `table.get` targets to indirect calls. `[O4Z-AUDIT-OI-G]`, `[O4Z-AUDIT-OI-I]`, `[O4Z-AUDIT-OI-J]`, and later slices remain open.
