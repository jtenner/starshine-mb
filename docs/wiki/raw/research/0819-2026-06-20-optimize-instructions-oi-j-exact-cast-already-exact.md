# Optimize-instructions OI-J already-exact ref.cast cleanup

_Date:_ 2026-06-20
_Status:_ completed coverage sub-slice for `[O4Z-AUDIT-OI-J]`

## Question

Does Binaryen `version_130` `optimize-instructions` remove exact `ref.cast` checks when the operand static type is already exact on the same heap?

This follows the `0818` exactness boundary. That earlier slice showed an inexact same-heap local must keep `ref.cast (ref (exact $foo))`. This slice covers the positive already-exact side of the same guard: when the operand type is already `(ref (exact $foo))` or `(ref null (exact $foo))`, the exact descriptor check is redundant except for the nullable-to-non-null null trap.

## Binaryen oracle

Probe: `.tmp/oi-j-exact-already-exact-probe.wat`

Command:

```sh
wasm-opt .tmp/oi-j-exact-already-exact-probe.wat --enable-gc --enable-reference-types --enable-custom-descriptors -S -O --optimize-instructions -o -
```

Result: Binaryen `version_130` removed the redundant exact casts for already-exact operands:

- non-null `(ref (exact $foo))` to `(ref (exact $foo))` became `local.get`;
- nullable `(ref null (exact $foo))` to non-null `(ref (exact $foo))` became `ref.as_non_null(local.get)` to preserve the null trap;
- nullable `(ref null (exact $foo))` to nullable `(ref null (exact $foo))` became `local.get`.

The probe used `--enable-custom-descriptors`, matching the local Binaryen requirement observed in `0818` for exact cast text validation.

## Starshine coverage

Starshine already had the narrow exact-operand guard from `0818`: exact-target cast removal or `ref.as_non_null` conversion is allowed only when `optimize_instructions_ref_operand_has_exact_heap(...)` proves the operand result type is exact on the same heap.

This slice adds the direct-core public-pipeline test `optimize-instructions folds exact ref.cast on already exact locals` to lock the positive behavior. The test covers the same three oracle spellings: non-null exact to non-null exact, nullable exact to non-null exact, and nullable exact to nullable exact.

Red-first positive implementation evidence does not apply because this was coverage for behavior that the `0818` implementation already made possible. The focused test passed immediately.

## Evidence

- Binaryen oracle: `wasm-opt .tmp/oi-j-exact-already-exact-probe.wat --enable-gc --enable-reference-types --enable-custom-descriptors -S -O --optimize-instructions -o -` removed/converted the redundant exact casts as described above.
- Focused coverage: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*exact ref.cast*'` passed `2/2` after adding the already-exact coverage.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref.cast*'` passed `32/32`.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*ref*'` passed `68/68`.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'` passed `201/201`.
- `moon fmt` passed.
- `moon test src/passes` passed `2731/2731`.
- `moon build --target native --release src/cmd` passed / had no work to do.
- `moon info` passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
- Direct compare smoke:
  - `rm -rf .tmp/pass-fuzz-optimize-instructions-oi-j-exact-already-exact-1 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 1 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-j-exact-already-exact-1 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe`
  - requested `1`, compared `1/1`, normalized matches `0`, compare-normalized matches `0`, raw mismatches `1`, validation/property/generator/command failures `0`.
  - cache: wasm-smith `0` hits / `0` misses; Binaryen `1` hit / `0` misses; Binaryen failures `0` hits / `0` misses.
  - Agent classification: known scalar/default output-shape raw mismatch family from earlier OI slices. Grepping the failure artifacts found no `ref.cast`, `ref.test`, `ref.eq`, `ref.is_null`, `ref.as_non_null`, `call_ref`, or `return_call_ref`, so the smoke did not exercise this exact-cast coverage.

## Remaining work

This closes only the already-exact operand coverage sub-slice of `[O4Z-AUDIT-OI-J]`. Descriptor casts, TNH/IIT-only removals, success-only-if-null/non-null cases beyond the covered nullable exact cast, useful-type-info preservation, and custom-descriptor mode boundaries remain open. The broader `[O4Z-AUDIT-OI-G]`, `[O4Z-AUDIT-OI-H]`, `[O4Z-AUDIT-OI-I]`, `[O4Z-AUDIT-OI-J]`, and later slices are not complete.
