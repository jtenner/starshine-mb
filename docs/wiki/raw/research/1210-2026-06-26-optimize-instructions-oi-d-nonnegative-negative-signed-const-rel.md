---
kind: research
status: supported
created: 2026-06-26
sources:
  - ../../binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md
  - ../../../../src/passes/optimize_instructions_test.mbt
  - ../../../../src/passes/optimize_instructions.mbt
related:
  - ../../binaryen/passes/optimize-instructions/index.md
  - ../../binaryen/passes/optimize-instructions/starshine-strategy.md
---

# Optimize-instructions OI-D nonnegative-negative signed constant relational coverage

## Question

Narrow the mixed signed relational constant-pair surface without generalizing to every signed constant pair. This slice probes the sign-disjoint direction where the left operand is nonnegative and the right operand is negative.

## Binaryen oracle

Probe file: `.tmp/oi-d-signed-rel-nonneg-neg-probe.wat`.

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-d-signed-rel-nonneg-neg-probe.wat -o -
```

Observed behavior:

- `i32.lt_s 1 -2` and `i32.le_s 1 -2` fold to `i32.const 0`.
- `i32.gt_s 1 -2` and `i32.ge_s 1 -2` fold to `i32.const 1`.
- The same i64 shapes fold to the same i32 boolean constants.

This is coverage/status evidence only. The opposite negative-vs-nonnegative direction remains mixed in Binaryen and should continue to use the existing boundary coverage unless a fresh oracle probe supports a narrower implementation.

## Starshine coverage

Added focused test:

- `optimize-instructions folds signed constant relational nonnegative-negative pairs`

Starshine already matched this exact sign-disjoint subset through existing compare canonicalization and constant compare machinery, so this was not a red-first implementation slice.

## Validation

- `wasm-opt --all-features -S --optimize-instructions .tmp/oi-d-signed-rel-nonneg-neg-probe.wat -o -` passed and produced the folded constants above.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*signed constant relational nonnegative-negative*'` passed `1/1`.

## Remaining work

Signed relational constant-pair parity remains intentionally narrow. Future work should continue probing nearby signed constant pairs before broadening folds or canonicalization.
