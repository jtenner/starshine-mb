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

# Optimize-instructions OI-D nonnegative signed constant relational boundary

## Question

Narrow the signed relational constant-pair boundary after the negative same-sign slice. Binaryen `version_130` has mixed behavior for signed relational constants, so this slice checks a same-nonnegative subset without generalizing signed relational folding.

## Binaryen oracle

Probe file: `.tmp/oi-d-nonneg-signed-rel-probe.wat`.

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-d-nonneg-signed-rel-probe.wat -o -
```

Observed behavior:

- `i32.lt_s 3 7` folded to `i32.const 1`.
- `i32.gt_s 9 2` canonicalized to `i32.gt_u 9 2` rather than folding.
- `i64.le_s 4 8` folded to `i32.const 1`.
- `i64.ge_s 8 4` canonicalized to `i64.ge_u 8 4` rather than folding.

This is coverage/status evidence only. It confirms the nonnegative signed-constant subset is mixed fold/canonicalize behavior, not a license to fold all signed relational constant pairs.

## Starshine coverage

Added focused test:

- `optimize-instructions tracks nonnegative signed constant relational compares narrowly`

The test records Starshine's current behavior for the four probed shapes: fold for `lt_s` / `le_s`, unsigned spelling for `gt_s` / `ge_s`. The first draft expected every probed nonnegative pair to fold and failed on the canonicalized `gt_s` shape; the final test intentionally matches the mixed oracle boundary.

## Validation

- `wasm-opt --all-features -S --optimize-instructions .tmp/oi-d-nonneg-signed-rel-probe.wat -o -` passed and produced the mixed fold/canonicalize oracle above.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*nonnegative signed constant relational*'` passed `1/1` after correcting the test to the mixed boundary.

## Remaining work

Signed relational constant-pair parity remains intentionally narrow. Future slices should use fresh Binaryen probes before adding folds or canonicalization for nearby non-zero signed pairs.
