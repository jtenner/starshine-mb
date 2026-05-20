---
kind: concept
status: supported
last_reviewed: 2026-05-20
sources:
  - ../../../raw/binaryen/2026-04-26-memory64-lowering-port-readiness-primary-sources.md
  - ../../../raw/research/0411-2026-04-26-memory64-lowering-port-readiness.md
  - ../../../raw/binaryen/2026-04-25-memory64-lowering-static-offset-correction.md
  - ../../../raw/research/0374-2026-04-25-memory64-lowering-static-offset-correction.md
  - ../../../raw/binaryen/2026-04-25-memory64-lowering-current-main-recheck.md
  - ../../../raw/research/0340-2026-04-25-memory64-lowering-out-of-range-recheck.md
  - ../../../raw/binaryen/2026-04-24-memory64-lowering-primary-sources.md
  - ../../../raw/research/0315-2026-04-24-memory64-lowering-primary-sources-and-starshine-followup.md
  - ../../../raw/wasm/2026-05-20-table64-table-instruction-validation-refresh.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./static-offsets-dynamic-operands-and-grow-repair.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
---

# `memory64-lowering` WAT shape catalog

This page shows the important before/after families for Binaryen's `memory64-lowering` and `table64-lowering` passes.
The examples are schematic but match the source-backed rewrite rules captured in the raw manifest. For future Starshine implementation order and validation lanes, see [`starshine-port-readiness-and-validation.md`](starshine-port-readiness-and-validation.md).

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

Only the dynamic address changes. The load result type remains `i32`.
The same dynamic-address rule applies to other scalar loads, stores, SIMD memory ops, and atomic memory ops. The 2026-04-25 static-offset correction narrowed the older wording: an `i64.const` address expression still follows this operand-wrap path; static `offset=` immediates have their own range split below.

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

## 4. Static `offset=` range split, not arbitrary constant operands

Before, a dynamic memory64 address operand that is syntactically constant:

```wat
(i32.load (i64.const 4294967296))
```

After, the corrected source-backed shape is still operand wrapping:

```wat
(i32.load (i32.wrap_i64 (i64.const 4294967296)))
```

Before, a static memory-access immediate offset at or above `2^32`:

```wat
(i32.load offset=4294967296 (local.get $p))
```

After, Binaryen preserves the known bad access with `unreachable` rather than modulo-wrapping the static immediate:

```wat
(unreachable)
```

If the address child has side effects, those effects are preserved before the `unreachable` shape. This distinction is the main 2026-04-25 static-offset correction: dynamic operands, including `i64.const` operands, wrap; high static `offset=` immediates do not.

## 5. `memory.size` result repair

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

## 6. `memory.grow` operand and result repair

Before:

```wat
(func (param $delta i64) (result i64)
  (memory.grow (local.get $delta))
)
```

After, schematically:

```wat
(func (param $delta i64) (result i64)
  (local $old-size32 i32)
  ;; Binaryen wraps the dynamic delta for the lowered memory32 grow,
  ;; remembers the single grow result, then maps i32 grow failure back
  ;; to the wasm64 failure sentinel.
  (local.set $old-size32
    (memory.grow (i32.wrap_i64 (local.get $delta))))
  (select
    (i64.const -1)
    (i64.extend_i32_u (local.get $old-size32))
    (i32.eq (local.get $old-size32) (i32.const -1)))
)
```

The exact printed AST may use Binaryen temporaries differently; the teaching point is the failure-aware result repair. It is **not** just `i64.extend_i32_u(memory.grow(...))`, because wasm32 grow failure is `i32 -1` and wasm64 callers expect the 64-bit failure sentinel.

The 2026-04-25 correction did not find a separate constant-delta preclassification rule. Teach this as delta lowering plus failure-sentinel result repair.

## 7. Active data offset repair

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

The reviewed source lowers active offset expressions to the new address type. Do not apply the static `MemArg.offset` high-offset trap rule to active segments unless a newer source or oracle run proves that behavior.

## 8. Bulk memory init/fill/copy

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

## 9. Mixed memory copy

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

## 10. Table declaration lowering

Before:

```wat
(table 0 i64 10 funcref)
```

After:

```wat
(table 0 10 funcref)
```

This shape belongs to the sibling public pass `table64-lowering`, not the memory-only pass name.

## 11. Table get/set index repair

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

## 12. Table size/grow result repair

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

As with memory grow, the dynamic operand is narrowed and the result is repaired with the same grow-failure-sentinel rule. The simple `i64.extend_i32_u(...)` shape is sufficient for `table.size`, but not for failed `table.grow`.

## 13. Active element offset repair

Before:

```wat
(elem (i64.const 3) func $f)
```

After:

```wat
(elem (i32.const 3) func $f)
```

This is the table sibling of active data offset repair. Keep it separate from static memory-access `offset=` immediates; the reviewed source lowers active offset expressions to the new address type rather than documenting a high-active-offset `unreachable` special case.

## 14. Table fill width split

Before:

```wat
(table.fill $tab64
  (local.get $dst-i64)
  (local.get $value)
  (local.get $len-i64))
```

After:

```wat
(table.fill $tab32
  (i32.wrap_i64 (local.get $dst-i64))
  (local.get $value)
  (i32.wrap_i64 (local.get $len-i64)))
```

The official table64 rule uses the table address type for both destination and length, while the value position remains the table element reference type. Current Starshine validation is not yet a positive oracle for this shape: the 2026-05-20 table64 refresh records that the local typechecker widens the destination/start operand but still expects `len:i32`.

## 15. Table copy mixed-width rules

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
- This pass is not dynamic pointer-range validation; its source-confirmed high-address repair is for static memory-access `offset=` immediates, not arbitrary dynamic operand constants.
- This pass is not a Starshine feature today.
- Current Starshine table64 validation is not coherent enough to prove the table shapes here without prerequisite typechecker cleanup, including `table.fill` length.

## Sources

- [`../../../raw/binaryen/2026-04-26-memory64-lowering-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-26-memory64-lowering-port-readiness-primary-sources.md)
- [`../../../raw/research/0411-2026-04-26-memory64-lowering-port-readiness.md`](../../../raw/research/0411-2026-04-26-memory64-lowering-port-readiness.md)
- [`../../../raw/binaryen/2026-04-25-memory64-lowering-static-offset-correction.md`](../../../raw/binaryen/2026-04-25-memory64-lowering-static-offset-correction.md)
- [`../../../raw/research/0374-2026-04-25-memory64-lowering-static-offset-correction.md`](../../../raw/research/0374-2026-04-25-memory64-lowering-static-offset-correction.md)
- [`../../../raw/binaryen/2026-04-25-memory64-lowering-current-main-recheck.md`](../../../raw/binaryen/2026-04-25-memory64-lowering-current-main-recheck.md)
- [`../../../raw/research/0340-2026-04-25-memory64-lowering-out-of-range-recheck.md`](../../../raw/research/0340-2026-04-25-memory64-lowering-out-of-range-recheck.md)
- [`../../../raw/binaryen/2026-04-24-memory64-lowering-primary-sources.md`](../../../raw/binaryen/2026-04-24-memory64-lowering-primary-sources.md)
- [`../../../raw/wasm/2026-05-20-table64-table-instruction-validation-refresh.md`](../../../raw/wasm/2026-05-20-table64-table-instruction-validation-refresh.md)
- Binaryen `memory64-lowering.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/memory64-lowering.wast>
- Binaryen `table64-lowering.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/table64-lowering.wast>
