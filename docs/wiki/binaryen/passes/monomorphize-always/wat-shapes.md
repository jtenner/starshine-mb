---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-monomorphize-always-primary-sources.md
  - ../../../raw/research/0318-2026-04-24-monomorphize-always-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0187-2026-04-21-monomorphize-always-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-types.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-context.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-drop.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-limits.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./usefulness-gate-and-sibling-split.md
  - ./starshine-strategy.md
  - ../monomorphize/wat-shapes.md
---

# `monomorphize-always` WAT and IR shapes

This is the beginner-friendly shape catalog for Binaryen `monomorphize-always`.

Read each shape in two passes:

1. Is the context legal and nontrivial?
2. Might ordinary `monomorphize` reject it for weak payoff?

If the answer to both is yes, the shape is exactly where `monomorphize-always` is easiest to see.

## Positive shape 1: refined reference type survives as a specialized clone

This is the most direct sibling-lit family; see `monomorphize-types.wast`.

### Before

```wat
(type $Base (struct))
(type $Sub (sub $Base (struct)))

(func $use (param $r (ref null $Base)) (result (ref null $Base))
  (local.get $r))

(func $caller (param $s (ref null $Sub)) (result (ref null $Base))
  (call $use
    (local.get $s)))
```

### After under `monomorphize-always`, conceptually

```wat
(func $use$mono$0 (param $r (ref null $Sub)) (result (ref null $Base))
  (local.get $r))

(func $caller (param $s (ref null $Sub)) (result (ref null $Base))
  (call $use$mono$0
    (local.get $s)))
```

The clone can expose a sharper parameter type even when the immediate body shrink is small.

## Positive shape 2: constant argument produces a clone even with modest payoff

### Before

```wat
(func $callee (param $x i32) (result i32)
  (i32.add
    (local.get $x)
    (i32.const 1)))

(func $caller (result i32)
  (call $callee
    (i32.const 9)))
```

### After under `monomorphize-always`, conceptually

```wat
(func $callee$mono$0 (result i32)
  (i32.const 10))

(func $caller (result i32)
  (call $callee$mono$0))
```

The exact printed form can vary, but the important shape is:

- the constant moved into the specialized clone
- the specialized clone lost a parameter
- the callsite retargeted to the clone

Ordinary `monomorphize` may reject this if the computed benefit is too weak.

## Positive shape 3: mixed context leaves one dynamic param

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

This is the core contextual-specialization story: some operand context moves inward, while dynamic data remains an actual parameter.

## Positive shape 4: dropped result becomes a `none`-result clone

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

The important shape is that the outer `drop` can be absorbed into the specialized clone when Binaryen proves it is safe.

## Negative shape 1: imported callee

### Before

```wat
(import "env" "f" (func $f (param i32) (result i32)))

(func $caller (result i32)
  (call $f (i32.const 1)))
```

### After

No change.

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

No clone is kept.

This is the classic trivial-context bailout:

- no dropped result
- no constant
- no refined type
- no moved subtree
- just same-typed passthrough `local.get`

`monomorphize-always` does not force specialization here.

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

No illegal inward move. Often no specialization is kept at all.

The shared context builder still refuses movements that would reorder visible effects.

## Negative shape 4: too many surviving dynamic inputs

### Before

A large callsite where specialization still leaves too many dynamic values as clone parameters.

### After

No clone is kept if the specialized signature exceeds the hard cap.

This bailout is shared with ordinary `monomorphize`.

## Starshine shape caveat

Current Starshine has no local before/after output for these shapes because [`./starshine-strategy.md`](./starshine-strategy.md) documents `monomorphize-always` as boundary-only. These examples are Binaryen strategy/port-planning shapes, not current Starshine behavior.

## Common misreads

### Misread 1: “always” means no bailouts

Wrong. It only removes the usefulness rejection. It keeps the same legality and triviality bailouts.

### Misread 2: this is just inlining

Wrong. The callee is cloned and specialized. The caller is not rewritten into a direct copy of the callee body the way ordinary inlining works.

### Misread 3: existing Starshine threshold plumbing implements it

Wrong. `--monomorphize-min-benefit` option storage is adjacent configuration plumbing, not a clone-building pass.

## Sources

- [`../../../raw/binaryen/2026-04-24-monomorphize-always-primary-sources.md`](../../../raw/binaryen/2026-04-24-monomorphize-always-primary-sources.md)
- [`../../../raw/research/0318-2026-04-24-monomorphize-always-primary-sources-and-starshine-followup.md`](../../../raw/research/0318-2026-04-24-monomorphize-always-primary-sources-and-starshine-followup.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-types.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-context.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-drop.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-limits.wast>
