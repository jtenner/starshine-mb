# Optimize-instructions OI-I effectful impossible ref.eq preservation

Date: 2026-06-20

## Summary

Thirty-fifth `[O4Z-AUDIT-OI-I]` reference sub-slice.

This slice fixes effect preservation for the locally represented impossible `ref.eq` proof where an immediate `ref.i31(...)` value is compared with a local whose declared heap cannot be `i31`. Before this slice, the impossible-equality branch rewrote the whole equality to `i32.const 0` without checking whether either proven-dead operand carried effects. That was fine for pure local and constant operands, but wrong for an imported call wrapped by `ref.i31`.

The now-locked represented shape is:

```wat
call $effect
ref.i31
local.get 0 ;; (ref null $s)
ref.eq
;; => drop(ref.i31(call $effect)); i32.const 0
```

## Binaryen oracle

Probe file: `.tmp/oi-effectful-ref-eq-impossible-i31-struct-probe.wat`

Command:

```sh
wasm-opt .tmp/oi-effectful-ref-eq-impossible-i31-struct-probe.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -
```

Observed output preserved the imported call as `drop(call $effect)` before `i32.const 0` for imported-call `ref.i31` impossible equality against a struct local. The probe also showed Binaryen canonicalizing the two export-equivalent operand orderings to the same body.

## Starshine change

Updated `src/passes/optimize_instructions.mbt` so the impossible `ref.eq` branch uses a helper that checks operand effect masks before replacing the equality with `i32.const 0`:

- pure impossible equality operands still fold directly to `i32.const 0`, preserving prior local/constant shapes;
- a single effectful impossible operand rewrites to `drop(operand); i32.const 0`;
- if a future represented impossible-equality proof has effects on both operands, the helper preserves left-to-right evaluation by dropping the left operand, then the right operand, then producing `i32.const 0`.

## TDD evidence

Focused command used during development:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*impossible equality*'
```

The initial focused test exposed the effect/localization boundary for impossible equality. After implementation and scoping the fixture to the represented imported-call `ref.i31` shape, the focused command passed:

Result: `Total tests: 3, passed: 3, failed: 0.`

## Focused and broader evidence

- Focused `*ref*` test:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref*'`
  - Passed: `Total tests: 42, passed: 42, failed: 0.`
- Focused `*optimize-instructions*` test:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'`
  - Passed: `Total tests: 172, passed: 172, failed: 0.`

- Broader validation:
  - `moon fmt` passed.
  - `moon test src/passes` passed: `Total tests: 2696, passed: 2696, failed: 0.`
  - `moon build --target native --release src/cmd` passed with existing warnings in `src/passes/pass_manager.mbt` and `src/passes/pass_manager_wbtest.mbt`.
  - `moon info` passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
  - `git diff --check` and `git diff --cached --check` passed.
- Direct compare smoke:
  - Completed command:
    - `rm -rf .tmp/pass-fuzz-optimize-instructions-oi-i-effectful-impossible-ref-eq-1 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 1 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-i-effectful-impossible-ref-eq-1 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe`
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

- arbitrary effect preservation for every reference fold beyond the represented impossible `ref.eq` branch;
- new impossible-equality proofs beyond the already-modeled `i31`-versus-cannot-be-`i31` and local struct/array disjointness paths;
- a WAT stack-localization fix for every operand ordering not currently represented by this branch;
- descriptor/exactness/TNH/IIT-sensitive cast behavior;
- arbitrary subtype-lattice or indexed/defined heap reasoning;
- flow-sensitive nullable-local facts.

## Evidence captured

- Binaryen oracle:
  - `wasm-opt .tmp/oi-effectful-ref-eq-impossible-i31-struct-probe.wat --enable-reference-types --enable-gc -S -O --optimize-instructions -o -`
  - Preserved `drop(call $effect)` before `i32.const 0` for imported-call `ref.i31` impossible equality against a struct local.
- Focused tests:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*impossible equality*'`
  - Passed after implementation: `Total tests: 3, passed: 3, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref*'`
  - Passed: `Total tests: 42, passed: 42, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'`
  - Passed: `Total tests: 172, passed: 172, failed: 0.`
- Broader validation:
  - `moon fmt` passed.
  - `moon test src/passes` passed: `Total tests: 2696, passed: 2696, failed: 0.`
  - `moon build --target native --release src/cmd` passed with existing warnings in `src/passes/pass_manager.mbt` and `src/passes/pass_manager_wbtest.mbt`.
  - `moon info` passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
  - `git diff --check` and `git diff --cached --check` passed.
- Direct compare smoke:
  - `.tmp/pass-fuzz-optimize-instructions-oi-i-effectful-impossible-ref-eq-1` requested `1`, compared `1/1`, had `1` known scalar/default output-shape raw mismatch, and had `0` validation/property/generator/command failures. Grep found no `ref.*`, `call_ref`, or `return_call_ref` in final compare artifacts.

## Remaining work

`[O4Z-AUDIT-OI-I]` remains active for impossible equality beyond the covered subsets, broader definitely-successful and definitely-failed `ref.test` / `ref.cast` proofs, additional unreachable/drop-child and effect preservation outside the now-covered immediate-`ref.i31` known-miss, null-equality, `ref.is_null`, successful `ref.test`, and represented impossible `ref.eq` paths, and default-mode trap/effect negatives. `[O4Z-AUDIT-OI-J]` and later remain open.
