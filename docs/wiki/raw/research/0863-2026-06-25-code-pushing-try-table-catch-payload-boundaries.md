# Code-pushing try_table catch payload boundaries

Date: 2026-06-25

## Question

Does Binaryen v130 move a pure single-first-assignment `local.set` across richer `try_table` handler forms before a later `br_if` push point?

This extends the earlier reduced `catch_all` (`0858`) and `catch_all_ref` (`0862`) stationary `try_table` probes with tag-payload `catch` and payload-plus-reference `catch_ref` handlers.

## Probes

Local toolchain:

- `wasm-opt --version`: `wasm-opt version 130 (version_130)`
- Validation used `wasm-tools validate --features all`.

### `try_table (catch $e $handler)`

Probe path: `.tmp/cp-probes/try-table-catch-payload-before-brif.wat`.

Shape:

```wat
(module
  (tag $e (param i32))
  (func (param i32) (local i32)
    (block $done
      (block $handler (result i32)
        (block $exit
          i32.const 7
          local.set 1
          try_table (catch $e $handler)
            i32.const 0
            drop
          end
          local.get 0
          br_if $exit
          local.get 1
          drop)
        i32.const 0)
      drop)))
```

Commands:

- `wasm-tools parse .tmp/cp-probes/try-table-catch-payload-before-brif.wat -o .tmp/cp-probes/try-table-catch-payload-before-brif.wasm`
- `wasm-tools validate --features all .tmp/cp-probes/try-table-catch-payload-before-brif.wasm`
- `wasm-opt --all-features .tmp/cp-probes/try-table-catch-payload-before-brif.wat --code-pushing -S -o -`

Finding: Binaryen kept the pure `local.set 1 (i32.const 7)` before the `try_table` and later `br_if`.

### `try_table (catch_ref $e $handler)`

Probe path: `.tmp/cp-probes/try-table-catch-ref-before-brif.wat`.

Shape:

```wat
(module
  (tag $e (param i32))
  (func (param i32) (local i32)
    (block $done
      (block $handler (result i32 exnref)
        (block $exit
          i32.const 7
          local.set 1
          try_table (catch_ref $e $handler)
            i32.const 0
            drop
          end
          local.get 0
          br_if $exit
          local.get 1
          drop)
        i32.const 0
        ref.null exn)
      drop
      drop)))
```

Commands:

- `wasm-tools parse .tmp/cp-probes/try-table-catch-ref-before-brif.wat -o .tmp/cp-probes/try-table-catch-ref-before-brif.wasm`
- `wasm-tools validate --features all .tmp/cp-probes/try-table-catch-ref-before-brif.wasm`
- `wasm-opt --all-features .tmp/cp-probes/try-table-catch-ref-before-brif.wat --code-pushing -S -o -`

Finding: Binaryen kept the pure `local.set 1 (i32.const 7)` before the `try_table` and later `br_if`. Binaryen's printer rewrote the multivalue result through tuple scratch locals, but the code-pushing-relevant root order stayed stationary.

## Starshine coverage

Added intentionally unsupported/Binaryen-stationary focused tests in `src/passes/code_pushing_test.mbt`:

- `code-pushing boundary keeps SFA set before payload catch try_table and br_if push point`
- `code-pushing boundary keeps SFA set before catch_ref try_table and br_if push point`

The existing `HotOp::TryTable` segment-order barrier already preserved both shapes, so this slice did not change `src/passes/code_pushing.mbt` or GenValid profiles.

## Validation

- `moon test --target native src/passes/code_pushing_test.mbt --filter '*payload catch try_table*'` passed `1/1`.
- `moon test --target native src/passes/code_pushing_test.mbt --filter '*catch_ref try_table*'` passed `1/1` after adjusting the expected HOT tuple/result wrapper shape.

## Classification

Agent classification: narrow Binaryen-stationary EH boundary. Starshine may keep these `try_table` handler forms as segment-order barriers for `[O4Z-AUDIT-CP]` unless a future probe shows Binaryen-positive movement for a narrower subshape or a generator compare exposes a semantic mismatch.

## Follow-ups

- This is characterization/boundary coverage only. It does not refresh the post-`0861` final closeout matrix.
- Broader native HOT `Try`, richer `try_table` combinations, caught reference payload variants beyond this reduced `catch_ref`, and legacy try/catch surfaces remain open.
