---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-monomorphize-primary-sources.md
  - ../../../raw/research/0176-2026-04-21-monomorphize-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Monomorphize.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-benefit.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-context.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-drop.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-limits.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-mvp.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-types.wast
related:
  - ./index.md
  - ./starshine-strategy.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./call-context-benefit-and-boundaries.md
---

# WAT shape catalog for `monomorphize`

This page catalogs the main shape families beginners should look for when reading Binaryen `monomorphize` output.

## Positive family 1: constant argument specialization

Before:

```wat
(func $call (param $x i32) (result i32)
  (call $target
    (local.get $x)
    (i32.const 1)))

(func $target (param $x i32) (param $y i32) (result i32)
  (select
    (local.get $x)
    (i32.const 42)
    (local.get $y)))
```

Typical Binaryen-style after shape:

```wat
(func $call (param $x i32) (result i32)
  (call $target_2
    (local.get $x)))

(func $target_2 (param $p0 i32) (result i32)
  (local $old_y i32)
  (local.set $old_y (i32.const 1))
  ...optimized body...)
```

Meaning:

- the constant stops being an ordinary call arg
- it becomes part of the specialized callee prelude
- the cloned callee often becomes easier to optimize further

## Positive family 2: refined reference argument specialization

Before:

```wat
(type $A (sub (struct)))
(type $B (sub $A (struct)))

(func $refinable (param (ref $A)) ...)

(func $calls (param $a (ref $A)) (param $b (ref $B))
  (call $refinable (local.get $a))
  (call $refinable (local.get $b)))
```

Possible after shape:

```wat
(func $calls (param $a (ref $A)) (param $b (ref $B))
  (call $refinable (local.get $a))
  (call $refinable_4 (local.get $b)))
```

Meaning:

- the specialized clone gets a narrower param type
- careful mode only keeps this if later optimization actually benefits from the narrower type

## Positive family 3: dropped-call result specialization

Before:

```wat
(drop
  (call $work
    (local.get $x)
    (local.get $y)))
```

Typical after shape:

```wat
(call $work_2
  (local.get $x)
  (local.get $y))
```

with the specialized callee now returning `none` and no longer carrying useless return traffic.

Meaning:

- the outer `drop` became part of the specialization context
- the specialized clone can simplify more because its result is now dead by construction

## Positive family 4: movable GC allocation context

Before:

```wat
(call $target-short
  (struct.new $A
    (local.get $y)))
```

Possible after shape:

```wat
(call $target-short_12
  (local.get $y))
```

where the specialized clone starts with a prelude like:

```wat
(local.set $tmp
  (struct.new $A
    (local.get $0)))
```

Meaning:

- Binaryen did not just specialize on a value class
- it moved a whole allocation context into the cloned callee
- later optimization may then remove or simplify that allocation there

## Positive family 5: many constants can shrink an over-wide signature back under the cap

Before:

```wat
(call $many-params
  (i32.const 0) (i32.const 0) ... many constants ...)
```

Possible after shape:

```wat
(call $many-params_3)
```

Meaning:

- even a very wide original signature can specialize successfully
- because constant operands stop being params and move into the callee prelude

## Positive family 6: same caller, several different specializations

Before:

```wat
(call $target ...all constants...)
(call $target ...one dynamic, rest constants...)
(call $target ...two dynamics, rest constants...)
```

Possible after shape:

```wat
(call $target_2)
(call $target_3 (local.get $x))
(call $target_4 (local.get $x) (local.get $x))
```

Meaning:

- Binaryen can create multiple specialized clones of the same original callee
- each clone corresponds to a different nontrivial context
- this is why the pass memoizes `(target, context)` pairs

## Bailout family 1: imported target

```wat
(import "env" "f" (func $f (param i32)))
(call $f (i32.const 1))
```

Why it stays:

- the pass only specializes defined module-local callees

## Bailout family 2: recursive self-call

```wat
(func $f (param i32)
  (call $f (i32.const 0)))
```

Why it stays:

- the reviewed implementation skips self-recursion to avoid in-run self-modification complexity

## Bailout family 3: trivial passthrough context

```wat
(call $target
  (local.get $x)
  (local.get $y))
```

Why it stays:

- the context carries no extra information beyond the original signature
- cloning would be wasted work

## Bailout family 4: operand subtree accesses locals or performs calls

```wat
(call $target
  (i32.add
    (local.get $x)
    (call $helper)))
```

Why it stays partly or wholly dynamic:

- Binaryen refuses to move local traffic and nested calls into the context here
- the surviving dynamic portion remains an ordinary call argument

## Bailout family 5: control-flow-shaped operand

```wat
(call $target
  (if (result i32) ...))
```

Why it stays:

- the pass deliberately refuses to move full control-flow structures into the specialized callee in `version_129`

## Bailout family 6: tuple-child surface

```wat
(call $target
  (tuple.extract 2 1
    (local.get $tuple)))
```

Why it stays:

- Binaryen avoids creating tuple params here
- the reviewed source treats this as a rare but explicit no-move family

## Bailout family 7: return-call / dropped-result safety boundary

```wat
(drop
  (call $target-that-return-calls ...))
```

Why the drop may stay outside:

- Binaryen refuses to pull the outer `drop` into a callee when that could destroy required return-call structure

## Bailout family 8: too many surviving dynamic params

```wat
(call $many-params
  (local.get $0) (local.get $1) ... too many dynamics ...)
```

Why it stays:

- even after context extraction, the specialized clone would still need too many params
- the reviewed hard limit is `20`

## Bailout family 9: legal specialization but not useful enough

This is the most important non-obvious negative case.
Sometimes a specialization is mechanically valid, but careful `monomorphize` still leaves the original call unchanged because nested optimization did not reduce cost enough.

That is the central lesson of `monomorphize-benefit.wast` and `monomorphize-types.wast`.

## The easiest misunderstanding to avoid

When reading output, do **not** ask only:

- “did this call have a constant?”

Also ask:

- “was the context nontrivial?”
- “could the operand code move safely?”
- “did the specialized clone stay under the param cap?”
- “did nested optimization actually make it cheaper enough?”

Those four questions explain most of the positive and negative families above.

## Sources

- [`../../../raw/binaryen/2026-04-24-monomorphize-primary-sources.md`](../../../raw/binaryen/2026-04-24-monomorphize-primary-sources.md)
- [`../../../raw/research/0176-2026-04-21-monomorphize-binaryen-research.md`](../../../raw/research/0176-2026-04-21-monomorphize-binaryen-research.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Monomorphize.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-benefit.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-context.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-drop.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-limits.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-mvp.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-types.wast>
