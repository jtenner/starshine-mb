---
kind: concept
status: supported
last_reviewed: 2026-05-04
sources:
  - ../../../raw/binaryen/2026-05-04-tuple-optimization-current-main-recheck.md
  - ../../../raw/research/0434-2026-05-04-tuple-optimization-current-main-recheck.md
  - ../../../raw/research/0144-2026-04-20-tuple-optimization-binaryen-research.md
  - ../../../raw/research/0076-2026-04-01-tuple-optimization-binaryen-port-plan.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/tuple-optimization.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/TupleOptimization.cpp
  - ../../../../../src/passes/tuple_optimization_wbtest.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../../src/cmd/cmd_native_wbtest.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./starshine-strategy.md
  - ./starshine-hot-ir-strategy.md
  - ./scheduler-and-gates.md
---

# `tuple-optimization` WAT and IR shape catalog

This page answers three separate questions:

1. what **literal Binaryen tuple-local** shapes the upstream pass rewrites
2. what shapes the official tests prove it deliberately leaves alone
3. what HOT-native equivalents Starshine sees after lift, even when the raw WAT no longer prints as explicit tuple locals everywhere

## Reading rule

Binaryen's source and official lit file are written in terms of explicit tuple locals:

- `tuple.make`
- tuple-typed `local.set` / `local.tee`
- `tuple.extract`

Starshine's lifted HOT input often looks different:

- one multi-result producer
- a spill ladder of scalar locals
- copy groups rebuilt from those scalar locals
- optional host `local.tee` traffic

For the in-tree Starshine strategy and code map, see [`./starshine-strategy.md`](./starshine-strategy.md) and [`./implementation-map.md`](./implementation-map.md).

Those differences are representation differences.
The semantic question is still the same:

- does this traffic behave like a nonescaping tuple scratch bundle, or does it escape that narrow contract?

## Canonical upstream shape: tuple scratch local

### Before

```wat
(local.set $tuple
  (tuple.make 3
    (A)
    (B)
    (C)))

(use
  (tuple.extract 3 0
    (local.get $tuple)))
```

### After, conceptually

```wat
(local.set $lane0 (A))
(local.set $lane1 (B))
(local.set $lane2 (C))

(use
  (local.get $lane0))
```

### Why this rewrites

- the tuple local is only scratch storage
- later local passes can reason about dead lanes only after the tuple is split

## Positive shape family 1: write-only tuple local

Official lit family:

- `just-set`

### Before

```wat
(local.set $tuple
  (tuple.make 2
    (i32.const 1)
    (i32.const 2)))
```

### After

```wat
(local.set $lane0
  (i32.const 1))
(local.set $lane1
  (i32.const 2))
```

### Why this still matters

Even with no later tuple reads, the tuple local itself is dead indirection.
Binaryen still splits it so later passes can delete the now-unneeded tuple local and any dead scalar lanes.

## Positive shape family 2: read-only tuple local using default values

Official lit family:

- `just-get`

### Before

```wat
(drop
  (tuple.extract 2 0
    (local.get $tuple)))
(drop
  (tuple.extract 2 1
    (local.get $tuple)))
```

### After

```wat
(drop (local.get $lane0))
(drop (local.get $lane1))
```

### Important beginner note

The tuple local was never explicitly written first.
The new scalar locals still stand in for the tuple local's default initialized value.

That is why write-only and read-only tuple locals are both in scope.

## Positive shape family 3: tuple-local copy chain

Official lit families:

- `tee`
- `set-after-set`
- `chain-3`

### Before

```wat
(local.set $tuple0
  (tuple.make 2 ...))
(local.set $tuple1
  (local.get $tuple0))
(local.set $tuple2
  (local.get $tuple1))
(drop
  (tuple.extract 2 1
    (local.get $tuple2)))
```

### After, conceptually

```wat
(local.set $a0 ...)
(local.set $a1 ...)
(local.set $b0 (local.get $a0))
(local.set $b1 (local.get $a1))
(local.set $c0 (local.get $b0))
(local.set $c1 (local.get $b1))
(drop (local.get $c1))
```

### Why this rewrites

Tuple-local copies are still okay as long as the whole copy-connected component stays inside the approved tuple-local + `tuple.extract` world.

## Positive shape family 4: tuple `local.tee`

Official lit families:

- `just-tee`
- `tee`
- `tee-chain`

### Before

```wat
(drop
  (tuple.extract 2 0
    (local.tee $tuple
      (tuple.make 2 ...))))
```

### After, conceptually

```wat
(drop
  (block (result i32)
    (block
      (local.set $lane0 ...)
      (local.set $lane1 ...))
    (local.get $lane0)))
```

### Why this is special

The tee is both:

- a tuple-local write
- an expression result

So Binaryen cannot just erase the tuple expression and hope the surrounding code still sees the right value.
It must preserve the yielded lane value explicitly.

## Positive shape family 5: no later tuple readers, but approved copy traffic only

Official lit family:

- `no-uses`

### Before

```wat
(local.set $tuple
  (local.tee $tuple2
    (tuple.make 2 ...)))
```

### Why it still rewrites

This case surprises people the first time.
The set has no later tuple readers, and the tee only has its immediate tuple-like use.
But that is still enough for Binaryen to split both tuple locals because the whole component stays inside the approved tuple-local copy contract.

## Positive shape family 6: tuple element subtyping

Official lit family:

- `tuple.element.subtyping`

### Before

```wat
(local $tuple_null (tuple i32 nullref))
(local $tuple_eq   (tuple i32 eqref))

(local.set $tuple_eq
  (local.tee $tuple_null
    (tuple.make 2
      (i32.const 0)
      (ref.null none))))
```

### Why this matters

The copied tuple elements are not byte-for-byte identical in type at the destination.
Binaryen must still use the **source lane types** when rebuilding scalar gets so valid subtype relationships survive the split.

This is one of the easiest important details to miss if you only read the high-level source comment.

## Positive shape family 7: separate tuple families of different arities in one function

Official lit families:

- `two-2-three`
- `three-2-two`

### Beginner lesson

The pass does **not** require one global tuple arity discipline across the whole function.
It only requires each optimizable tuple-local family to be internally coherent.

So one function may contain:

- a good 2-lane tuple-local component
- a separate good 3-lane tuple-local component

and Binaryen can still optimize both.

## Negative shape family 1: whole-tuple escape poisons the component

Official lit families:

- `just-get-bad`
- `corruption-tee`
- `corruption-set`
- `corruption-first-set`
- `corruption-second-set`
- `chain-3-corruption`

### Before

```wat
(local.set $tuple2
  (local.get $tuple1))
...
(local.get $tuple1) ;; whole tuple escapes
```

### Why this bails out

A plain tuple-typed `local.get` escaping as a whole tuple is outside the pass's approved reader surface.
Because Binaryen treats tuple-local copies as one connected component, the entire copy-connected family must remain untouched.

That is why the tests use the word “corruption.”
One bad whole-tuple use corrupts the whole component.

## Negative shape family 2: tuple result from a call

Official lit family:

- `set-call`

### Before

```wat
(local.set $tuple
  (call $f))
```

### Why this bails out

The writer is neither:

- `tuple.make`
- tuple-local `local.get`
- reachable tuple-local `local.tee`

So it is outside the pass's narrow writer contract.

This is a good reminder that tuple-opt is not a generic tuple-value propagation pass.

## Negative shape family 3: tuple ops with no tuple local

Official lit families:

- `make-extract-no-local`
- `make-extract-no-local-but-other`

### Before

```wat
(drop
  (tuple.extract 2 0
    (tuple.make 2 ...)))
```

### Why this bails out

This family is intentionally handled elsewhere.
Binaryen expects earlier peepholes such as `optimize-instructions` to take care of the direct expression-level tuple pattern.
`tuple-optimization` is about tuple locals.

## Negative shape family 4: tuple local written from a block result

Official lit family:

- `set-of-block`

### Before

```wat
(local.set $tuple
  (block (result i32 i32)
    (tuple.make 2 ...)))
```

### Why this bails out

The source comment in `TupleOptimization.cpp` is explicit that broader block-related lowering is intentionally out of scope here.
The pass only lowers shapes that are “definitely worth lowering.”

That makes `set-of-block` one of the most important negative tests in the suite.
It proves the pass is deliberately narrower than the name suggests.

## Negative shape family 5: unreachable tuple-like traffic

Official lit families:

- `unreachability`
- `unreachable.tuple.extract`

### Why this matters

Binaryen must be conservative in unreachable code because tuple types can look misleading there.
The pass should:

- not crash
- not assume an unreachable tee is a valid tuple-local copy
- let earlier / neighboring cleanup passes simplify those shapes first

## HOT-native seed shape in Starshine

The simplest HOT-native equivalent of Binaryen's tuple-local scratch shape is the multivalue spill bridge:

```wat
(func (result i32)
  (local i32 i32 i32)
  block (result i32 i32 i32)
    i32.const 10
    i32.const 20
    i32.const 30
  end
  local.set 2
  local.set 1
  local.set 0
  local.get 0)
```

Why this is the right Starshine analogue:

- HOT lift often already exposes the bundle as one multi-result producer plus scalar lane locals
- so Starshine usually starts closer to Binaryen's **post-split** form than to Binaryen's explicit tuple-local AST form

## HOT-native copy-group families

The reduced Starshine repros extend the official upstream intuition into lifted shapes such as:

- exact-copy result-block carriers
- scalar-forward copy groups
- mixed direct / forwarded lane transport
- host `local.tee` bridge groups
- nested scalar-result or branch-exit carrier families
- terminal drop-only host or no-host tails

Those are not contradictions of the upstream docs.
They are HOT-native equivalents of the same underlying question:

- is this still one nonescaping lane bundle, or has it escaped into unsupported scalar traffic?

## Practical rule for new bugs

When a new tuple bug appears, classify it in this order:

1. official upstream tuple-local family
2. official upstream bailout family
3. HOT-native equivalent of an upstream family
4. HOT-only staging or lowering drift after the tuple rewrite already made the correct semantic decision

That order keeps the Binaryen contract clear even when the local implementation uses a different IR.

## Sources

- [`../../../raw/research/0144-2026-04-20-tuple-optimization-binaryen-research.md`](../../../raw/research/0144-2026-04-20-tuple-optimization-binaryen-research.md)
- [`../../../raw/research/0076-2026-04-01-tuple-optimization-binaryen-port-plan.md`](../../../raw/research/0076-2026-04-01-tuple-optimization-binaryen-port-plan.md)
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/tuple-optimization.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/TupleOptimization.cpp>
- Starshine local evidence:
  - [`../../../../../src/passes/tuple_optimization_wbtest.mbt`](../../../../../src/passes/tuple_optimization_wbtest.mbt)
  - [`../../../../../src/cmd/cmd_wbtest.mbt`](../../../../../src/cmd/cmd_wbtest.mbt)
  - [`../../../../../src/cmd/cmd_native_wbtest.mbt`](../../../../../src/cmd/cmd_native_wbtest.mbt)
