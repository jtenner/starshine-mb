---
kind: concept
status: supported
last_reviewed: 2026-05-06
sources:
  - ../../../raw/binaryen/2026-05-06-alignment-lowering-current-main-recheck.md
  - ../../../raw/research/0496-2026-05-06-alignment-lowering-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-26-alignment-lowering-current-main-port-readiness.md
  - ../../../raw/research/0379-2026-04-26-alignment-lowering-port-readiness.md
  - ../../../raw/binaryen/2026-04-23-alignment-lowering-primary-sources.md
  - ../../../raw/research/0171-2026-04-21-alignment-lowering-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/AlignmentLowering.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/alignment-lowering.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/bits.h
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./starshine-port-readiness-and-validation.md
---

# WAT shape catalog for `alignment-lowering`

## Reading this page correctly

This pass is shape-driven, but the shapes are narrower than many people expect. The 2026-05-06 current-main recheck confirmed the same upstream shapes; the earlier 2026-04-26 port-readiness recheck still makes them the recommended first red-test ladder for a future Starshine port.
It rewrites only ordinary scalar loads and stores with weaker-than-natural alignment.

Read every example below as:

- "what Binaryen directly rewrites"
- "what Binaryen directly leaves alone"
- and "what a faithful port must preserve exactly"

## Shape 1: natural-alignment no-op

**Pattern:** natural alignment or default alignment.

```wat
(i32.load (local.get $p))
(i32.load align=4 (local.get $p))
(i32.store (local.get $p) (local.get $v))
(i32.store align=4 (local.get $p) (local.get $v))
```

**What Binaryen does:**

- leaves these unchanged

**Why:**

- the pass only handles weaker-than-natural alignment
- reviewed code treats `align == 0` and `align == bytes` as immediate no-op cases

## Shape 2: `i32.load align=1` becomes four byte loads

**Pattern:**

```wat
(i32.load align=1 (local.get $p))
```

**Rewritten shape:**

```wat
(block (result i32)
  (local.set $tmp-p (local.get $p))
  (i32.or
    (i32.or
      (i32.load8_u (local.get $tmp-p))
      (i32.shl (i32.load8_u offset=1 (local.get $tmp-p)) (i32.const 8)))
    (i32.or
      (i32.shl (i32.load8_u offset=2 (local.get $tmp-p)) (i32.const 16))
      (i32.shl (i32.load8_u offset=3 (local.get $tmp-p)) (i32.const 24)))))
```

**What to remember:**

- pointer is evaluated once and spilled
- offsets stay explicit on the smaller loads
- Binaryen rebuilds the original bits, not the original syntax

## Shape 3: `i32.load align=2` becomes two halfword loads

**Pattern:**

```wat
(i32.load align=2 (local.get $p))
```

**Rewritten shape:**

```wat
(block (result i32)
  (local.set $tmp-p (local.get $p))
  (i32.or
    (i32.load16_u (local.get $tmp-p))
    (i32.shl
      (i32.load16_u offset=2 (local.get $tmp-p))
      (i32.const 16))))
```

**Why this is easy to miss:**

- Binaryen does not always split all the way to bytes
- it uses the biggest aligned chunk size still legal under the weaker alignment

## Shape 4: signed 16-bit load must restore sign

**Pattern:**

```wat
(i32.load16_s align=1 (local.get $p))
```

**Rewritten shape:**

- first rebuild the raw 16 bits from two `load8_u`s
- then sign-extend the result back to 32 bits

A beginner-friendly approximation is:

```wat
(i32.shr_s
  (i32.shl
    (reconstructed-16-bit-value)
    (i32.const 16))
  (i32.const 16))
```

**Why this matters:**

- byte loads themselves are unsigned here
- the pass must separately restore the original signed meaning

## Shape 5: `i32.store align=1` becomes four byte stores

**Pattern:**

```wat
(i32.store align=1 (call $ptr) (call $val))
```

**Rewritten shape:**

```wat
(block
  (local.set $tmp-p (call $ptr))
  (local.set $tmp-v (call $val))
  (i32.store8 (local.get $tmp-p) (local.get $tmp-v))
  (i32.store8 offset=1 (local.get $tmp-p)
    (i32.shr_u (local.get $tmp-v) (i32.const 8)))
  (i32.store8 offset=2 (local.get $tmp-p)
    (i32.shr_u (local.get $tmp-v) (i32.const 16)))
  (i32.store8 offset=3 (local.get $tmp-p)
    (i32.shr_u (local.get $tmp-v) (i32.const 24))))
```

**Most important rule:**

- both children are evaluated once before the split stores run

## Shape 6: `i32.store align=2` becomes two halfword stores

**Pattern:**

```wat
(i32.store align=2 (local.get $p) (local.get $v))
```

**Rewritten shape:**

```wat
(block
  (local.set $tmp-p (local.get $p))
  (local.set $tmp-v (local.get $v))
  (i32.store16 (local.get $tmp-p) (local.get $tmp-v))
  (i32.store16 offset=2 (local.get $tmp-p)
    (i32.shr_u (local.get $tmp-v) (i32.const 16))))
```

## Shape 7: `f32` lowers through integer bits, not numeric conversion

**Pattern:**

```wat
(f32.load align=1 (local.get $p))
(f32.store align=1 (local.get $p) (local.get $x))
```

**Rewritten idea:**

- load side: lower as an `i32` chunked load, then `f32.reinterpret_i32`
- store side: `i32.reinterpret_f32`, then lower as an `i32` chunked store

**Why this matters:**

- the pass preserves exact bit patterns
- it is not performing a float/int conversion

## Shape 8: full-width `i64` load becomes two 32-bit halves

**Pattern:**

```wat
(i64.load align=1 (local.get $p))
```

**Rewritten idea:**

```wat
(block (result i64)
  (local.set $tmp-p (local.get $p))
  (i64.or
    (i64.extend_i32_u (lowered-32-bit-load at offset 0))
    (i64.shl
      (i64.extend_i32_u (lowered-32-bit-load at offset 4))
      (i64.const 32))))
```

**What to remember:**

- reviewed Binaryen splits 64-bit full-width access into two 32-bit chunked accesses
- it does not directly emit an eight-byte tree at i64 level

## Shape 9: full-width `f64` is the same plus reinterpret

**Pattern:**

```wat
(f64.load align=1 (local.get $p))
(f64.store align=1 (local.get $p) (local.get $x))
```

**Rewritten idea:**

- load: build i64 from two 32-bit halves, then `f64.reinterpret_i64`
- store: `i64.reinterpret_f64`, then split into two 32-bit stores

## Shape 10: narrow `i64` loads/stores still route through i32 logic

**Patterns:**

```wat
(i64.load16_s align=1 (local.get $p))
(i64.load32_u align=1 (local.get $p))
(i64.store16 align=1 (local.get $p) (local.get $v))
(i64.store32 align=1 (local.get $p) (local.get $v))
```

**Behavior:**

- narrow loads lower to the i32 helper, then extend to i64
- narrow stores wrap to i32 first, then lower through the i32 store helper

This is another reminder that the i32 helper logic is the real center of the pass.

## Shape 11: offsets are preserved, not re-associated away

**Pattern:**

```wat
(i32.load offset=100 align=1 (local.get $p))
```

**Rewritten idea:**

- first chunk uses `offset=100`
- later chunks use `101`, `102`, `103`

**Why it matters:**

- the pass preserves the address calculation through explicit offset increments
- it does not try to fold the offset into the pointer expression differently

## Shape 12: unreachable load is not dropped to nothing

**Pattern:**

```wat
(i32.load offset=100 align=1 (unreachable))
```

**Behavior:**

- Binaryen replaces the whole node with the pointer expression

In effect, the misaligned memory op disappears, but the child expression remains as the semantic carrier.

## Shape 13: unreachable store preserves both children as drops

**Pattern:**

```wat
(i32.store offset=100 align=1 (unreachable) (i32.const 8))
(i32.store offset=100 align=1 (i32.const 4) (unreachable))
```

**Behavior:**

- Binaryen replaces the store with a block that drops both pointer and value children

This is a real contract, not just a cleanup accident.

## Shape 14: things the pass does not rewrite

These are important negative shapes.

### Atomics

Not visited by the reviewed source.

### SIMD memory ops and lane ops

Not visited by the reviewed source.

### Bulk-memory ops

Not visited by the reviewed source.

### GC / table / control instructions

Not visited directly, except that the pass may wrap the current expression in a small block or sequence.

## Positive / negative / bailout summary table

| Family | Result |
| --- | --- |
| natural alignment | no-op |
| `i32.load align=1` | rewrite to four `load8_u`s |
| `i32.load align=2` | rewrite to two `load16_u`s |
| signed 16-bit load | rewrite plus explicit sign extension |
| `i32.store align=1` | rewrite to four `store8`s |
| `i32.store align=2` | rewrite to two `store16`s |
| `f32` / `f64` | integer lowering plus reinterpret |
| full-width `i64` / `f64` | two 32-bit halves |
| unreachable load/store | operand-preserving special rewrite |
| atomics / SIMD / bulk-memory | not in reviewed scope |

## What a future Starshine port must preserve

- exact single-evaluation behavior through fresh locals
- exact chunk-size selection based on alignment
- signed narrow-load repair
- float reinterpret staging
- 64-bit split/rebuild through two 32-bit halves
- offset-preserving chunk emission
- unreachable operand-preserving rewrites
- narrow scope instead of silently expanding to unrelated memory instructions

## Sources

- [`../../../raw/binaryen/2026-05-06-alignment-lowering-current-main-recheck.md`](../../../raw/binaryen/2026-05-06-alignment-lowering-current-main-recheck.md)
- [`../../../raw/research/0496-2026-05-06-alignment-lowering-current-main-recheck.md`](../../../raw/research/0496-2026-05-06-alignment-lowering-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-26-alignment-lowering-current-main-port-readiness.md`](../../../raw/binaryen/2026-04-26-alignment-lowering-current-main-port-readiness.md)
- [`../../../raw/research/0379-2026-04-26-alignment-lowering-port-readiness.md`](../../../raw/research/0379-2026-04-26-alignment-lowering-port-readiness.md)
- [`../../../raw/binaryen/2026-04-23-alignment-lowering-primary-sources.md`](../../../raw/binaryen/2026-04-23-alignment-lowering-primary-sources.md)
- [`../../../raw/research/0171-2026-04-21-alignment-lowering-binaryen-research.md`](../../../raw/research/0171-2026-04-21-alignment-lowering-binaryen-research.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/AlignmentLowering.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/alignment-lowering.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/bits.h>
