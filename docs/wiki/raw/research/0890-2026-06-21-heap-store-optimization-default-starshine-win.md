# `heap-store-optimization` plain default double-store Starshine win

## Summary

Binaryen `version_130` folds only the first call-valued store in a two-store `struct.new_default` chain. Starshine folds both call-valued stores into the materialized `struct.new` while preserving the helper-call order, so this slice records another narrow better-than-Binaryen HSO-D boundary rather than changing Starshine to keep Binaryen's second `struct.set`.

This is intentionally narrow: it covers plain `struct.new_default` materialization where both replacement values are calls and their relative order is preserved. It does not authorize broader movement across mutable/effectful/trapping descriptor operands, target-local hazards, old-field side effects, later-field barriers, or arbitrary control-flow values.

## Binaryen probe

Local oracle: `wasm-opt version 130 (version_130)`.

Probe shape:

```wat
(module
  (rec
    (type $s (struct (field (mut i32)) (field (mut i32)))))
  (type $helper (func (param i32) (result i32)))
  (import "env" "helper" (func $helper (type $helper)))
  (func $test (local $x (ref null $s))
    (local.set $x
      (struct.new_default $s))
    (struct.set $s 0
      (local.get $x)
      (call $helper (i32.const 1)))
    (struct.set $s 1
      (local.get $x)
      (call $helper (i32.const 2)))))
```

Command:

```sh
wasm-opt --version && \
wasm-opt --all-features .tmp/hso-probe-default-call-double.wat \
  --heap-store-optimization -S \
  -o .tmp/hso-probe-default-call-double.opt.wat && \
grep -E "func|struct.set|struct.new|call|drop|i32.const" \
  .tmp/hso-probe-default-call-double.opt.wat
```

Observed Binaryen result:

- `struct.new_default` became `struct.new`.
- The first call-valued store was folded into field `0`.
- Field `1` was materialized as `i32.const 0`.
- The second call-valued `struct.set $s 1` remained.

Interpretation: Binaryen's default-constructor materialization does not continue this double-call chain far enough to absorb the second store in the same pass.

## Starshine behavior and classification

The focused test was first written to expect the Binaryen-shape second `struct.set` and failed:

```text
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Failure excerpt:

```text
body_raw:
  (i32.const I32(1))(call (Func 0))(i32.const I32(2))(call (Func 0))(struct.new (Type 0))(local.set (Local 0))(end)
```

Agent classification: narrow Starshine win / better-than-Binaryen behavior. The Starshine output preserves the two helper calls in their original relative order, removes both redundant `struct.set` roots, and emits one explicit `struct.new` with both stored field values. This is a smaller and more direct constructor form without a measured safety downside in this plain default-constructor shape.

## Starshine coverage

Added focused test:

- `heap-store-optimization folds both default call stores as documented Starshine win`

The final test asserts that Starshine emits `struct.new`, preserves both call constants, removes `struct.new_default`, and removes all `struct.set` roots.

## Validation

- `wasm-opt --version` — `wasm-opt version 130 (version_130)`.
- `wasm-opt --all-features .tmp/hso-probe-default-call-double.wat --heap-store-optimization -S -o .tmp/hso-probe-default-call-double.opt.wat && grep -E "func|struct.set|struct.new|call|drop|i32.const" .tmp/hso-probe-default-call-double.opt.wat` — Binaryen folded only the first store and preserved the second `struct.set`.
- `moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt` — first run failed with the Binaryen-shape expectation, exposing Starshine's double-fold.
- `moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt` — final run passed `248/248`.

No implementation behavior changed. No native rebuild or direct compare was required for this documentation/test-only Starshine-win classification.

## Reopening criteria

Reopen HSO-D/E if a broader default-constructor double-store fold moves calls out of order, crosses mutable/effectful/trapping operands unsafely, drops overwritten old-field side effects, crosses target-local hazards, introduces validation failures, regresses code size/performance relative to keeping the second `struct.set`, or if Binaryen later adopts the same double-fold and exposes additional source-backed safety constraints.
