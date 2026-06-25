# Code-pushing global read/mutation boundary

Date: 2026-06-25

## Question

After the pure-value movement slice across `global.set`, does Binaryen v130 also move a candidate value that reads the same global across an intervening `global.set` before a later `br_if` push point?

## Probe

Reduced local probe:

- `.tmp/cp-probes/global-get-candidate-across-global-set-before-brif.wat`

Shape:

```wat
(module
  (global $g (mut i32) (i32.const 9))
  (func (param $p i32) (local $tmp i32)
    (block $exit
      global.get $g
      local.set $tmp
      i32.const 11
      global.set $g
      local.get $p
      br_if $exit
      local.get $tmp
      drop)))
```

Commands:

```sh
wasm-tools parse .tmp/cp-probes/global-get-candidate-across-global-set-before-brif.wat -o .tmp/cp-probes/global-get-candidate-across-global-set-before-brif.wasm
wasm-tools validate --features all .tmp/cp-probes/global-get-candidate-across-global-set-before-brif.wasm
wasm-opt --all-features .tmp/cp-probes/global-get-candidate-across-global-set-before-brif.wat --code-pushing -S -o -
```

## Binaryen v130 result

Local `wasm-opt version 130 (version_130)` kept the `local.set` containing `global.get $g` before the intervening `global.set $g` and later `br_if`.

This is a Binaryen-stationary boundary: the positive pure-value movement across `global.set` does not generalize to candidate values that read global state which the crossed root mutates.

## Starshine coverage

Added focused boundary coverage in `src/passes/code_pushing_test.mbt`:

- `code-pushing boundary keeps global.get value before global.set and br_if push point`

The test is intentionally unsupported/Binaryen-stationary and asserts that Starshine does not mutate the shape.

## Validation

```sh
moon test --target native src/passes/code_pushing_test.mbt --filter '*global.get value before global.set*'
```

Result: `1/1` passed.

## Conclusion

`[O4Z-AUDIT-CP]` should continue to distinguish pure non-reading values from state-reading candidate values. A `global.get` candidate remains before a matching `global.set` mutation even when a later `br_if` would otherwise be a push point. Reopen only if future Binaryen probes move this shape, if Starshine's global effect model changes, or if generated compare exposes a mismatch in a narrower global read/write window.

This slice is characterization-only: no pass implementation or GenValid profile changed, and it does not refresh the required post-`0861` final matrix lanes.
