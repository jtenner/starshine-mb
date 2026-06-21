# `heap-store-optimization` descriptor old-field plus later-field call barrier

## Summary

Binaryen `version_130` keeps a later `struct.set` when a descriptor constructor has both an overwritten old-field call and a later constructor-field call. Folding the later call-valued store into the constructor would move it before the later field call, so the old-field side-effect preservation rule does not override the usual later-field effect barrier. Starshine already matched this behavior, so this was a coverage-only HSO-D/E slice.

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
        (call $helper (i32.const 10))
        (global.get $desc)))
    (struct.set $s 0
      (local.get $x)
      (call $helper (i32.const 1)))))
```

Command:

```sh
wasm-opt --all-features .tmp/hso-probe-desc-old-field-call-barrier.wat \
  --heap-store-optimization -S \
  -o .tmp/hso-probe-desc-old-field-call-barrier.opt.wat && \
grep -E "struct.set|struct.new_desc|call|drop|global.get|i32.const" \
  .tmp/hso-probe-desc-old-field-call-barrier.opt.wat
```

Observed result: Binaryen retained `struct.new_desc`, retained the later `struct.set`, retained the descriptor `global.get`, and retained all three helper calls. No old-field `drop` was introduced because the rewrite did not happen.

Interpretation: descriptor old-field side-effect preservation is conditional on the fold being otherwise legal. When a later constructor field has effects that must remain before the moved store value, Binaryen preserves the store instead of folding and preserving the old field under `drop`.

## Starshine coverage

Added focused test:

- `heap-store-optimization keeps descriptor old field call behind later field call barrier`

The test uses `hso_desc_call_test_run(...)` with a `struct.new_desc` whose field `0` and field `1` operands are both calls, followed by a call-valued `struct.set` to field `0`. It asserts that Starshine keeps `struct.set`, keeps `struct.new_desc`, keeps the descriptor `global.get`, preserves all visible constants, and does not introduce `drop`.

The new test passed on the first focused run, so this slice documents existing Binaryen parity. No implementation changed; no native rebuild or direct compare was required.

## Validation

- `moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt` — passed `243/243`.

## Reopening criteria

Reopen HSO-D/E if a descriptor/default-descriptor old-field preservation shape folds across an effectful later constructor field, deletes/reorders the overwritten old-field side effects, or otherwise disagrees with Binaryen `version_130` on the interaction between old-field preservation and later-field movement barriers.
