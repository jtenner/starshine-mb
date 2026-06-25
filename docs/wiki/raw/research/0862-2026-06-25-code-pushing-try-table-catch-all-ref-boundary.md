# 0862 - code-pushing try_table catch_all_ref boundary

Date: 2026-06-25

## Question

Does the reduced `try_table` stationary boundary from `0858` still hold for a richer reference-carrying `catch_all_ref` target?

## Probe

Reduced local probe:

```wat
(module
  (func (param $p i32) (local $x i32)
    (block $done
      (block $handler (result exnref)
        (block $exit
          i32.const 7
          local.set $x
          try_table (catch_all_ref $handler)
            i32.const 0
            drop
          end
          local.get $p
          br_if $exit
          local.get $x
          drop)
        ref.null exn)
      drop)))
```

Commands:

- `wasm-tools parse .tmp/cp-probes/try-table-catch-all-ref-before-brif.wat -o .tmp/cp-probes/try-table-catch-all-ref-before-brif.wasm` — passed.
- `wasm-tools validate --features all .tmp/cp-probes/try-table-catch-all-ref-before-brif.wasm` — passed.
- `wasm-opt --all-features .tmp/cp-probes/try-table-catch-all-ref-before-brif.wat --code-pushing -S -o -` — passed with local `wasm-opt version 130 (version_130)`.

## Binaryen result

Binaryen kept the pure `local.set $x (i32.const 7)` before the `try_table (catch_all_ref $handler)` root, then left the later `br_if` and suffix read unchanged. This extends the reduced `try_table` stationary boundary from `0858` to a reference-carrying `catch_all_ref` target.

## Starshine coverage

Added focused boundary coverage in `src/passes/code_pushing_test.mbt`:

- `code-pushing boundary keeps SFA set before catch_all_ref try_table and br_if push point`

This is intentionally unsupported/Binaryen-stationary coverage. No implementation or GenValid profile leaf changed because existing `HotOp::TryTable` segment barriers already preserve the shape.

## Validation

- `moon test --target native src/passes/code_pushing_test.mbt --filter '*catch_all_ref try_table*'` — passed `1/1`.

## Impact

The `try_table` boundary is now better sourced for both a reduced catch-all target and a reference-carrying `catch_all_ref` target. Broader native HOT `Try`, `catch_ref`, caught payload/reference forms outside this exact shape, and other EH surfaces remain open. Because no pass behavior changed, this slice does not supersede the post-`0861` final matrix refresh requirement.
