# Optimize Instructions OI-F Identical Compare Local/Local Select Arms

Date: 2026-06-26

## Scope

This slice extends Starshine's narrow OI-F identical-pure-`select` arm matcher from direct arithmetic/bitwise/shift/rotate local/local shells to direct integer compare local/local shells.

Covered shape:

```wat
(select
  (i32.eq (local.get 0) (local.get 1))
  (i32.eq (local.get 0) (local.get 1))
  (local.get 2))
```

and the analogous same-instruction/same-ordered-local `i32` / `i64` compare operators:

- `eq`
- `ne`
- `lt_s`
- `lt_u`
- `gt_s`
- `gt_u`
- `le_s`
- `le_u`
- `ge_s`
- `ge_u`

The condition remains required to be side-effect-free by the existing identical-arm fold.

## Binaryen oracle

Probe: `.tmp/oi-select-identical-compare-local-local-arms-probe.wat`

Command:

```sh
wasm-opt --all-features -S --optimize-instructions \
  .tmp/oi-select-identical-compare-local-local-arms-probe.wat \
  -o .tmp/oi-select-identical-compare-local-local-arms-probe.out.wat
```

Result:

- command passed with status `0`
- `select-count=0`
- compare count in the output was `20`, matching the twenty probed direct `i32`/`i64` compare functions

This shows Binaryen folds the identical `select` shell away and keeps one compare payload.

## Starshine implementation

Files:

- `src/passes/optimize_instructions.mbt`
- `src/passes/optimize_instructions_test.mbt`

Implementation adds two narrow predicates:

- `optimize_instructions_i32_compare_local_local_payloads_are_identical_pure`
- `optimize_instructions_i64_compare_local_local_payloads_are_identical_pure`

Both reuse the existing ordered `local.get` / `local.get` payload matcher and are wired into the existing identical-pure-select-arm predicate.

Focused test coverage extends `optimize-instructions folds select with identical pure local-local binary arms` with representative `i32.eq` and `i64.ge_u` local/local shells.

## Red-first and validation evidence

Red-first focused test before implementation:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt \
  --filter '*local-local binary arms*'
```

Result before implementation: failed `0/1` on the new `i32.eq` case because Starshine kept the `select`.

After implementation:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt \
  --filter '*local-local binary arms*'
```

Result after implementation: passed `1/1`.

Full slice validation is recorded in the commit body.

## Boundaries

This slice deliberately does not claim:

- commuted operand equivalence
- arbitrary structural expression equality
- algebraic equality
- float compare local/local equality
- division/remainder local/local shells
- effectful or trapping payload folding
- effectful or trapping condition folding

Those remain separate OI-F or adjacent parity work and need fresh oracle evidence before implementation.
