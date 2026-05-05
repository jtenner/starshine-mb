---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-optimize-added-constants-current-main-recheck.md
  - ../../../raw/research/0465-2026-05-05-optimize-added-constants-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-27-optimize-added-constants-port-readiness-primary-sources.md
  - ../../../raw/research/0418-2026-04-27-optimize-added-constants-port-readiness.md
  - ../../../raw/binaryen/2026-04-24-optimize-added-constants-primary-sources.md
  - ../../../raw/research/0300-2026-04-24-optimize-added-constants-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0232-2026-04-21-optimize-added-constants-safety-followup.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/OptimizeAddedConstants.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/optimize-added-constants_low-memory-unused.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/optimize-added-constants_low-memory-unused.txt
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-added-constants-memory64.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-added-constants-nomemory.wast
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/OptimizeAddedConstants.cpp
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../optimize-added-constants-propagate/index.md
---

# `optimize-added-constants` low-memory threshold, overflow, and offset-merge rules

This page isolates the part of Binaryen's plain `optimize-added-constants` contract that is easiest to mis-port.
It is anchored to the 2026-04-24 raw primary-source manifest [`../../../raw/binaryen/2026-04-24-optimize-added-constants-primary-sources.md`](../../../raw/binaryen/2026-04-24-optimize-added-constants-primary-sources.md), the 2026-05-05 current-main source-anchor digest [`../../../raw/binaryen/2026-05-05-optimize-added-constants-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-optimize-added-constants-current-main-recheck.md), and the 2026-04-27 current-main / local-readiness recheck [`../../../raw/binaryen/2026-04-27-optimize-added-constants-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-27-optimize-added-constants-port-readiness-primary-sources.md).

The safety questions are:

- when the pass is allowed to fold an added constant into a memory offset,
- when it is allowed to merge a constant pointer with an existing offset,
- and why `1023` and `1024` behave differently.

## The shortest accurate rule

Binaryen folds only the **boring obviously-safe** address cases.

That means it wants all of these at once:

- `--low-memory-unused` is enabled,
- the pass is looking at a `Load` or `Store`,
- the added constant is strictly below `LowMemoryBound`,
- the **merged total offset** is also strictly below `LowMemoryBound`,
- and constant-pointer normalization does not overflow the memory address width.

## Rule 1: the pass hard-requires `--low-memory-unused`

`OptimizeAddedConstants.cpp` does not treat low-memory knowledge as a soft heuristic.
It aborts the pass when `getPassOptions().lowMemoryUnused` is false.

Why that matters:

- `base + c` in ordinary wasm arithmetic can wrap,
- but a memory instruction `offset=` field does not model “wrap into reachable low memory” the same way,
- so Binaryen only performs these folds when the optimizer is allowed to assume that low memory is unreachable anyway.

Beginner version:

- no low-memory guarantee,
- no pass.

## Rule 2: plain mode is still only about `Load` / `Store`

The plain pass does **not** own generic arithmetic simplification.
It only rewrites pointer expressions that feed memory operations directly.

That means this page is about two surfaces only:

- direct `base + const` address folding,
- constant-pointer-plus-offset normalization.

If the address first flows through locals, that is the sibling pass's job:

- [`../optimize-added-constants-propagate/index.md`](../optimize-added-constants-propagate/index.md)

## Rule 3: `LowMemoryBound` is a strict `< 1024` cutoff

`src/pass.h` defines:

- `PassOptions::LowMemoryBound = 1024`

But the important source fact is how `OptimizeAddedConstants.cpp` uses it.
`canOptimizeConstant(...)` accepts only constants where:

- `value < PassOptions::LowMemoryBound`

not `<=`.

So the public behavior is:

- `1023` can still be folded,
- `1024` is already too large.

The shipped `optimize-added-constants_low-memory-unused.{wast,txt}` files make that visible for both loads and stores.

## Rule 4: Binaryen checks the merged total offset too

This is the easiest rule to miss.
Binaryen does not stop after checking the new constant.
It also computes:

- `total = curr->offset + value`

and only succeeds when:

- `total < PassOptions::LowMemoryBound`

So these are different:

- “the new constant is small enough”
- “the final merged offset is small enough”

A faithful port must require **both**.

## Practical example: why this matters

This can fold:

```wat
(i32.store offset=2
  (i32.add
    (local.get $x)
    (i32.const 5))
  (local.get $v))
```

because the total offset becomes `7`, which is still below `1024`.

But a future port must not generalize that into:

- “any small constant can be merged into any existing offset.”

Binaryen's real rule is narrower:

- merge only when the resulting total still stays in the low-memory-safe range.

## Rule 5: constant-pointer normalization is a separate path

Binaryen also handles this family:

```wat
(i32.load offset=10
  (i32.const 0))
```

which it prefers to rewrite conceptually into:

```wat
(i32.load
  (i32.const 10))
```

The source comment explains the preference plainly:

- the two encodings are interchangeable,
- but Binaryen prefers to keep the entire constant address in the constant for clarity and compressibility.

Important detail:

- this path is **not** gated by the `< 1024` total-offset rule in the same way,
- it is gated by **unsigned overflow safety** for the target address width.

## Rule 6: memory32 and memory64 use different overflow proofs

For constant-pointer normalization, Binaryen proves that `base + offset` cannot overflow.
The proof changes with address width.

### Memory32

Binaryen checks that:

- `uint64_t(base) + uint64_t(offset) < 2^32`

If that succeeds, it rewrites the pointer constant and clears the explicit offset.

### Memory64

Binaryen checks that:

- `base <= UINT64_MAX - offset`

If that succeeds, it rewrites the pointer constant and clears the explicit offset.

### Beginner correction

Memory64 does **not** change the low-memory threshold.
It changes only the width of the unsigned-overflow proof for constant-pointer normalization.

So two facts stay separate:

- the `< 1024` low-memory rule for added-constant folding,
- the 32-bit vs 64-bit unsigned-overflow rule for constant-pointer normalization.

## Rule 7: existing large offsets may stay large

The source comments make another subtle point explicit:

- a memory op may already have a large offset,
- and Binaryen does not automatically treat that as invalid or rewriteable,
- but it only performs extra normalization when the no-overflow case is obvious.

That is why the constant-pointer path is taught best as:

- “merge existing offset into the constant only when unsigned addition is obviously safe,”

not as:

- “always collapse offset plus constant pointer into one constant pointer.”

## Rule 8: negative and wraparound-looking cases stay untouched

The official plain-pass tests deliberately preserve the edge cases that would require more adventurous reasoning:

- negative constants,
- offsets that would reach or exceed the low-memory bound,
- and memory64 constant-pointer cases where `base + offset` would overflow.

So the real public contract is intentionally conservative.

## Read the tests as a safety matrix

The shipped tests are easiest to remember as four small promises.

### `optimize-added-constants_low-memory-unused.{wast,txt}`

Proves:

- direct folds happen,
- existing-offset accumulation happens,
- `1023` folds,
- `1024` does not,
- negative examples stay unfused.

### `optimize-added-constants-memory64.wast`

Proves:

- constant-pointer normalization still works on memory64,
- but only when `base + offset` does not overflow unsigned 64-bit addressing.

### `optimize-added-constants-nomemory.wast`

Proves:

- the pass is a valid no-op on no-memory modules.

## Why this page matters for future Starshine work

[`./starshine-strategy.md`](./starshine-strategy.md) records that current Starshine already has `low_memory_unused=false` / `low_memory_bound=1024` option plumbing but still no pass owner file. If Starshine ports plain `optimize-added-constants`, the easiest wrong implementation would be something like:

- “if I see `add(base, const)`, move the const into `offset=`.”

That would be too broad.
Binaryen's real contract is narrower and more beginner-teachable:

1. require `--low-memory-unused`,
2. only touch `Load` / `Store` pointers in plain mode,
3. accept only added constants with `value < 1024`,
4. also require the final merged offset to stay `< 1024`,
5. normalize constant pointers only when unsigned addition cannot overflow,
6. keep 32-bit and 64-bit overflow proofs separate,
7. leave negative and wraparound-looking cases alone.

## One-sentence memory aid

If you remember only one sentence, remember this:

> Binaryen `optimize-added-constants` only folds the boring obviously-safe memory-address cases: small nonnegative added constants stay below the low-memory bound, and constant-pointer cleanup happens only when unsigned address addition cannot overflow.
