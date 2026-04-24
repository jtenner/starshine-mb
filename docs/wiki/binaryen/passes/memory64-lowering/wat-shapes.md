---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-memory64-lowering-primary-sources.md
  - ../../../raw/research/0315-2026-04-24-memory64-lowering-primary-sources-and-starshine-followup.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./starshine-strategy.md
---

# `memory64-lowering` WAT shape catalog

This page shows the important before/after families for Binaryen's `memory64-lowering` and `table64-lowering` passes.
The examples are schematic but match the source-backed rewrite rules captured in the raw manifest.

## 1. Memory declaration lowering

Before:

```wat
(memory 0 i64 1 10)
```

After:

```wat
(memory 0 1 10)
```

The declaration change is what forces every use-site repair below.

## 2. Load address repair

Before:

```wat
(func (param $p i64) (result i32)
  (i32.load (local.get $p))
)
```

After:

```wat
(func (param $p i64) (result i32)
  (i32.load (i32.wrap_i64 (local.get $p)))
)
```

Only the address changes. The load result type remains `i32`.
The same address rule applies to other scalar loads, stores, SIMD memory ops, and atomic memory ops.

## 3. Store address repair

Before:

```wat
(func (param $p i64) (param $v i64)
  (i64.store (local.get $p) (local.get $v))
)
```

After:

```wat
(func (param $p i64) (param $v i64)
  (i64.store (i32.wrap_i64 (local.get $p)) (local.get $v))
)
```

The payload value is not narrowed. Only the memory address is narrowed.

## 4. `memory.size` result repair

Before:

```wat
(func (result i64)
  (memory.size)
)
```

After:

```wat
(func (result i64)
  (i64.extend_i32_u (memory.size))
)
```

The lowered memory32 operation produces `i32`, so Binaryen extends it back to the apparent source-level `i64` result.

## 5. `memory.grow` operand and result repair

Before:

```wat
(func (param $delta i64) (result i64)
  (memory.grow (local.get $delta))
)
```

After:

```wat
(func (param $delta i64) (result i64)
  (i64.extend_i32_u
    (memory.grow (i32.wrap_i64 (local.get $delta))))
)
```

This is the easiest size/grow shape to remember: narrow the delta before the operation, then zero-extend the result after it.

## 6. Active data offset repair

Before:

```wat
(data (i64.const 16) "abc")
```

After:

```wat
(data (i32.const 16) "abc")
```

Segment offsets are module-initialization code, so they must be lowered too.
Do not implement this pass as a function-body-only walk.

## 7. Bulk memory init/fill/copy

Before:

```wat
(func (param $dst i64) (param $src i32) (param $n i64)
  (memory.init 0 (local.get $dst) (local.get $src) (local.get $n))
)
```

After, for the positions whose source type was `i64`:

```wat
(func (param $dst i64) (param $src i32) (param $n i64)
  (memory.init 0
    (i32.wrap_i64 (local.get $dst))
    (local.get $src)
    (i32.wrap_i64 (local.get $n)))
)
```

The exact length operand width is position- and operation-dependent. The source-backed rule to carry forward is: do not assume all operands in a bulk op have the same address width.

## 8. Mixed memory copy

Before, copying from memory64 to memory32 or the reverse can have mixed operand widths:

```wat
(memory.copy $dst32 $src64
  (local.get $dst-i32)
  (local.get $src-i64)
  (local.get $len-i32))
```

After:

```wat
(memory.copy $dst32 $src32
  (local.get $dst-i32)
  (i32.wrap_i64 (local.get $src-i64))
  (local.get $len-i32))
```

When only one side is memory64, the reviewed Binaryen contract keeps the length on the smaller common index width rather than blindly making it `i64`.

## 9. Table declaration lowering

Before:

```wat
(table 0 i64 10 funcref)
```

After:

```wat
(table 0 10 funcref)
```

This shape belongs to the sibling public pass `table64-lowering`, not the memory-only pass name.

## 10. Table get/set index repair

Before:

```wat
(func (param $i i64) (result funcref)
  (table.get (local.get $i))
)
```

After:

```wat
(func (param $i i64) (result funcref)
  (table.get (i32.wrap_i64 (local.get $i)))
)
```

`table.set` has the same index repair while preserving the reference payload.

## 11. Table size/grow result repair

Before:

```wat
(func (param $init funcref) (param $delta i64) (result i64)
  (table.grow (local.get $init) (local.get $delta))
)
```

After:

```wat
(func (param $init funcref) (param $delta i64) (result i64)
  (i64.extend_i32_u
    (table.grow (local.get $init) (i32.wrap_i64 (local.get $delta))))
)
```

As with memory grow, the operand is narrowed and the result is zero-extended.

## 12. Active element offset repair

Before:

```wat
(elem (i64.const 3) func $f)
```

After:

```wat
(elem (i32.const 3) func $f)
```

This is the table sibling of active data offset repair.

## 13. Table copy mixed-width rules

Before:

```wat
(table.copy $dst64 $src32
  (local.get $dst-i64)
  (local.get $src-i32)
  (local.get $len-i32))
```

After:

```wat
(table.copy $dst32 $src32
  (i32.wrap_i64 (local.get $dst-i64))
  (local.get $src-i32)
  (local.get $len-i32))
```

The reviewed code treats the length as 64-bit only when both source and destination tables are 64-bit.
That detail is important for mixed table32/table64 cases.

## Non-goals

- This pass is not memory packing.
- This pass is not address arithmetic simplification.
- This pass is not pointer-range validation.
- This pass is not a Starshine feature today.

## Sources

- [`../../../raw/binaryen/2026-04-24-memory64-lowering-primary-sources.md`](../../../raw/binaryen/2026-04-24-memory64-lowering-primary-sources.md)
- Binaryen `memory64-lowering.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/memory64-lowering.wast>
- Binaryen `table64-lowering.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/table64-lowering.wast>
