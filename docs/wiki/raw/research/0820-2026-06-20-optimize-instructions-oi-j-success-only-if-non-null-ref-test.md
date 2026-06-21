# Optimize-instructions OI-J success-only-if-non-null ref.test

_Date:_ 2026-06-20
_Status:_ completed implementation sub-slice for `[O4Z-AUDIT-OI-J]`

## Question

Does Binaryen `version_130` `optimize-instructions` simplify `ref.test (ref T)` when the operand is statically `(ref null T)` (or another nullable subtype of the non-null target), where the only remaining runtime question is whether the operand is null?

This belongs to `[O4Z-AUDIT-OI-J]` because it is a success-only-if-non-null cast/test boundary: the heap/type test is redundant, but null must still produce `0`. The safe replacement is `i32.eqz(ref.is_null(operand))`, not `i32.const 1`.

## Binaryen oracle

Probe: `.tmp/oi-j-success-only-if-non-null-ref-test-probe.wat`

Command:

```sh
wasm-opt .tmp/oi-j-success-only-if-non-null-ref-test-probe.wat --enable-gc --enable-reference-types -S -O --optimize-instructions -o -
```

Result: Binaryen rewrote all probed nullable-source / non-null-target `ref.test` forms to `i32.eqz(ref.is_null(...))`:

- `eqref` tested as `(ref eq)` became `i32.eqz(ref.is_null(local.get))`;
- `(ref null $s)` tested as `(ref $s)` became `i32.eqz(ref.is_null(local.get))`;
- an imported call returning `(ref null $s)` tested as `(ref $s)` became `i32.eqz(ref.is_null(call))`, preserving the call as the operand of the null check.

## Starshine change

Before this slice, Starshine only folded `ref.test` to constants when a known match/miss proof was enough. It did not cover the intermediate success-only-if-non-null shape, so nullable operands whose static heap already matched the non-null target kept `ref.test`.

This slice adds a narrow helper based on the operand result type and rewrites non-null-target `ref.test` to a null check when the operand is nullable and its heap is known to match the target. The replacement keeps the original operand under `ref.is_null`, so effectful operands such as imported calls remain evaluated in place and the null result is preserved.

The focused test `optimize-instructions rewrites nullable-source non-null-target ref.test to null check` covers nullable `eq`, nullable `struct`, and effectful-call nullable `struct` operands. Red-first evidence applied: the test initially failed because the first local case still contained `ref.test`; after the first local-only implementation, the effectful call case still failed; after switching to result-type-based matching, all covered forms passed.

## Evidence

- Binaryen oracle: `wasm-opt .tmp/oi-j-success-only-if-non-null-ref-test-probe.wat --enable-gc --enable-reference-types -S -O --optimize-instructions -o -` rewrote the probed forms to `i32.eqz(ref.is_null(...))`.
- Red-first focused test: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*nullable-source non-null-target ref.test*'` failed before implementation because `ref.test` remained.
- Intermediate focused test: the same filter still failed for the effectful-call case after a local-only helper, proving the result-type based operand check was needed.
- After implementation, `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*nullable-source non-null-target ref.test*'` passed `2/2`.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref.test*'` passed `26/26`.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref*'` passed `69/69`.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'` passed `202/202`.
- `moon fmt` passed.
- `moon test src/passes` passed `2732/2732`.
- `moon build --target native --release src/cmd` passed with existing unused-function warnings in pass-manager test/support helpers.
- `moon info` passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
- `git diff --check && git diff --cached --check` passed.
- Direct compare smoke:
  - `rm -rf .tmp/pass-fuzz-optimize-instructions-oi-j-success-only-if-non-null-ref-test-1 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 1 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-j-success-only-if-non-null-ref-test-1 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe`
  - requested `1`, compared `1/1`, normalized matches `0`, compare-normalized matches `0`, raw mismatches `1`, validation/property/generator/command failures `0`.
  - cache: wasm-smith `0` hits / `0` misses; Binaryen `1` hit / `0` misses; Binaryen failures `0` hits / `0` misses.
  - Agent classification: known scalar/default output-shape raw mismatch family from earlier OI slices. Grepping the failure artifacts found no `ref.cast`, `ref.test`, `ref.eq`, `ref.is_null`, `ref.as_non_null`, `call_ref`, or `return_call_ref`, so the smoke did not exercise this success-only-if-non-null ref.test slice.

## Remaining work

This closes only the success-only-if-non-null `ref.test` sub-slice of `[O4Z-AUDIT-OI-J]`. Descriptor casts, TNH/IIT-only removals, useful-type-info preservation, custom-descriptor mode boundaries, and additional success-only-if-null/non-null cast/test shapes remain open. The broader `[O4Z-AUDIT-OI-G]`, `[O4Z-AUDIT-OI-H]`, `[O4Z-AUDIT-OI-I]`, `[O4Z-AUDIT-OI-J]`, and later slices are not complete.
