# 1437 - local-subtyping direct block-return validator boundary

Date: 2026-07-04

## Question

Can Starshine safely close the remaining `local-subtyping` direct block-return nondefaultable-local unreachable-tail family by matching Binaryen's non-null local declaration rewrite?

## Probe fixture

The refreshed fixture is the reduced direct block-return shape already tracked under `.tmp/ls-probes/block-return-before-write-outside-get.wat`:

```wat
(module
  (type $base (sub (struct)))
  (type $child (sub $base (struct)))
  (func $f (param $p (ref $child)) (local $l (ref null $base))
    (block
      (return)
      (local.set $l (local.get $p))
    )
    (drop (local.get $l))))
```

## Commands

- `wasm-opt --all-features --local-subtyping .tmp/ls-probes/block-return-before-write-outside-get.wat -S -o .tmp/ls-block-return-20260704/block-return-before-write-outside-get.binaryen.v130.wat`
- `wasm-tools validate --features all .tmp/ls-probes/block-return-before-write-outside-get.wat`
- `wasm-tools validate --features all .tmp/ls-block-return-20260704/block-return-before-write-outside-get.binaryen.v130.wat`
- `STARSHINE_PASSES=local-subtyping _build/native/release/build/cmd/cmd.exe .tmp/ls-probes/block-return-before-write-outside-get.wat --out .tmp/ls-block-return-20260704/block-return-before-write-outside-get.starshine.wasm`
- `wasm-tools validate --features all .tmp/ls-block-return-20260704/block-return-before-write-outside-get.starshine.wasm`

## Results

- The source fixture validates with `wasm-tools`.
- Binaryen v130 rewrites the body local from `(ref null $base)` to `(ref $child)`.
- `wasm-tools validate --features all` rejects the Binaryen v130 output with `uninitialized local: 1` at the post-block `local.get`.
- Starshine keeps the body local nullable child, emits a validating module, and therefore does not reproduce Binaryen's current invalid nondefaultable-local output for this shape.
- A new focused validator boundary test, `validate_module rejects direct block-return non-defaultable unreachable-tail local get`, locks Starshine's validation behavior for the exact invalid-output shape.

## Classification

This remains a precise validator/tooling boundary, not a Starshine win. Starshine is not claiming that nullable output is better than Binaryen's transform; it is refusing to emit a nondefaultable local declaration while both Starshine validation and `wasm-tools` reject the reduced Binaryen output.

## Reopening criteria

Reopen this LS family when one of these becomes true:

1. a reduced direct block-return non-null local output for this family validates under current `wasm-tools --features all` and Starshine validation;
2. Starshine validation intentionally adopts a spec-backed unreachable-tail nondefaultable-local proof that accepts this Binaryen shape;
3. Binaryen changes the output shape so the same semantic narrowing is represented with a validating repair, such as removing or rewriting the unreachable post-return local get;
4. a direct compare mismatch shows an LS-owned semantic consequence beyond this invalid-output boundary.

Until then, keep the LS pass's nullable fallback for direct block-return post-state and do not classify the residual as a measured Starshine win.
