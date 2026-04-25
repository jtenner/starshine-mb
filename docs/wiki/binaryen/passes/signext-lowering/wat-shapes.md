---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-signext-lowering-primary-sources.md
  - ./binaryen-strategy.md
related:
  - ./index.md
  - ./starshine-strategy.md
  - ../optimize-instructions/wat-shapes.md
  - ../pick-load-signs/wat-shapes.md
---

# `signext-lowering` WAT shapes

This page lists the concrete shapes transformed by Binaryen `signext-lowering` and the nearby shapes it deliberately does not own.

## Shape family 1: `i32.extend8_s`

Before:

```wat
(i32.extend8_s
  (local.get $x))
```

After:

```wat
(i32.shr_s
  (i32.shl
    (local.get $x)
    (i32.const 24))
  (i32.const 24))
```

Why `24`: the source field is 8 bits inside a 32-bit lane, so the pass shifts left by `32 - 8` and then arithmetic-right-shifts by the same amount.

## Shape family 2: `i32.extend16_s`

Before:

```wat
(i32.extend16_s
  (local.get $x))
```

After:

```wat
(i32.shr_s
  (i32.shl
    (local.get $x)
    (i32.const 16))
  (i32.const 16))
```

The result type remains `i32`.

## Shape family 3: `i64.extend8_s`

Before:

```wat
(i64.extend8_s
  (local.get $y))
```

After:

```wat
(i64.shr_s
  (i64.shl
    (local.get $y)
    (i64.const 56))
  (i64.const 56))
```

The shift count is `64 - 8`.

## Shape family 4: `i64.extend16_s`

Before:

```wat
(i64.extend16_s
  (local.get $y))
```

After:

```wat
(i64.shr_s
  (i64.shl
    (local.get $y)
    (i64.const 48))
  (i64.const 48))
```

The shift count is `64 - 16`.

## Shape family 5: `i64.extend32_s`

Before:

```wat
(i64.extend32_s
  (local.get $y))
```

After:

```wat
(i64.shr_s
  (i64.shl
    (local.get $y)
    (i64.const 32))
  (i64.const 32))
```

This is still an `i64 -> i64` unary operation. Do not confuse it with `i64.extend_i32_s`, which converts an `i32` input to an `i64` result and is not part of this pass.

## Effectful child shape

Before:

```wat
(i32.extend8_s
  (i32.load8_u (local.get $p)))
```

After:

```wat
(i32.shr_s
  (i32.shl
    (i32.load8_u (local.get $p))
    (i32.const 24))
  (i32.const 24))
```

The load remains under the new shift pair and still executes once. This same principle applies to calls, traps, and other child expressions: the pass nests the child, it does not duplicate it.

## Nested sign-extension shape

Before:

```wat
(i32.extend8_s
  (i32.extend16_s (local.get $x)))
```

After, before any later cleanup:

```wat
(i32.shr_s
  (i32.shl
    (i32.shr_s
      (i32.shl (local.get $x) (i32.const 16))
      (i32.const 16))
    (i32.const 24))
  (i32.const 24))
```

`signext-lowering` may create redundant-looking shift pairs. Removing or simplifying them belongs to other passes, not to this one.

## Feature annotation shape

The dedicated Binaryen test also proves that the pass removes the sign-extension feature from output. In practical WAT terms, a module-level sign-extension target-feature marker should not survive as a claim that sign-extension opcodes are still required after all those opcodes are lowered.

Starshine currently has opaque custom-section preservation, not a Binaryen-identical `FeatureSet::SignExt` model. See [`starshine-strategy.md`](starshine-strategy.md) for the local caveat.

## Non-transformed nearby shapes

### Not `i64.extend_i32_s`

```wat
(i64.extend_i32_s (local.get $i32))
```

This is a numeric conversion from `i32` to `i64`, not a same-width sign-extension opcode. `signext-lowering` does not own it.

### Not load-sign selection

```wat
(i32.extend8_s
  (i32.load8_u (local.get $p)))
```

`signext-lowering` lowers the outer `i32.extend8_s`. It does not decide to rewrite `i32.load8_u` into `i32.load8_s`; that is the domain of [`../pick-load-signs/index.md`](../pick-load-signs/index.md).

### Not sign-extension pattern recognition

```wat
(i32.shr_s
  (i32.shl (local.get $x) (i32.const 24))
  (i32.const 24))
```

This shape is already the lowered form. `signext-lowering` does not turn it back into `i32.extend8_s`; [`../optimize-instructions/index.md`](../optimize-instructions/index.md) is the neighboring place to study sign-extension pattern simplification.

### Not a profitability pass

The rewrite can increase instruction count. That is acceptable because the objective is feature compatibility, not immediate size reduction.

## Validation checklist

A complete test suite for a future Starshine port should include:

- one positive test for each of the five opcodes;
- a child-with-effects test to prove no child duplication;
- a nested-sign-extension test to show this pass does not try to simplify its own output;
- a negative `i64.extend_i32_s` test;
- a feature-metadata test if Starshine gains an explicit target-feature model.
