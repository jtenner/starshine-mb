---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0187-2026-04-21-monomorphize-always-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-benefit.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-context.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-drop.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-types.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./usefulness-gate-and-sibling-split.md
  - ../monomorphize/index.md
---

# `monomorphize-always` WAT and IR shapes

This page is the beginner-friendly shape catalog for Binaryen `monomorphize-always`.

The easiest way to read the page is:

- first ask whether the context is legal and nontrivial
- then ask whether ordinary `monomorphize` might still reject it for weak payoff
- if yes, that is exactly the kind of shape where `monomorphize-always` becomes easiest to see

## Positive shape 1: constant argument produces a specialized clone even when the payoff is only modest

### Before

```wat
(func $callee (param $x i32) (result i32)
  (i32.add
    (local.get $x)
    (i32.const 1)))

(func $caller (param $y i32) (result i32)
  (call $callee
    (i32.const 9)))
```

### After under `monomorphize-always`, conceptually

```wat
(func $callee$mono$0 (result i32)
  (i32.const 10))

(func $caller (param $y i32) (result i32)
  (call $callee$mono$0))
```

The exact printed form can vary, but the important shape is:

- the constant moved into the specialized clone
- the specialized clone lost a parameter
- the callsite retargeted to the clone

If ordinary `monomorphize` thinks the payoff is too weak, it may keep the original generic call instead.
The sibling keeps the specialized shape visible.

## Positive shape 2: mixed context leaves one dynamic param and one inlined constant

### Before

```wat
(func $pair (param $a i32) (param $b i32) (result i32)
  (i32.add (local.get $a) (local.get $b)))

(func $caller (param $x i32) (result i32)
  (call $pair
    (i32.const 4)
    (local.get $x)))
```

### After under `monomorphize-always`, conceptually

```wat
(func $pair$mono$0 (param $b i32) (result i32)
  (local.set $old_a (i32.const 4))
  (i32.add (local.get $old_a) (local.get $b)))

(func $caller (param $x i32) (result i32)
  (call $pair$mono$0
    (local.get $x)))
```

This is the core contextual-specialization story:

- some operand context moves inward
- some dynamic data remains an actual parameter

## Positive shape 3: refined reference type becomes a visible specialized clone

### Before

```wat
(func $use (param $r anyref) (result anyref)
  (local.get $r))

(func $caller (param $s (ref null $Sub)) (result anyref)
  (call $use
    (local.get $s)))
```

### After under `monomorphize-always`, conceptually

```wat
(func $use$mono$0 (param $r (ref null $Sub)) (result anyref)
  (local.get $r))

(func $caller (param $s (ref null $Sub)) (result anyref)
  (call $use$mono$0
    (local.get $s)))
```

This is exactly the sort of shape the sibling helps teach.
The specialization is real even if the immediate cost win is small.

## Positive shape 4: dropped result becomes a `none`-result specialized clone

### Before

```wat
(func $work (param $x i32) (result i32)
  (i32.add (local.get $x) (i32.const 1)))

(func $caller
  (drop
    (call $work
      (i32.const 7))))
```

### After under `monomorphize-always`, conceptually

```wat
(func $work$mono$0
  (drop
    (i32.add (i32.const 7) (i32.const 1))))

(func $caller
  (call $work$mono$0))
```

The exact cleanup may simplify further, but the important shape is:

- the outer `drop` got absorbed into the specialized clone
- the specialized call no longer returns a live value

## Negative shape 1: imported callee

### Before

```wat
(import "env" "f" (func $f (param i32) (result i32)))

(func $caller (result i32)
  (call $f (i32.const 1)))
```

### After

No change from either variant.

The pass family specializes defined callees, not imported ones.

## Negative shape 2: trivial passthrough context

### Before

```wat
(func $id (param $x i32) (result i32)
  (local.get $x))

(func $caller (param $y i32) (result i32)
  (call $id (local.get $y)))
```

### After

No change.

This is the classic trivial-context bailout:

- no dropped result
- no constant
- no refined type
- no moved subtree
- just same-typed passthrough `local.get`

`monomorphize-always` does **not** force specialization here.

## Negative shape 3: illegal context movement across visible effects

### Before

```wat
(func $callee (param i32) (result i32)
  (local.get 0))

(func $caller (param $x i32) (result i32)
  (call $callee
    (i32.add
      (call $side)
      (local.get $x))))
```

### After

No illegal inward move.
Potentially no specialization at all.

The shared context builder still refuses movements that would reorder visible effects.

## Negative shape 4: too many surviving dynamic inputs

### Before

A very large function whose context still leaves too many dynamic values as parameters after specialization.

### After

No clone is kept if the specialized signature still exceeds the hard cap.

This bailout is shared with ordinary `monomorphize`.

## What beginners most often misread

### Misread 1: "always" means no bailouts

Wrong.
It only removes the usefulness rejection.
It keeps the same legality and triviality bailouts.

### Misread 2: this is just inlining

Wrong.
The callee is cloned and specialized.
The caller is not rewritten into a direct copy of the callee body the way ordinary inlining works.

### Misread 3: refined types only matter when a big optimization follows immediately

Wrong.
The sibling exists partly so official tests can keep those smaller but still-real specialized clones visible.

## Sources

- [`../../../raw/research/0187-2026-04-21-monomorphize-always-binaryen-research.md`](../../../raw/research/0187-2026-04-21-monomorphize-always-binaryen-research.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-benefit.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-context.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-drop.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-types.wast>
