---
kind: research
status: supported
created: 2026-06-25
sources:
  - ./0843-2026-06-25-code-pushing-value-br-table-boundary.md
  - ./0822-2026-06-21-code-pushing-br-table-boundary.md
  - ../../../binaryen/passes/code-pushing/starshine-port-readiness-and-validation.md
  - ../../../../src/passes/code_pushing_test.mbt
---

# Code Pushing Multi-Label `br_table` Boundary

## Question

Does Binaryen v130 move a pure SFA `local.set` window across a multi-target `br_table` where one target falls through to a later suffix read and another exits the enclosing block?

## Binaryen probe

Local oracle: `wasm-opt version 130 (version_130)`.

Probe input: `.tmp/o4z-audit-cp-ww/br-table-multilabel.wat`.

```wat
(module
  (func (param i32) (local i32)
    (block $outer
      (block $inner
        i32.const 7
        local.set 1
        local.get 0
        br_table $inner $outer $inner
        local.get 1
        drop)
      local.get 1
      drop)))
```

Commands:

```sh
wasm-tools parse .tmp/o4z-audit-cp-ww/br-table-multilabel.wat -o .tmp/o4z-audit-cp-ww/br-table-multilabel.wasm
wasm-tools validate --features all .tmp/o4z-audit-cp-ww/br-table-multilabel.wasm
wasm-opt --version
wasm-opt --all-features .tmp/o4z-audit-cp-ww/br-table-multilabel.wat --code-pushing -S -o .tmp/o4z-audit-cp-ww/br-table-multilabel.opt.wat
```

Binaryen accepted and validated the probe, then kept the pure `local.set` before the multi-label `br_table`. The optimized WAT still has `local.set $1 (i32.const 7)` immediately before `br_table $inner $outer $inner`; the later `drop (local.get $1)` suffix remains after the inner block target path.

## Starshine decision

No mutation landed. This is a narrow fail-closed switch boundary, extending the already protected simple no-branch-value and value-carrying `br_table` boundaries to one multi-target control shape. It does not prove all switch/`br_table` forms stationary, and it does not close broader switch work under `[O4Z-AUDIT-CP]`.

## Tests

Added focused boundary coverage in `src/passes/code_pushing_test.mbt`:

- `code-pushing boundary keeps SFA set before multi-label br_table switch push point`

The test is explicitly commented as an intentionally unsupported/Binaryen-stationary boundary. It asserts that the local HOT pass leaves the SFA set before the inner-block `br_table`, with both the inner unreachable suffix drop and outer suffix drop still represented after the switch path.

## Validation

- `wasm-tools parse .tmp/o4z-audit-cp-ww/br-table-multilabel.wat -o .tmp/o4z-audit-cp-ww/br-table-multilabel.wasm`: passed.
- `wasm-tools validate --features all .tmp/o4z-audit-cp-ww/br-table-multilabel.wasm`: passed.
- `wasm-opt --version`: `wasm-opt version 130 (version_130)`.
- `wasm-opt --all-features .tmp/o4z-audit-cp-ww/br-table-multilabel.wat --code-pushing -S -o .tmp/o4z-audit-cp-ww/br-table-multilabel.opt.wat`: passed; Binaryen kept the pure set before the multi-label `br_table`.
- `moon test --target native src/passes/code_pushing_test.mbt --filter '*multi-label br_table*'`: passed `1/1`.

No GenValid leaf or compare lane was added because this slice added a stationary boundary, not a positive movement family.

## Reopening criteria

Reopen this boundary if a future Binaryen source/lit refresh or reduced oracle probe shows a multi-target switch movement family, if Starshine starts moving this shape without source-backed proof, if HOT/WAT lowering gains a broader switch representation that exposes a different Binaryen-positive shape, or if direct compare exposes switch-attributable semantic or unnormalized output mismatches rather than documented local cleanup debris.
