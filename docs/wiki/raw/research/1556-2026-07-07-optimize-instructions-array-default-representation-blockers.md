# Optimize-instructions array default representation blockers

Date: 2026-07-07

## Context

This note records a bounded recursive OI fact-slice investigation into widening Binaryen v130 `visitArrayNew` / `visitArrayNewFixed` default facts beyond the currently represented scalar defaults. Binaryen's source checks array constructor defaults by comparing `Properties::getFallthrough(value)` with `Literal::makeZero(type)`, so SIMD all-zero values and nullable-reference fallthrough wrappers are part of the upstream fact surface.

The investigation found additional Starshine representation blockers before safe TDD implementation could proceed. These blockers should be fixed before adding the corresponding `OiArrayDefaultValueFact` widening, otherwise tests either fail before assertions or would require unverified private shortcuts.

## Binaryen source facts

- `.tmp/binaryen-version130/OptimizeInstructions.cpp` `visitArrayNew` checks constant length one first, then checks defaultable element type, `getFallthrough(curr->init)`, `Properties::isSingleConstantExpression`, and `Literal::makeZero(type)` before rewriting to `drop(init); array.new_default`.
- `.tmp/binaryen-version130/OptimizeInstructions.cpp` `visitArrayNewFixed` proves adjacent equality, then checks the representative through `getFallthrough` and `Literal::makeZero(type)` before rewriting to `array.new_default` through `getDroppedChildrenAndAppend`.
- `.tmp/binaryen-v130-rub/src/ir/properties.h` `getImmediateFallthroughPtr` looks through `local.tee`, unnamed block tails, loop bodies, one-unreachable-arm `if`, reorder-safe value `br_if`, nonthrowing old `try`, `ref.cast`, non-conversion `ref.as_*`, and `br_on*` ref operands.

## Probes

### v128 defaults

Probe file: `.tmp/oi-array-v128-default-probe.wat` (not committed).

```wat
(module
  (type $arr (array (mut v128)))
  (func (export "new") (result (ref $arr))
    v128.const i32x4 0 0 0 0
    i32.const 3
    array.new $arr)
  (func (export "fixed") (result (ref $arr))
    v128.const i32x4 0 0 0 0
    v128.const i32x4 0 0 0 0
    array.new_fixed $arr 2))
```

Command:

```sh
wasm-opt .tmp/oi-array-v128-default-probe.wat --optimize-instructions -S --enable-gc --enable-reference-types --enable-simd -o -
```

Binaryen v130 rewrites:

- `array.new` with all-zero `v128.const` initializer to `drop(v128.const 0); array.new_default`.
- `array.new_fixed` with two all-zero `v128.const` operands to `array.new_default` length `2`.

Starshine public/HOT fixture attempt failed before assertions in `run_hot_pipeline` / HOT verification with the original body still present:

```text
FAILED: func code[0] ...
body_raw:
  (v128.const 00000000000000000000000000000000)(i32.const I32(3))(array.new (Type 0))(end)
```

This blocks a red-first behavior test for `v128` array-default facts even though Binaryen has a clear source-backed behavior.

### Reference-typed fixed-array operands

A direct builder fixture for `array.new_fixed` over a nullable reference array with `ref.null` operands also failed before assertions. The reduced attempted body was equivalent to:

```wat
(module
  (type $arrref (array (mut (ref null eq))))
  (func (result (ref $arrref))
    ref.null eq
    ref.null eq
    array.new_fixed $arrref 2))
```

The HOT/pass failure reported the lowered original body with two `ref.null` operands and `array.new_fixed`, before any behavior assertion could run. This is broader than the previously documented control-valued `array.new_fixed` blocker: at least some reference-typed fixed-array operands also cannot currently be used as public/HOT OI regression fixtures.

Binaryen probe `.tmp/oi-array-fixed-refcast-equal-probe.wat` showed the intended upstream behavior for a related nullable-reference fallthrough/default case:

```wat
(module
  (type $arrref (array (mut (ref null eq))))
  (func (export "fixed-cast2") (result (ref $arrref))
    ref.null eq
    ref.cast (ref null eq)
    ref.null eq
    array.new_fixed $arrref 2))
```

Command:

```sh
wasm-opt .tmp/oi-array-fixed-refcast-equal-probe.wat --optimize-instructions -S --enable-gc --enable-reference-types -o -
```

Binaryen rewrites this to `array.new_default` length `2`.

### Nullable ref.cast `array.new`

Probe file: `.tmp/oi-array-default-fallthrough-probe.wat` (not committed) showed Binaryen already treats nullable `ref.cast(ref.null)` as default for `array.new`, emitting a dropped null followed by `array.new_default`. A direct Starshine fixture for the `array.new` form did not expose a red behavior gap because existing OI-J/ref-cast cleanup appears to simplify the shape before the array default fact needs to widen. This is an inference from the focused test passing immediately; it was not kept as coverage because it was not red-first.

## Current blocker statement

Do not implement the next OI-K/OI-L default fact by assuming these families are semantically safe drift:

- all-zero `v128` `array.new` / `array.new_fixed` defaults;
- nullable-reference `array.new_fixed` defaults, including `ref.cast(ref.null)` fallthrough representatives;
- the previously known control-valued `array.new_fixed` operands.

They are Binaryen-backed parity gaps, but Starshine needs a representable public/HOT fixture or an explicit lower-level fact-test seam before behavior can be implemented TDD-first.

## Reopening criteria

Reopen these as implementation slices when one of the following is true:

1. HOT verification/lowering accepts `v128` array constructor operands through `optimize-instructions` public/HOT tests.
2. HOT verification/lowering accepts nullable-reference `array.new_fixed` operands through `optimize-instructions` public/HOT tests.
3. A narrow internal fact-test seam is added that can red-first exercise `OiArrayDefaultValueFact` / `OiArrayDefaultFallthroughFact` without bypassing pass validation.
4. A reduced compare-pass mismatch proves one of these families is reachable through generated modules after HOT support has been fixed.

Until then, keep these as representation blockers in the OI-K/OI-L array-constructor backlog, not as accepted Starshine wins.
