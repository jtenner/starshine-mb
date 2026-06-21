# `heap-store-optimization` default descriptor double-store Starshine win

## Summary

Binaryen `version_130` folds only the first store in a two-store `struct.new_default_desc` chain when both stored values are calls. Starshine folds both stores into the materialized `struct.new_desc` while preserving the helper-call order and the pure descriptor `global.get`, so this slice records a narrow better-than-Binaryen HSO-D boundary rather than changing Starshine to match Binaryen's less optimized output.

This is intentionally narrow: it only covers default descriptor constructor materialization where the replacement call values remain in source order and the descriptor operand is an immutable descriptor `global.get` that may be evaluated after those calls without changing observable behavior.

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
      (struct.new_default_desc $s
        (global.get $desc)))
    (struct.set $s 0
      (local.get $x)
      (call $helper (i32.const 1)))
    (struct.set $s 1
      (local.get $x)
      (call $helper (i32.const 2)))))
```

Command:

```sh
wasm-opt --all-features .tmp/hso-probe-default-desc-call-barrier.wat \
  --heap-store-optimization -S \
  -o .tmp/hso-probe-default-desc-call-barrier.opt.wat && \
grep -E "func|struct.set|struct.new|call|drop|global.get|i32.const" \
  .tmp/hso-probe-default-desc-call-barrier.opt.wat
```

Observed Binaryen result:

- `struct.new_default_desc` became `struct.new_desc`.
- The first call-valued store was folded into field `0`.
- Field `1` was materialized as `i32.const 0`.
- The second call-valued `struct.set $s 1` remained.
- The descriptor `global.get` remained in the constructor.

Interpretation: Binaryen's pass does not continue this default-descriptor chain far enough to absorb the second store in the same pass.

## Starshine behavior and classification

The focused test was first written to expect Binaryen's one-store-left shape and failed:

```text
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Initial failure excerpt showed Starshine had already folded both stores:

```text
body_raw:
  (i32.const I32(1))(call (Func 0))(i32.const I32(2))(call (Func 0))(global.get (Global 0))(struct.new_desc (Type 0))(local.set (Local 0))(end)
```

Agent classification: narrow Starshine win / better-than-Binaryen behavior. The Starshine output preserves the two helper calls in their original relative order, evaluates the immutable descriptor `global.get` after those calls, removes both redundant `struct.set` roots, and emits a single explicit `struct.new_desc` with both stored field values. That is a smaller and more direct constructor form without a measured safety downside in this shape.

This does **not** authorize broader divergence for arbitrary descriptor expressions, mutable descriptor globals, trapping/effectful descriptor operands, old-field side-effect conflicts, target-local hazards, or later-field effect barriers. Those remain governed by the existing HSO-D/E evidence and reopening criteria.

## Starshine coverage

Added focused test:

- `heap-store-optimization folds both default descriptor call stores as documented Starshine win`

The final test asserts that Starshine emits `struct.new_desc`, preserves the descriptor `global.get`, preserves both call constants, removes `struct.new_default_desc`, and removes all `struct.set` roots.

## Validation

- `wasm-opt --version` — `wasm-opt version 130 (version_130)`.
- `wasm-opt --all-features .tmp/hso-probe-default-desc-call-barrier.wat --heap-store-optimization -S -o .tmp/hso-probe-default-desc-call-barrier.opt.wat && grep -E "func|struct.set|struct.new|call|drop|global.get|i32.const" .tmp/hso-probe-default-desc-call-barrier.opt.wat` — Binaryen folded only the first store and preserved the second `struct.set`.
- `moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt` — first run failed with the Binaryen-shape expectation, exposing the Starshine double-fold.
- `moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt` — final run passed `247/247` after documenting the shape as a narrow Starshine-win test.

No implementation behavior changed. No native rebuild or direct compare was required for this documentation/test-only Starshine-win classification.

## Reopening criteria

Reopen HSO-D/E if a broader default-descriptor double-store fold moves calls out of order, crosses a mutable or effectful descriptor operand unsafely, drops overwritten old-field side effects, crosses target-local hazards, introduces validation failures, regresses code size/performance relative to keeping the second `struct.set`, or if Binaryen later adopts the same double-fold and exposes additional source-backed safety constraints.
