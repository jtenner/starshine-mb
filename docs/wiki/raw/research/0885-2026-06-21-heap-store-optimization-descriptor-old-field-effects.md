# `heap-store-optimization` descriptor old-field effect preservation

## Summary

Binaryen `version_130` folds a call-valued `struct.set` into a fresh `struct.new_desc` when the replaced old field value was itself a call, and preserves that old-field call by wrapping it in `drop`. Starshine already matched this descriptor old-field side-effect behavior, so this was a coverage-only HSO-D slice.

## Binaryen probe

Local oracle: `wasm-opt version 130 (version_130)`.

Probe shape:

```wat
(module
  (rec
    (type $s (descriptor $d) (struct (field (mut i32)) (field (mut i32))))
    (type $d (describes $s) (struct)))
  (type $helper (func (param i32) (result i32)))
  (import "env" "desc" (global $desc (ref (exact $d))))
  (import "env" "helper" (func $helper (type $helper)))
  (func $test (local $x (ref null $s))
    (local.set $x
      (struct.new_desc $s
        (call $helper (i32.const 0))
        (i32.const 10)
        (global.get $desc)))
    (struct.set $s 0
      (local.get $x)
      (call $helper (i32.const 1)))))
```

Command:

```sh
wasm-opt --version && \
wasm-opt --all-features .tmp/hso-probe-desc-old-field-call.wat \
  --heap-store-optimization -S \
  -o .tmp/hso-probe-desc-old-field-call.opt.wat && \
grep -E "struct.set|struct.new_desc|call|drop|global.get|i32.const" \
  .tmp/hso-probe-desc-old-field-call.opt.wat
```

Observed result: Binaryen removed the later `struct.set`, kept `struct.new_desc`, moved the replacement `call $helper (i32.const 1)` into field `0`, kept field `1`, kept the descriptor `global.get`, and preserved the old field-0 `call $helper (i32.const 0)` under `drop`.

Interpretation: descriptor constructors share the old-field side-effect preservation rule already covered for plain constructors. Replacing a constructor field does not permit deleting the old operand's side effects.

## Starshine coverage

Added focused test:

- `heap-store-optimization preserves descriptor old field call effects when folding`

The test uses `hso_desc_call_test_run(...)` with a `struct.new_desc` whose replaced field is a call and whose later `struct.set` value is also a call. It asserts that Starshine removes `struct.set`, retains `struct.new_desc`, keeps both calls/consts, and preserves the old-field call via `drop`.

The new test passed on the first focused run, so this slice documents existing Binaryen parity. No implementation changed; no native rebuild or direct compare was required.

## Validation

- `moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt` — passed `242/242`.

## Reopening criteria

Reopen HSO-D old-field preservation if a descriptor/default-descriptor constructor shape deletes or reorders an overwritten old-field side effect, or if a broader old-field combination involving descriptor operands exposes a mismatch with Binaryen's `version_130` behavior.
