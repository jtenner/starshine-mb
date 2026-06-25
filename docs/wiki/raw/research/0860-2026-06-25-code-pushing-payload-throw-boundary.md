# 0860 - code-pushing payload throw boundary

Date: 2026-06-25

## Question

Does the tag-based `throw` stationary boundary from `0857` still hold when the throw has a payload operand?

## Probe

Reduced local probe:

```wat
(module
  (tag $e (param i32))
  (func (param $p i32) (local $x i32)
    (block $exit
      i32.const 7
      local.set $x
      i32.const 42
      throw $e
      local.get $p
      br_if $exit
      local.get $x
      drop)))
```

Commands:

- `wasm-tools parse .tmp/cp-probes/throw-payload-before-brif.wat -o .tmp/cp-probes/throw-payload-before-brif.wasm` — passed.
- `wasm-tools validate --features all .tmp/cp-probes/throw-payload-before-brif.wasm` — passed.
- `wasm-opt --all-features .tmp/cp-probes/throw-payload-before-brif.wat --code-pushing -S -o -` — passed with local `wasm-opt version 130 (version_130)`.

## Binaryen result

Binaryen kept the pure `local.set $x (i32.const 7)` before the payload-bearing `throw $e (i32.const 42)`. This extends the tag-based `throw` stationary boundary from the plain no-payload probe in `0857`.

## Starshine coverage

Added focused boundary coverage in `src/passes/code_pushing_test.mbt`:

- `code-pushing boundary keeps SFA set before payload throw and br_if push point`

This is intentionally unsupported/Binaryen-stationary coverage. No movement implementation or GenValid profile leaf was added.

## Validation

- `moon test --target native src/passes/code_pushing_test.mbt --filter '*payload throw*'` — passed `1/1`.

## Impact

The EH stationary set is narrower and better sourced: Starshine now has focused coverage for both plain tag-based `throw` and payload-bearing tag-based `throw` before a later `br_if`, while `throw_ref` remains the source-backed positive movement case. Broader `rethrow`, native HOT `Try`, richer `try_table`, caught payload/reference forms, and other EH surfaces remain open.
