# Optimize-instructions OI-D negative signed constant relational boundary

Date: 2026-06-26

## Scope

Boundary/status-only OI-D slice for same-sign negative signed relational constant pairs.

This note narrows the existing signed relational constant-pair boundary. It does not implement a new transform and must not be generalized into full signed relational constant folding.

## Binaryen oracle

Probe: `.tmp/oi-d-negative-signed-const-rel-probe.wat`

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-d-negative-signed-const-rel-probe.wat -o -
```

Observed Binaryen `version_130` behavior:

- keeps `i32.lt_s (i32.const -7) (i32.const -3)`
- keeps `i32.ge_s (i32.const -5) (i32.const -4)`
- keeps `i64.gt_s (i64.const -2) (i64.const -9)`
- keeps `i64.le_s (i64.const -2) (i64.const -9)`

Nearby signed relational constant-pair behavior remains mixed: other slices document zero-lhs folds, zero-compare canonicalization for selected sign-disjoint pairs, nonnegative signed-to-unsigned spelling, and kept forms. This note only covers the negative same-sign keep-spelling probes above.

## Starshine coverage

Added focused test:

- `optimize-instructions keeps negative signed constant relational compares`

The test asserts that Starshine keeps the four probed negative signed relational pairs as comparisons with their signed instruction spelling. This is coverage/status evidence for an existing match and a guard against accidentally widening the unsigned constant relational fold to all signed relational constants.

## Validation

- `wasm-opt --all-features -S --optimize-instructions .tmp/oi-d-negative-signed-const-rel-probe.wat -o -` — passed and kept the probed signed comparisons.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*negative signed constant relational*'` — passed `1/1`.

Full slice validation is recorded in the commit body.

## Status

OI-D signed relational constant-pair behavior remains deliberately narrow. This slice adds boundary coverage only; broad signed relational constant folding remains open unless a future source-backed subfamily proves Binaryen folds it consistently.
