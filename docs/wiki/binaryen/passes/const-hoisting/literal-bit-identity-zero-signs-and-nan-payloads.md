---
kind: concept
status: supported
last_reviewed: 2026-05-06
sources:
  - ../../../raw/binaryen/2026-05-06-const-hoisting-current-main-recheck.md
  - ../../../raw/research/0508-2026-05-06-const-hoisting-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-27-const-hoisting-port-readiness-primary-sources.md
  - ../../../raw/binaryen/2026-04-23-const-hoisting-primary-sources.md
  - ../../../raw/binaryen/2026-04-25-const-hoisting-current-main-recheck.md
  - ../../../raw/research/0428-2026-04-27-const-hoisting-port-readiness.md
  - ../../../raw/research/0225-2026-04-21-const-hoisting-literal-identity-followup.md
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/ConstHoisting.cpp
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/literal.h
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/const-hoisting.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./size-model-and-boundaries.md
  - ./wat-shapes.md
  - ./starshine-port-readiness-and-validation.md
---

# `const-hoisting` literal bit identity, zero signs, and NaN payloads

This page covers the easiest subtlety in `const-hoisting` to miss after you already understand the byte-cost algebra:

- **what counts as “the same constant” for hoisting purposes**

For the Starshine negative-test checklist that preserves these buckets, see [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

The short answer is:

- Binaryen groups by exact `Literal`
- and `Literal` equality for basic values is type-plus-bits, not broad numeric equivalence

That matters most for float corner cases.

## The real grouping key

`ConstHoisting.cpp` stores uses in:

- `InsertOrderedMap<Literal, std::vector<Expression**>> uses`

So the pass is not using:

- printed constant text
- integer-only normalization
- fuzzy numeric equality

It is using the whole `Literal` object as the key.

## What `Literal` equality means here

In `literal.h`, Binaryen documents `Literal::operator==` as:

- comparing both the type and the bits
- which means NaN floats compare bitwise

That gives the actual `const-hoisting` bucket rule:

- same type
- same bits
- first-seen order preserved by `InsertOrderedMap`

## Why `+0.0` and `-0.0` do **not** share one hoist bucket

This is the most important beginner-facing corner case.

At a math level:

- `+0.0 == -0.0`

But `const-hoisting` is not using broad floating-point equality.
Because the grouping key is type-plus-bits:

- `f32.const 0.0`
- `f32.const -0.0`

are different buckets.

The same is true for `f64`.

So today, if a function contains many `+0.0` literals and many `-0.0` literals:

- Binaryen may hoist the `+0.0` group
- Binaryen may hoist the `-0.0` group
- but it will not merge them into one shared temp local

## Why NaN payloads do **not** share one hoist bucket

`literal.h` also makes NaN handling explicit:

- NaN equality here is bitwise

So these are different groups:

- one `f32` NaN payload pattern
- another `f32` NaN payload pattern

Even if both would print loosely as `nan`, Binaryen does not treat them as one hoistable value.

That means the practical rule is:

- identical NaN bit patterns can group
- different NaN payloads cannot group

## Hashing matches the same rule

This is not just a comment-level policy.
The `std::hash<Literal>` support in `literal.h` hashes:

- `f32` via `reinterpreti32()`
- `f64` via `reinterpreti64()`

So float hashing is bit-pattern-based too.
That matches the equality semantics instead of quietly canonicalizing floats.

## Why the zero TODO does not change current behavior

`ConstHoisting.cpp` contains TODO comments saying, roughly:

- zero might be special enough to avoid the initial set
- float and double zero might be especially beneficial

But current `version_129` does not implement a zero-special path.
The pass still uses the ordinary size calculation:

- integers by signed-LEB payload width
- `f32` as `4` bytes
- `f64` as `8` bytes
- the same `before` versus `after` formula for all supported scalar literal groups

So today the correct teaching is:

- **zero is only a TODO special case**
- not an implemented optimization

## Important consequence: `isZero()` is not the grouping rule

`literal.h` has an `isZero()` helper.
For floats it uses ordinary numeric comparison to zero, so both `+0.0` and `-0.0` count as zero there.

But `const-hoisting` does not group with `isZero()`.
It groups with `Literal` equality.

That is why these two claims can both be true:

- both float encodings are “zero” in a general helper sense
- they still do not hoist together in the current pass

## Dedicated lit surface: one real check and one small comment typo

The official `const-hoisting.wast` file proves the real float thresholds:

- `f32` literals need `4` appearances
- `f64` literals need `2` appearances

The checked output for the final `$enough-d` example matches that.
However, that example's inline source comment still says:

- `4 bytes, need 4 appearances`

That comment is stale or mistaken.
The implementation and `CHECK:` lines are the real oracle.

## Shape examples to keep straight

## Separate float-zero buckets

```wat
(func
  (drop (f32.const 0.0))
  (drop (f32.const 0.0))
  (drop (f32.const -0.0))
  (drop (f32.const -0.0))
)
```

Beginner-friendly expectation:

- not one merged four-use bucket
- instead two separate two-use buckets
- which still fail the current `f32` threshold

## Separate NaN-payload buckets

```wat
(func
  (drop (f32.const nan:0x1))
  (drop (f32.const nan:0x1))
  (drop (f32.const nan:0x2))
  (drop (f32.const nan:0x2))
)
```

Beginner-friendly expectation:

- two distinct buckets, not one four-use float bucket

## What does share a bucket

These do group together:

```wat
(func
  (drop (f64.const 0))
  (drop (f64.const 0))
)
```

Why:

- same type
- same bits
- enough uses for the `8`-byte `f64` threshold

## Best short rule to teach

When explaining `const-hoisting`, say:

- repeated literal values are grouped by exact typed bit identity
- floats are not normalized by numeric equality
- `+0.0`, `-0.0`, and different NaN payloads can all land in separate buckets

That wording is much safer than just saying “same constant value.”

## Sources

- [`../../../raw/binaryen/2026-05-06-const-hoisting-current-main-recheck.md`](../../../raw/binaryen/2026-05-06-const-hoisting-current-main-recheck.md)
- [`../../../raw/research/0508-2026-05-06-const-hoisting-current-main-recheck.md`](../../../raw/research/0508-2026-05-06-const-hoisting-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-23-const-hoisting-primary-sources.md`](../../../raw/binaryen/2026-04-23-const-hoisting-primary-sources.md)
- [`../../../raw/binaryen/2026-04-25-const-hoisting-current-main-recheck.md`](../../../raw/binaryen/2026-04-25-const-hoisting-current-main-recheck.md)
- [`../../../raw/research/0225-2026-04-21-const-hoisting-literal-identity-followup.md`](../../../raw/research/0225-2026-04-21-const-hoisting-literal-identity-followup.md)
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/ConstHoisting.cpp>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/literal.h>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/const-hoisting.wast>
