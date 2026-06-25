# Code-pushing try_table multi-catch boundary

Date: 2026-06-25

## Question

Does Binaryen v130 move a pure SFA `local.set` across a `try_table` with more than one catch clause before a later `br_if` push point?

This follows the catch-all, catch-all-ref, tag-payload catch, and catch-ref stationary probes in `0858`, `0862`, and `0863`.

## Probe

Local toolchain:

- `wasm-opt --version`: `wasm-opt version 130 (version_130)`
- Validation used `wasm-tools validate --features all`.

Probe path: `.tmp/cp-probes/try-table-multi-catch-before-brif.wat`.

Shape:

```wat
(module
  (tag $e)
  (func (param i32) (local i32)
    (block $handler
      (block $exit
        i32.const 7
        local.set 1
        try_table (catch $e $handler) (catch_all $handler)
          i32.const 0
          drop
        end
        local.get 0
        br_if $exit
        local.get 1
        drop))))
```

Commands:

- `wasm-tools parse .tmp/cp-probes/try-table-multi-catch-before-brif.wat -o .tmp/cp-probes/try-table-multi-catch-before-brif.wasm`
- `wasm-tools validate --features all .tmp/cp-probes/try-table-multi-catch-before-brif.wasm`
- `wasm-opt --all-features .tmp/cp-probes/try-table-multi-catch-before-brif.wat --code-pushing -S -o -`

Finding: Binaryen kept the pure `local.set 1 (i32.const 7)` before the `try_table` and later `br_if`.

## Starshine coverage

Added intentionally unsupported/Binaryen-stationary focused coverage in `src/passes/code_pushing_test.mbt`:

- `code-pushing boundary keeps SFA set before multi-catch try_table and br_if push point`

The existing `HotOp::TryTable` segment-order barrier already preserved this shape, so this slice did not change `src/passes/code_pushing.mbt` or GenValid profiles.

## Validation

- `moon test --target native src/passes/code_pushing_test.mbt --filter '*multi-catch try_table*'` passed `1/1`.

## Classification

Agent classification: narrow Binaryen-stationary EH boundary. Starshine may keep this reduced multi-catch `try_table` form as a segment-order barrier for `[O4Z-AUDIT-CP]` unless a future probe shows Binaryen-positive movement for a narrower subshape or generated compare exposes a semantic mismatch.

## Follow-ups

- This is characterization/boundary coverage only. It does not refresh the post-`0861` final closeout matrix.
- Broader native HOT `Try`, richer mixed-arity `try_table` combinations, and legacy try surfaces remain open.
