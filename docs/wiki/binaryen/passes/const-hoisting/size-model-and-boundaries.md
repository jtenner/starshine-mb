---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0182-2026-04-21-const-hoisting-binaryen-research.md
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/ConstHoisting.cpp
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/const-hoisting.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
---

# `const-hoisting` size model and boundaries

This page focuses on the easiest part of `const-hoisting` to mis-teach:

- why some repeated constants are hoisted and others are not

## The real cost model

Binaryen compares two byte counts.

### Inline cost

If a literal of encoded size `size` appears `num` times, keeping it inline costs:

- `before = num * size`

### Hoisted cost

If Binaryen hoists it, the model becomes:

- one remaining literal payload: `size`
- one `local.set`: `2` bytes in the simplified model
- one `local.get` per use: `2 * num`

So:

- `after = size + 2 + 2 * num`

Hoist only if:

- `after < before`

That is the actual Binaryen rule.

## Why tiny constants never win

If `size <= 2`, the inequality can never produce a win.
That means:

- 1-byte constants never hoist
- 2-byte constants never hoist

This exactly matches the upstream lit tests.

## Concrete thresholds

The source comment rewrites the inequality as:

- `num > (size + 2) / (size - 2)`

That gives the practical thresholds:

| Encoded literal size | Minimum profitable uses |
| --- | --- |
| 1 byte | never |
| 2 bytes | never |
| 3 bytes | 6 uses |
| 4 bytes | 4 uses |
| 8 bytes | 2 uses |

That table explains almost every surprising test outcome.

## The integer cases in plain language

### Not profitable

These stay inline because their signed-LEB payloads are tiny:

- `i32.const 0`
- `i32.const 63`
- `i32.const 64`
- `i32.const 8191`
- `i32.const -64`
- `i32.const -65`
- `i32.const -8192`

Even if repeated many times in the shipped test, they are still cheaper inline than through `local.set`/`local.get` traffic.

### Profitable at 6 uses

These are 3-byte signed-LEB literals and become worth hoisting only at 6 appearances:

- `i32.const 8192`
- `i32.const 1048575`
- `i32.const -8193`
- `i32.const -1048576`

### Profitable at 4 uses

These are 4-byte signed-LEB literals and become worth hoisting at 4 appearances:

- `i32.const 1048576`
- `i32.const -1048577`

## Floating-point cases

For floats, Binaryen does not use LEB widths.
It uses the fixed payload width:

- `f32` = 4 bytes
- `f64` = 8 bytes

So the thresholds become:

- repeated `f32.const` literals need 4 appearances
- repeated `f64.const` literals need only 2 appearances

That is why even repeated zero floats are profitable much sooner than repeated small signed-LEB integers.

## The zero TODO that is not implemented yet

The source comment says zero is special:

- integer zero could in theory avoid even the initializing set
- float and double zero are especially attractive because their payloads are fixed-width and large

But the current pass does **not** implement a zero-special-case optimization.
It still uses the generic formula.
It also does **not** canonicalize float zeros before grouping, so `+0.0` and `-0.0` remain separate buckets even though both are numerically zero.

That distinction matters because it is easy to read the TODO and accidentally teach it as present behavior.

## Float identity boundary: same bytes, not just same math value

The byte-size model only decides whether a group is profitable **after** the pass has already decided which uses belong to the same `Literal` bucket.
That grouping is exact and bitwise for float literals.
So today:

- `+0.0` and `-0.0` are different buckets
- different NaN payloads are different buckets
- only identical typed bit patterns are counted together toward the use threshold

That matters because a beginner-friendly statement like “repeated `f32.const 0` hoists at 4 uses” is true only when those four uses are actually the same float encoding.

## Unsupported boundary: `v128`

The reviewed implementation returns false immediately for `v128`.
So the current size model is only defined for:

- `i32`
- `i64`
- `f32`
- `f64`

It is not currently a generic “all const types” pass.

## Non-goal boundaries

`const-hoisting` deliberately does **not** do any of the following:

- replace arithmetic trees with constants
- compare nonliteral expressions for equivalence
- share constants across functions
- synthesize immutable globals
- optimize compressed size
- optimize runtime speed directly

The source warning about gzip size is especially important:

- the pass may shrink raw wasm while worsening gzip

So a future port should keep the objective explicit instead of treating “smaller AST” or “more locals” as success by default.

## Porting rule of thumb

If a future Starshine implementation cannot or does not want to reproduce the exact byte model, it should say so explicitly.
This is one of those passes where “roughly similar behavior” is easy to get but the upstream contract is small enough that exact parity is feasible and worth preserving.

## Sources

- [`../../../raw/research/0182-2026-04-21-const-hoisting-binaryen-research.md`](../../../raw/research/0182-2026-04-21-const-hoisting-binaryen-research.md)
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/ConstHoisting.cpp>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/literal.h>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/const-hoisting.wast>
