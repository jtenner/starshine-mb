# Optimize-instructions OI-I effectful ref.i31 null-equality preservation

Date: 2026-06-20

## Summary

Thirty-second `[O4Z-AUDIT-OI-I]` reference sub-slice.

This slice fixes a second effectful-operand preservation gap, this time in known-non-null `ref.eq(..., ref.null)` folding. Before this slice, Starshine folded an immediate `ref.i31` value compared with `ref.null` to `i32.const 0` without checking whether the `ref.i31` child expression had side effects. That was correct for pure constants and locals, but wrong for stack operands such as an imported call whose result is wrapped by `ref.i31`.

The now-locked shape is:

```wat
call $effect
ref.i31
ref.null eq
ref.eq
;; => drop(call $effect); i32.const 0
```

## Binaryen oracle

Probe file: `.tmp/oi-effectful-ref-eq-null-probe.wat`

Command:

```sh
wasm-opt .tmp/oi-effectful-ref-eq-null-probe.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -
```

Observed output preserved the imported call as `drop(call $effect)` before `i32.const 0` for the imported-call `ref.i31` null-equality miss.

## Starshine change

Updated `src/passes/optimize_instructions.mbt` so null equality against a locally known-non-null operand checks the operand's effect mask before replacing the whole `ref.eq` with `i32.const 0`:

- pure known-non-null operands still fold directly to `i32.const 0`, preserving prior pure shapes;
- effectful known-non-null operands rewrite to `drop(operand); i32.const 0`.

The implementation uses the existing `optimize_instructions_replace_with_drop_then_const_i32(...)` helper and adds a small `optimize_instructions_ref_is_null_operand(...)` helper for the ref-null test surface.

## TDD evidence

Red-first focused command:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref.eq null miss*'
```

Failed before implementation because the optimized function contained only `i32.const 0`, proving the imported call had been dropped.

After implementation, the same focused command passed:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref.eq null miss*'
```

Result: `Total tests: 1, passed: 1, failed: 0.`

## Focused and broader evidence

- Focused `*ref*` test:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref*'`
  - Passed: `Total tests: 39, passed: 39, failed: 0.`
- Focused `*optimize-instructions*` test:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'`
  - Passed: `Total tests: 169, passed: 169, failed: 0.`
- Broader validation:
  - `moon fmt` passed.
  - `moon test src/passes` passed: `Total tests: 2693, passed: 2693, failed: 0.`
  - `moon build --target native --release src/cmd` passed with existing warnings in `src/passes/pass_manager.mbt` and `src/passes/pass_manager_wbtest.mbt`.
  - `moon info` passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
  - `git diff --check` passed.
- Direct compare smoke:
  - Command:
    - `rm -rf .tmp/pass-fuzz-optimize-instructions-oi-i-effectful-ref-eq-null-8 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 8 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-i-effectful-ref-eq-null-8 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe`
  - Requested `8`, compared `8/8`.
  - Normalized matches: `0`.
  - Cleanup-normalized matches: `0`.
  - Raw mismatches: `8`.
  - Validation failures: `0`.
  - Property failures: `0`.
  - Generator failures: `0`.
  - Command failures: `0`.
  - Cache: wasm-smith `0` hits / `0` misses; Binaryen `8` hits / `0` misses; Binaryen failures `0` hits / `0` misses.
  - Agent classification: the raw mismatches are known scalar/default output-shape families from earlier OI slices, not new reference semantic failures. Grep of final failure artifacts found no `ref.*`, `call_ref`, or `return_call_ref` occurrences.
  - Larger direct compare attempts at counts `9`, `10`, `1000`, and `10000` timed out in this environment before writing `result.json`; the `8`-case lane is the captured compare evidence for this slice.

## Boundaries

This slice does not add:

- arbitrary effect preservation for every `ref.eq` impossible-equality proof;
- new equality proofs beyond the already-modeled known-non-null/null miss path;
- allocation-dropping constructor identity rewrites;
- descriptor/exactness/TNH/IIT-sensitive cast behavior;
- arbitrary subtype-lattice or indexed/defined heap reasoning;
- flow-sensitive nullable-local facts.

## Evidence captured

- Binaryen oracle:
  - `wasm-opt .tmp/oi-effectful-ref-eq-null-probe.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -`
  - Preserved `drop(call $effect)` before `i32.const 0`.
- Focused red/green test:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref.eq null miss*'`
  - Failed before implementation because the call was dropped.
  - Passed after implementation: `Total tests: 1, passed: 1, failed: 0.`
- Focused tests:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref*'`
  - Passed: `Total tests: 39, passed: 39, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'`
  - Passed: `Total tests: 169, passed: 169, failed: 0.`
- Broader validation:
  - `moon fmt` passed.
  - `moon test src/passes` passed: `Total tests: 2693, passed: 2693, failed: 0.`
  - `moon build --target native --release src/cmd` passed with existing warnings in `src/passes/pass_manager.mbt` and `src/passes/pass_manager_wbtest.mbt`.
  - `moon info` passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
  - `git diff --check` passed.
- Direct compare smoke:
  - `.tmp/pass-fuzz-optimize-instructions-oi-i-effectful-ref-eq-null-8` requested `8`, compared `8/8`, had `8` known scalar/default output-shape raw mismatches, and had `0` validation/property/generator/command failures. Grep found no `ref.*`, `call_ref`, or `return_call_ref` in final failure artifacts.
  - Larger count attempts timed out before writing `result.json`; see the focused evidence section above.

## Remaining work

`[O4Z-AUDIT-OI-I]` remains active for impossible equality beyond the covered subsets, broader definitely-successful and definitely-failed `ref.test` / `ref.cast` proofs, additional unreachable/drop-child and effect preservation outside the now-covered immediate-`ref.i31` known-miss and null-equality paths, and default-mode trap/effect negatives. `[O4Z-AUDIT-OI-J]` and later remain open.
