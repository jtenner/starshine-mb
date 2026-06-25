---
kind: research
status: supported
created: 2026-06-25
sources:
  - ./0822-2026-06-21-code-pushing-br-table-boundary.md
  - ../../../binaryen/passes/code-pushing/starshine-port-readiness-and-validation.md
  - ../../../../src/passes/code_pushing_test.mbt
---

# Code Pushing Value `br_table` Boundary

## Question

Does Binaryen v130 move a pure SFA `local.set` window across a value-carrying `br_table` to a result block, and should Starshine widen switch mutation for this shape?

## Binaryen probe

Local oracle: `wasm-opt version 130 (version_130)`.

Probe input: `.tmp/cp-br-table-value-probe.wat`.

```wat
(module
  (func $probe (param $idx i32) (result i32)
    (local $x i32)
    (block $exit (result i32)
      (local.set $x (i32.add (i32.const 40) (i32.const 2)))
      (br_table $exit $exit
        (i32.const 7)
        (local.get $idx)
      )
      (drop (local.get $x))
      (i32.const 9))))
```

Command:

```sh
wasm-opt --all-features --code-pushing -S .tmp/cp-br-table-value-probe.wat -o .tmp/cp-br-table-value-probe.opt.wat
```

Binaryen kept the pure `local.set` before the `br_table`. The output still contains the set, then `br_table $exit $exit` with the branch payload and selector, followed by the unreachable suffix drop/read.

## Starshine decision

No movement implementation landed. This is a deliberately narrow fail-closed boundary, extending the earlier simple no-branch-value `br_table` boundary from [`0822`](./0822-2026-06-21-code-pushing-br-table-boundary.md) to one value-carrying result-block shape. It does not prove all switch/`br_table` surfaces stationary, and it does not close broader switch mutation in `[O4Z-AUDIT-CP]`.

## Tests

Added focused boundary coverage in `src/passes/code_pushing_test.mbt`:

- `code-pushing boundary keeps SFA set before value br_table switch push point`

The test is intentionally named and commented as an unsupported/Binaryen-stationary boundary. It asserts that Starshine keeps the pure set before the value-carrying `br_table` in the local HOT shape.

## Validation

- `wasm-opt --version`: `wasm-opt version 130 (version_130)`.
- `wasm-opt --all-features --code-pushing -S .tmp/cp-br-table-value-probe.wat -o .tmp/cp-br-table-value-probe.opt.wat`: Binaryen kept the pure set before the value `br_table`.
- `moon test --target native src/passes/code_pushing_test.mbt --filter '*value br_table*'`: initially failed while calibrating the HOT root shape (`5 != 4`, then expected `BrTable` at the wrong index), then passed `1/1` after the test asserted the actual stationary HOT layout.
- `moon test --target native src/passes/code_pushing_test.mbt --filter '*br_table*'`: passed `3/3`.

No aggregate GenValid leaf or compare lane was added because this slice added a boundary test, not a positive movement family.

## Reopening criteria

Reopen this boundary if a future Binaryen source/lit refresh or reduced oracle probe shows a switch/`br_table` movement family Starshine can represent safely, if Starshine begins moving this value-`br_table` shape without a source-backed implementation, or if direct compare exposes non-normalized mismatches attributable to missing switch mutation rather than local cleanup/lowering debris.
