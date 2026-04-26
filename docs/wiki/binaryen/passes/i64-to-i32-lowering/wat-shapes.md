---
kind: concept
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-i64-to-i32-lowering-port-readiness-primary-sources.md
  - ../../../raw/research/0412-2026-04-26-i64-to-i32-lowering-port-readiness.md
  - ../../../raw/binaryen/2026-04-24-i64-to-i32-lowering-primary-sources.md
  - ../../../raw/research/0299-2026-04-24-i64-to-i32-lowering-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0175-2026-04-21-i64-to-i32-lowering-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/I64ToI32Lowering.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_i64-to-i32-lowering.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./flatness-helpers-and-boundaries.md
  - ./abi-surface-and-opcode-coverage.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
---

# Beginner-friendly WAT shape catalog for `i64-to-i32-lowering`

This page focuses on what kinds of WAT or IR shapes Binaryen actually rewrites.
The examples are schematic, not exact checked output dumps.
For the current Starshine non-implementation status and future local code map, see [`./starshine-strategy.md`](./starshine-strategy.md). For implementation order and validation lanes, see [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

## Core mental model

After lowering, one original `i64` value usually becomes:

- one visible low-half `i32` expression
- one hidden high-half temp or helper global

So many positive examples below really mean:

- `low-half visible here`
- `high-half stored beside it`

## Positive family 1: i64 params and locals split into low/high slots

### Before

```wat
(func $f (param $x i64)
  (local $y i64)
  ...)
```

### After

```wat
(func $f (param $x i32) (param $x$hi i32)
  (local $y i32) (local $y$hi i32)
  ...)
```

### Why Binaryen likes this

This is the foundational representation change.
Everything else assumes the high half is next to the low half.

## Positive family 2: i64 return becomes i32 return plus helper global write

### Before

```wat
(func $f (result i64)
  ...)
```

### After

```wat
(global $i64toi32_i32$HIGH_BITS (mut i32) (i32.const 0))

(func $f (result i32)
  ;; compute low
  ;; store high to helper global
  ...)
```

### Why this matters

This is the easiest visible sign that the pass is an ABI rewrite, not just local arithmetic lowering.

## Positive family 3: direct call with i64 arg/result

### Before

```wat
(call $g
  <i64-value>)
```

### After

```wat
(call $g
  <low-i32>
  <high-i32>)
```

and if the result was `i64`:

```wat
(block
  (local.set $tmpLow
    (call $g ...))
  (local.set $tmpHigh
    (global.get $i64toi32_i32$HIGH_BITS))
  (local.get $tmpLow))
```

### Why Binaryen likes this

This preserves ordinary call syntax while carrying the high half out-of-band.

## Positive family 4: imported direct call retargeted to legalized shim

### Before

```wat
(import "env" "g" (func $g (param i64) (result i64)))
(call $g ...)
```

### After conceptually

```wat
(call $legalfunc$g ...)
```

### Why this matters

This shows the pass assumes JS-interface legalization has already prepared import shims.

## Positive family 5: local.get on a lowered i64 local

### Before

```wat
(local.get $x) ;; x : i64
```

### After conceptually

```wat
(block
  (local.set $tmpHigh
    (local.get $x$hi))
  (local.get $x))
```

### Why Binaryen likes this

The visible result stays simple, while the high half is attached in the hidden side channel.

## Positive family 6: local.tee on a lowered i64 value

### Before

```wat
(local.tee $x
  <i64-value>)
```

### After conceptually

```wat
(block
  (local.set $tmpLow
    (local.tee $x <low-i32>))
  (local.set $x$hi
    <high-i32>)
  (local.get $tmpLow))
```

### Why Binaryen likes this

`tee` still has to yield a low-half value while also updating the stored high half.

## Positive family 7: global.get / global.set on rewritten i64 globals

### Before

```wat
(global $g (mut i64) ...)
(global.get $g)
(global.set $g <i64-value>)
```

### After conceptually

```wat
(global $g (mut i32) ...)
(global $g$hi (mut i32) ...)

(block
  (local.set $tmpHigh (global.get $g$hi))
  (global.get $g))

(sequence
  (global.set $g <low-i32>)
  (global.set $g$hi <high-i32>))
```

### Important limit

This applies to non-imported globals only in reviewed `version_129`.

## Positive family 8: 64-bit load split into two 32-bit pieces

### Before

```wat
(i64.load offset=K align=A <ptr>)
```

### After conceptually

```wat
(block
  (local.set $ptrTmp <ptr>)
  (local.set $low
    (i32.load offset=K align=min(A,4) (local.get $ptrTmp)))
  (local.set $high
    (i32.load offset=K+4 align=min(A,4) (local.get $ptrTmp)))
  (local.get $low))
```

### Small-width signed/unsigned loads

For smaller signed/unsigned i64 loads, Binaryen does not always emit a second load.
Instead it may synthesize the high half from:

- sign extension of the low half, or
- zero

## Positive family 9: 64-bit store split into low/high stores

### Before

```wat
(i64.store offset=K align=A <ptr> <i64-value>)
```

### After conceptually

```wat
(block
  (local.set $ptrTmp <ptr>)
  (i32.store offset=K align=min(A,4)
    (local.get $ptrTmp)
    <low-i32>)
  (i32.store offset=K+4 align=min(A,4)
    (local.get $ptrTmp)
    <high-i32>))
```

### Why Binaryen likes this

Pointer evaluation still happens once, and 64-bit memory contents are preserved as two adjacent 32-bit stores.

## Positive family 10: `i64.eqz`

### Before

```wat
(i64.eqz <i64-value>)
```

### After conceptually

```wat
(i32.eqz
  (i32.or
    <low-i32>
    <high-i32>))
```

### Why Binaryen likes this

Both halves must be zero for the original `i64` to be zero.

## Positive family 11: add/sub with carry or borrow

### Before

```wat
(i64.add <a> <b>)
(i64.sub <a> <b>)
```

### After conceptually

```wat
;; add low halves
;; add high halves
;; repair high half with carry if low overflowed
```

and similarly for subtraction with a borrow bit.

### Why Binaryen likes this

This is classic two-limb integer lowering.

## Positive family 12: shifts split by `< 32` versus `>= 32`

### Before

```wat
(i64.shl <x> <k>)
(i64.shr_u <x> <k>)
(i64.shr_s <x> <k>)
```

### After conceptually

Binaryen first computes:

- `k % 32`
- whether `k % 64 >= 32`

Then it emits one block for the large-shift case and one for the small-shift case.

### Why this matters

This is a good example of the pass being more than trivial halfwise rewriting.
The boundary between the halves changes at 32 bits.

## Positive family 13: comparisons compare high halves first

### Before

```wat
(i64.lt_u <a> <b>)
(i64.lt_s <a> <b>)
(i64.eq <a> <b>)
```

### After conceptually

- equality checks both low and high halves
- unsigned order compares high halves first, then low halves if highs tie
- signed order uses signed compare on high halves and unsigned tie-breaks on low halves

### Why Binaryen likes this

This is the normal limb-comparison strategy for 64-bit values split into 32-bit chunks.

## Positive family 14: `select` on lowered i64 values

### Before

```wat
(select <i64-a> <i64-b> <cond>)
```

### After conceptually

```wat
(block
  (local.set $condTmp <cond>)
  (local.set $lowTmp
    (select <low-a> <low-b> (local.get $condTmp)))
  (local.set $highTmp
    (select <high-a> <high-b> (local.get $condTmp)))
  (local.get $lowTmp))
```

### Why Binaryen likes this

Condition evaluation stays single-shot while both halves are selected consistently.

## Positive family 15: reinterpret through scratch helpers

### Before

```wat
(f64.reinterpret_i64 <i64-value>)
(i64.reinterpret_f64 <f64-value>)
```

### After conceptually

Binaryen stores one representation through scratch-memory helper imports and reloads the other.

### Why this matters

This is an important negative lesson too:

- not every rewrite stays inside ordinary wasm instructions
- helper imports are part of the real contract

## Positive family 16: atomic helper lowering

### Before

```wat
(i64.atomic.rmw.* ...)
(memory.atomic.wait32/64 ... timeout:i64)
```

### After conceptually

Binaryen may replace these with helper calls such as:

- `ATOMIC_RMW_I64`
- `GET_STASHED_BITS`
- `ATOMIC_WAIT_I32`

### Why this matters

For these shapes, the pass preserves semantics through helper imports, not by pretending split non-atomic wasm operations are enough.

## Bailout family 1: imported i64 globals

### Shape

```wat
(import "env" "g" (global $g (mut i64)))
```

### Result

Reviewed `version_129` still aborts on this family.

## Bailout family 2: `return_call` with i64 result

### Shape

```wat
(return_call $g ...)
```

where `$g` returns `i64`.

### Result

Reviewed `version_129` still aborts on this family.

## Bailout family 3: non-flat input

### Shape

Any function body that does not satisfy Binaryen's flatness rules.

### Result

The pass relies on `Flat::verifyFlatness(func)`.
So this is a hard structural precondition, not an optimization preference.

## Bailout family 4: direct support for some harder i64 ops

### Shapes

- `i64.mul`
- `i64.div_s`
- `i64.div_u`
- `i64.rem_s`
- `i64.rem_u`
- rotates
- `i64.popcnt`
- `i64.ctz`

### Result

The reviewed file treats these as operations that should already have been removed or lowered elsewhere.

## Bailout family 5: direct atomic split load/store lowering

### Shape

- atomic `i64.load`
- atomic `i64.store`
- atomic `i64.cmpxchg`

### Result

These are not all handled by simple split memory ops in this pass.
Some are rejected, and some are redirected to helper calls instead.

## Hardest beginner-facing lesson

The pass name suggests a simple rule:

- “replace `i64` with two `i32`s”

The real WAT story is wider:

- split signatures
- split locals/globals
- visible low half plus hidden high-half temps
- synthetic return global
- helper imports for reinterpret and some atomics
- real unsupported families and scheduler prerequisites

That wider story is what a future Starshine port must preserve. The safe Starshine sequence is to classify these families first, then land a narrow scalar local/type split before enabling call, global, return, memory, helper, or atomic shapes; see [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).
