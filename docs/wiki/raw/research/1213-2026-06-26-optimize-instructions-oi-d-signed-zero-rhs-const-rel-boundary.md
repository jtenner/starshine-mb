---
kind: research
status: supported
created: 2026-06-26
sources:
  - ../../binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md
  - ../../../../src/passes/optimize_instructions_test.mbt
related:
  - ../../binaryen/passes/optimize-instructions/index.md
  - ../../binaryen/passes/optimize-instructions/starshine-strategy.md
---

# Optimize-instructions OI-D signed zero-rhs constant relational boundary

## Question

After covering signed relational constant folds whose left operand is literal zero, how does Binaryen handle the adjacent right-operand-zero signed relational constants, and should Starshine generalize the signed constant fold surface?

## Binaryen oracle

Probe file: `.tmp/oi-d-signed-rel-zero-rhs-probe.wat`.

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-d-signed-rel-zero-rhs-probe.wat -o -
```

Observed behavior:

- Binaryen keeps negative-vs-zero signed relational comparisons such as `i32.lt_s(i32.const -2, i32.const 0)`, `i32.ge_s(i32.const -2, i32.const 0)`, and the probed i64 sibling in signed spelling.
- Binaryen canonicalizes positive-vs-zero `gt_s` / `le_s` forms to unsigned spellings such as `i32.gt_u` / `i32.le_u` and the probed `i64.gt_u` sibling.
- Binaryen does not fold the probed zero-rhs shapes to `i32.const` booleans.

## Starshine coverage

Added focused boundary/status test:

- `optimize-instructions keeps signed zero-rhs constant relational boundary`

The test asserts Starshine keeps the probed negative-vs-zero signed spellings and canonicalizes the positive-vs-zero `gt`/`le` forms to unsigned comparisons, matching the observed Binaryen output shape.

## Classification

Boundary/status slice, not parity implementation. This guards against overgeneralizing the existing unsigned relational constant fold and the signed zero-lhs constant fold to all signed constant relational pairs. The signed constant relational surface remains mixed and should continue to require fresh oracle probes before widening.

## Validation

- `wasm-opt --all-features -S --optimize-instructions .tmp/oi-d-signed-rel-zero-rhs-probe.wat -o -` passed and showed the mixed keep/canonicalize behavior above.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*signed zero-rhs constant relational boundary*'` passed `1/1`.

## Remaining work

OI-D still lacks a broad signed relational constant folding contract. Future work should either implement a source-backed narrow subfamily with red-first tests or preserve each mixed Binaryen boundary with fresh oracle evidence.
