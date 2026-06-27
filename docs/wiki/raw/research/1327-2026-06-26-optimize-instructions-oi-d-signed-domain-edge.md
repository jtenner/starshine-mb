# OptimizeInstructions OI-D signed domain-edge compares

## Summary

Binaryen `version_130` `--optimize-instructions` folds side-effect-free signed relational compares at impossible signed-domain endpoints:

- `x <s INT_MIN` -> `i32.const 0`
- `x >=s INT_MIN` -> `i32.const 1`
- `x >s INT_MAX` -> `i32.const 0`
- `x <=s INT_MAX` -> `i32.const 1`

Starshine now matches that local/pure subset for i32 and i64 HOT compares.

## Oracle evidence

Probe: `.tmp/oi-signed-domain-probe.wat`.

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-signed-domain-probe.wat -o .tmp/oi-signed-domain-probe.out.wat
```

Result: passed. Binaryen folded local-backed i32/i64 signed endpoint comparisons to constants. A call-backed signed comparison was kept as a compare, so this slice deliberately does not preserve effects with `drop` the way unsigned-domain endpoint folding does.

## Starshine change

- Added `optimize_instructions_try_fold_signed_domain_edge_compare(...)` in `src/passes/optimize_instructions.mbt`.
- The fold requires the compared value to be side-effect-free and an exact signed min/max constant on the right side after existing relational canonicalization.
- Covered i32/i64 signed `lt_s`, `le_s`, `gt_s`, and `ge_s` endpoint results.
- Added red-first test coverage in `src/passes/optimize_instructions_test.mbt`: `optimize-instructions folds signed domain-edge compares`.

## Validation

- Red-first focused command before implementation: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*signed domain-edge*'` failed because `i32.lt_s` against signed min stayed a compare.
- After implementation: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*signed domain-edge*'` passed `2/2`.
- Pre-commit validation: `moon fmt` passed; focused `*signed domain-edge*` passed again; `moon test src/passes` passed `3532/3532`; `git diff --check` passed.

## Boundaries

This is a narrow OI-D scalar compare slice. It does not claim arbitrary signed range analysis, recursive signed max/min facts, effect-preserving signed endpoint folds, float/NaN-sensitive compare cleanup, or broader boolean algebra. Binaryen kept the call-backed signed endpoint probe, so Starshine intentionally keeps effectful signed endpoint compares for now.
