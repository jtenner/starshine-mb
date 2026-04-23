---
kind: concept
status: supported
last_reviewed: 2026-04-23
sources:
  - ../../../raw/binaryen/2026-04-23-alignment-lowering-primary-sources.md
  - ../../../raw/research/0171-2026-04-21-alignment-lowering-binaryen-research.md
  - ../../../raw/research/0200-2026-04-21-alignment-lowering-chunk-matrix-followup.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/AlignmentLowering.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/bits.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/alignment-lowering.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
---

# `alignment-lowering`: chunk selection and unreachable semantics

## Why this page exists

The first `alignment-lowering` dossier already explained the pass correctly at a high level.
The biggest remaining teaching gap was lower-level and more mechanical:

- exactly which byte-width/alignment combinations the helpers really implement
- how the pass chooses byte vs halfword vs split-32-bit chunk families
- what the builder-level single-evaluation scaffolding really looks like
- and how unreachable loads/stores preserve operand evaluation

Those details matter for a faithful port because this pass is small enough that most of its real contract *is* those details.

## First rule: the helper matrix is small

The broad pass description is:

- lower unaligned scalar loads and stores into smaller aligned ones

But the actual helper matrix in `AlignmentLowering.cpp` is much narrower.

### What returns early before helper logic matters

The visitors and helpers immediately leave the node alone when:

- `align == 0`
- or `align == bytes`

That means already-natural/default alignment is a no-op.

### What helper combinations are actually live

Once those early returns have happened, the core integer helpers only need these cases:

| Helper family | Bytes | Live weak alignments | Rewrite family |
| --- | --- | --- | --- |
| `lowerLoadI32` | `2` | `1` | two `load8_u` pieces, maybe plus sign-extension |
| `lowerLoadI32` | `4` | `1` | four `load8_u` pieces |
| `lowerLoadI32` | `4` | `2` | two `load16_u` pieces |
| `lowerStoreI32` | `2` | `1` | two `store8` pieces |
| `lowerStoreI32` | `4` | `1` | four `store8` pieces |
| `lowerStoreI32` | `4` | `2` | two `store16` pieces |

Everything else in those helpers is treated as internal-unreachable source state, not as a supported runtime fallback path.

## Why 1-byte families mostly disappear from the interesting matrix

Single-byte scalar accesses are already naturally aligned at `align=1`.
So for ordinary misalignment lowering, the helpers do not need a rich 1-byte case table.

That is easy to miss if you only remember the public pass name.
The source-backed teaching summary is:

- the helper matrix is mostly about misaligned `2`- and `4`-byte integer families
- larger scalar families are wrappers around that matrix

## The real chunk-selection rule

A beginner might guess the pass always falls back to bytes.
That is **not** what Binaryen does.

The actual pattern is:

- if the original declared alignment is `1`, split to bytes
- if the original declared alignment is `2`, use halfwords where possible
- for full-width 64-bit values, split into two 32-bit halves first, then apply the same rule inside each half

So the true rule is:

> choose the largest naturally aligned chunk family that is still legal under the original weaker alignment.

That is why `align=2` `i32` access lowers to two halfword operations instead of four bytes.

## Exact load-side matrix

## Misaligned 16-bit integer load

### Source pattern

```wat
(i32.load16_s align=1 ...)
(i32.load16_u align=1 ...)
```

### Binaryen strategy

- emit two `load8_u` pieces
- shift the second piece left by `8`
- `or` the two pieces together
- if the original load was signed, repair signedness afterward with `Bits::makeSignExt(..., 2, ...)`

### Important teaching point

Binaryen does **not** issue signed byte loads here.
It rebuilds raw bits first, then performs explicit sign repair.

## Misaligned 32-bit integer load with `align=1`

### Source pattern

```wat
(i32.load align=1 ...)
```

### Binaryen strategy

- emit four `load8_u` pieces
- shift them by `8`, `16`, and `24`
- `or` them into one `i32`

## Misaligned 32-bit integer load with `align=2`

### Source pattern

```wat
(i32.load align=2 ...)
```

### Binaryen strategy

- emit two `load16_u` pieces
- shift the high half left by `16`
- `or` the two halves together

## Exact store-side matrix

## Misaligned 16-bit integer store

### Source pattern

```wat
(i32.store16 align=1 ...)
```

### Binaryen strategy

- emit `store8` of the low byte
- emit `store8` of `value >> 8`

## Misaligned 32-bit integer store with `align=1`

### Source pattern

```wat
(i32.store align=1 ...)
```

### Binaryen strategy

- emit four `store8` pieces
- use right shifts `8`, `16`, `24` for the upper bytes

## Misaligned 32-bit integer store with `align=2`

### Source pattern

```wat
(i32.store align=2 ...)
```

### Binaryen strategy

- emit two `store16` pieces
- use `value >> 16` for the high half

## Wrapper families: `f32`, narrow `i64`, full `i64`, and `f64`

The broad scalar surface is implemented as wrappers around the matrix above.

| Source family | Real lowering center |
| --- | --- |
| `f32` load/store | reinterpret through `i32`, then reuse the `i32` helper |
| narrow `i64` load | lower through `i32`, then sign- or zero-extend |
| narrow `i64` store | wrap to `i32`, then reuse the `i32` store helper |
| full `i64` load/store | split into low/high 32-bit halves |
| `f64` load/store | reinterpret through full-width `i64` logic |

That is why the dossier keeps emphasizing that the real implementation center is the `i32` helper matrix.

## Full-width 64-bit splitting rule

When the source access is full-width `i64` or `f64`, Binaryen does **not** directly emit eight byte operations at the top level.
Instead it:

1. spills the pointer once
2. lowers the low 32-bit half at `offset`
3. lowers the high 32-bit half at `offset + 4`
4. rebuilds the final `i64`
5. reinterprets to `f64` when needed

On the store side it similarly:

1. spills pointer once
2. spills value once
3. extracts low/high 32-bit halves
4. lowers each half through the normal `i32` store helper

### Why reusing the same weak alignment is valid

At this point the only interesting weak alignments are `1`, `2`, and `4`.
Adding `4` to the offset keeps the same alignment promise legal for the high half.
That is a source-important reason the pass can reuse the original `align` there instead of recomputing some new alignment.

## Single-evaluation scaffolding is part of the contract

The pass is not merely “equivalent smaller memory ops.”
It is “equivalent smaller memory ops after single-evaluation preservation.”

## Load scaffolding

For rewritten loads, Binaryen:

- allocates a fresh pointer local with the memory `addressType`
- stores the original pointer expression there once
- rebuilds the result from repeated `local.get` reads of that temp
- wraps the sequence in a result-producing block

That is the builder-level reason the rewritten load can safely duplicate the pointer *value* without duplicating the pointer *expression*.

## Store scaffolding

For rewritten stores, Binaryen:

- allocates a fresh pointer local
- allocates a fresh value local
- evaluates each original child once into those locals
- emits the split stores from the temp locals

This is even more important on the store side because both children may carry effects.

## Unreachable handling is narrow and explicit

The unreachable rules are easy to misremember, so keep them literal.

## Unreachable load

If the load's own type is already `unreachable`, Binaryen replaces the whole node with the pointer child.

### Meaning

- the memory operation itself disappears
- the pointer expression remains as the semantic carrier
- Binaryen does **not** synthesize a special wrapper block here

## Unreachable store

If the store's type is already `unreachable`, Binaryen replaces it with a sequence that drops:

- the pointer child
- the value child

### Meaning

- the memory operation itself disappears
- both child evaluations are still preserved
- this is a deliberate operand-preserving rule, not incidental cleanup

## Why these unreachable rules matter

A naive port could easily get this wrong in two opposite ways:

- deleting the whole node and silently losing child effects
- or preserving too much structure and accidentally implying the memory op itself still happens

Binaryen does neither.
It preserves **operand evaluation only**.

## Offsets are incremented, not re-associated away

When the pass emits chunked loads/stores, it keeps the original memarg offset structure explicit.

Examples:

- byte chunks use `offset`, `offset + 1`, `offset + 2`, `offset + 3`
- halfword chunks use `offset` and `offset + 2`
- full-width 64-bit splitting uses `offset` and `offset + 4`

That means a future port should not casually rewrite the pointer arithmetic shape into some different but equivalent-looking form unless it deliberately wants to drift from Binaryen's printed output style.

## What is internal-unreachable versus public bailout

This distinction matters for faithful teaching.

### Public no-op / bailout behavior

These are ordinary visible no-op boundaries:

- already-natural/default alignment
- source families outside `Load`/`Store`

### Internal-unreachable assumptions

These are source assertions, not user-facing dynamic fallbacks:

- unsupported helper byte widths inside the dedicated `i32` helpers
- unsupported weak alignments for those helper cases
- unsupported type-family paths after the visitor has already filtered the node family

A future port may encode those differently internally, but it should keep the same *effective* supported surface.

## Porting checklist distilled from this page

A faithful Starshine port should preserve all of these:

- exact helper matrix for `2`- and `4`-byte misaligned integer families
- “largest legal chunk” selection, not automatic byte splitting everywhere
- explicit post-assembly sign repair for signed narrow loads
- `f32`/`f64` reinterpret staging
- narrow/full `i64` wrapper behavior around the integer helper matrix
- pointer and value temp locals for single evaluation
- operand-only preservation for unreachable loads and stores
- explicit offset increments for chunked pieces

## Best short summary

If the main strategy page says what the pass is,
this page says how Binaryen *really executes* that promise:

> a very small exact chunk-selection matrix, wrapped in strict single-evaluation scaffolding and operand-preserving unreachable fast paths.
