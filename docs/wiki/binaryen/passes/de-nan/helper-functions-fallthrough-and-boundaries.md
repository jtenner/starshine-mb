---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-de-nan-primary-sources.md
  - ../../../raw/research/0283-2026-04-24-de-nan-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0184-2026-04-21-de-nan-binaryen-research.md
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/DeNaN.cpp
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/properties.h
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/names.h
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/denan.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
---

# Helper functions, fallthrough, and boundaries in `de-nan` / `denan`

Use this page together with the raw primary-source manifest in [`../../../raw/binaryen/2026-04-24-de-nan-primary-sources.md`](../../../raw/binaryen/2026-04-24-de-nan-primary-sources.md) and the current Starshine status bridge in [`./starshine-strategy.md`](./starshine-strategy.md).

This page focuses on the easiest part of `denan` to misread:

- why some float-typed nodes are wrapped and others are not,
- what the helper functions actually promise,
- and where legality or rerun-safety boundaries stop the pass.

## The central teaching rule

`denan` is not a blanket “wrap every float-typed thing” pass.
It repairs value flows selectively.

The source-backed rule is:

- **wrap real producers**
- **skip pass-through shells**
- **skip plain `local.get` reads**

Everything else in the pass makes more sense once that distinction is clear.

## Why `local.get` is skipped

The implementation comment gives the reason directly:

- the added helper functions themselves use `local.get`
- instrumenting `local.get` would cause problems if the pass ran more than once

So `local.get` is a deliberate anti-self-interference boundary.

### What this means in practice

These shapes stay plain reads:

```wat
(drop (local.get $f))
(local.set $f (local.get $f))
```

The pass does **not** turn them into:

```wat
(drop (call $deNan32 (local.get $f)))
```

because it expects the source of `$f` to have been repaired already.

## Why result-fallthrough nodes are skipped

`Properties::isResultFallthrough(...)` returns true for nodes like:

- `local.set`
- `block`
- `if`
- `loop`
- `try`
- `try_table`
- `select`
- `break`

The point is not that those nodes are always safe.
The point is that their result can be the same child value falling through unchanged.

If the child has already been repaired, wrapping the shell again would be redundant.

## A beginner-friendly example: `local.set`

Consider:

```wat
(local.set $f (f32.abs (local.get $f)))
```

`denan` repairs the producer child:

```wat
(local.set $f (call $deNan32 (f32.abs (local.get $f))))
```

It does **not** then wrap the `local.set` node itself.
That would double-handle the same produced value.

## Another example: `select`

The shipped lit file shows a floating-result `select` body staying structurally a `select` after param-entry repair.
That is exactly what the fallthrough rule predicts.

So the right teaching summary is:

- `denan` repairs the thing that actually *computes* the value,
- not the structural container that simply yields it.

## Scalar helper function contract

The scalar helper for `f32` or `f64` is semantically:

```wat
(if (result f*)
  (f*.eq (local.get 0) (local.get 0))
  (local.get 0)
  (f*.const 0)
)
```

That means:

- if the input equals itself, it is not NaN, so return it unchanged
- otherwise it is NaN, so return zero

This helper does **not**:

- canonicalize NaN payloads
- preserve the sign of NaN-like values
- trap on NaN
- log or count NaNs

It simply filters NaN to zero.

## SIMD helper function contract

The SIMD helper is more complicated because a `v128` might be interpreted through floating lanes.
The source explains two key rules.

## Rule 1: use `f32x4` lane checks

Binaryen comments that the f32 NaN test is a superset of the f64 one for this purpose.
So it is enough to inspect four `f32` lanes.

## Rule 2: do not use vector equality directly

A direct vector-equality result would produce all-ones lanes for true comparisons.
Those all-ones patterns themselves resemble NaN payloads.
So a later rerun could interact badly with its own inserted helper code.

Instead Binaryen:

- extracts each lane
- compares each lane to itself with scalar `EqFloat32`
- ANDs the scalar results together

That is a very specific boundary a future port must preserve.

## Constant-only repair outside functions

Some contexts, like global initializers, cannot contain inserted helper calls.
That is why `denan` handles constant NaNs specially.

If a replacement is still a constant, Binaryen can install it outside functions.
If a replacement would be a call, Binaryen requires `getFunction()` and otherwise emits a warning.

### Positive global example

```wat
(global (mut f32) (f32.const nan))
```

can become:

```wat
(global (mut f32) (f32.const 0))
```

### Non-goal boundary

A nonconstant module-level floating producer is **not** repaired by synthesizing a helper call there.
That would be illegal wasm in that context.

## Imported-function boundary

Imported functions are skipped in `visitFunction`.
So entry-param repair applies only to defined functions.

This is a simple but real boundary:

- defined functions: entry sanitization happens
- imported functions: entry sanitization does not happen here

## Helper-name collision boundary

The pass chooses helper names with `Names::getValidFunctionName(...)`.
So if the module already contains:

- `deNan32`
- `deNan64`

Binaryen picks fresh suffixed names instead.
The lit file checks exactly that behavior.

This is not optional polish.
It is part of the real module-rewrite contract.

## Rerun-safety summary

The implementation clearly cares about avoiding accidental self-instrumentation.
Its main tools are:

- skip `local.get`
- skip result-fallthrough nodes
- add helpers after the walk
- scalarize SIMD lane checks inside the helper

The safest teaching summary is:

- `denan` is carefully guarded against obvious rerun hazards,
- but it should still be thought of as an instrumentation pass, not as a universal idempotent normal form.

That last sentence is an inference from the implementation style, not a formal upstream guarantee.

## Porting rules that are easy to lose

A future Starshine port must preserve all of these together:

1. skip `local.get`
2. skip result-fallthrough shells
3. sanitize params at entry anyway
4. permit constant repair outside functions
5. forbid helper-call repair outside functions
6. generate helper names collision-safely
7. preserve the special SIMD helper strategy

Dropping any one of those would change the real pass contract.

## Sources

- [`../../../raw/binaryen/2026-04-24-de-nan-primary-sources.md`](../../../raw/binaryen/2026-04-24-de-nan-primary-sources.md)
- [`../../../raw/research/0283-2026-04-24-de-nan-primary-sources-and-starshine-followup.md`](../../../raw/research/0283-2026-04-24-de-nan-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0184-2026-04-21-de-nan-binaryen-research.md`](../../../raw/research/0184-2026-04-21-de-nan-binaryen-research.md)
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/DeNaN.cpp>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/properties.h>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/names.h>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/denan.wast>
