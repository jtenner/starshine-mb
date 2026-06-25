# Code-pushing disjoint global.get / global.set movement

Date: 2026-06-25

## Question

After the matching `global.get` / `global.set` boundary in `0876`, does Binaryen v130 still move a `global.get` candidate value when the intervening mutation writes a different global before a later `br_if` push point?

## Probe

Reduced local probe:

- `.tmp/cp-probes/global-get-candidate-across-other-global-set-before-brif.wat`

Shape:

```wat
(module
  (global $g0 (mut i32) (i32.const 1))
  (global $g1 (mut i32) (i32.const 2))
  (func (param i32) (local i32)
    (block $exit
      global.get $g0
      local.set 1
      i32.const 3
      global.set $g1
      local.get 0
      br_if $exit
      local.get 1
      drop)))
```

## Binaryen v130 result

Local `wasm-opt version 130 (version_130)` moved the `local.set (global.get $g0)` after the intervening `global.set $g1` and the later `br_if`, while preserving the matching-global boundary from `0876` as stationary.

This narrows the global-state rule: Binaryen distinguishes the written global for this reduced direct-root shape. A candidate `global.get` cannot cross a write to the same global, but it can cross a direct `global.set` to a different global before the later push point.

## Starshine change

Added red-first focused coverage in `src/passes/code_pushing_test.mbt`:

- `code-pushing moves global.get value past other global.set before br_if push point`

The test initially failed with Starshine keeping `global.get $g0; local.set` before `global.set $g1`. The implementation now allows `global.get` candidate values to cross a direct `GlobalSet` root only when the written global index differs from the read global index. The existing matching-global boundary test remains green.

## Validation

```sh
wasm-tools parse .tmp/cp-probes/global-get-candidate-across-other-global-set-before-brif.wat -o .tmp/cp-probes/global-get-candidate-across-other-global-set-before-brif.wasm
wasm-tools validate --features all .tmp/cp-probes/global-get-candidate-across-other-global-set-before-brif.wasm
wasm-opt --all-features .tmp/cp-probes/global-get-candidate-across-other-global-set-before-brif.wat --code-pushing -S -o -
moon test --target native src/passes/code_pushing_test.mbt --filter '*other global.set*'
moon test --target native src/passes/code_pushing_test.mbt --filter '*global.get value before global.set*'
```

Results: the probe parsed/validated, Binaryen moved the disjoint-global candidate, the new Starshine focused test passed `1/1` after the implementation, and the existing matching-global boundary test passed `1/1`.

## Conclusion

`[O4Z-AUDIT-CP]` should keep the global-read/mutation rule index-sensitive for direct global roots: allow `global.get G0` across `global.set G1` when `G0 != G1`, but keep `global.get G` before `global.set G`. This is a behavior change after `0861`, so final closeout still needs refreshed regular, wasm-smith, dedicated `code-pushing-all`, and broad named matrix lanes.
