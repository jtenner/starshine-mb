---
kind: shape-catalog
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-llvm-memory-copy-fill-lowering-primary-sources.md
  - ../../../raw/research/0384-2026-04-26-llvm-memory-copy-fill-lowering-source-dossier.md
  - ../../../raw/binaryen/2026-04-26-llvm-memory-copy-fill-lowering-port-readiness-primary-sources.md
  - ../../../raw/research/0414-2026-04-26-llvm-memory-copy-fill-lowering-port-readiness.md
  - ../../../../../src/wast/types.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/validate/typecheck.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./helper-call-lowering-and-boundaries.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
---

# WAT shapes: `llvm-memory-copy-fill-lowering`

## Positive shape: `memory.copy`

Input:

```wat
(func (param $dst i32) (param $src i32) (param $len i32)
  (local.get $dst)
  (local.get $src)
  (local.get $len)
  memory.copy)
```

Schematic output:

```wat
(func $__memory_copy (param i32 i32 i32)
  ;; generated helper body: bounds checks + overlap-aware byte loop
)

(func (param $dst i32) (param $src i32) (param $len i32)
  (local.get $dst)
  (local.get $src)
  (local.get $len)
  (call $__memory_copy))
```

Caveats:

- The helper must preserve `memory.copy` overlap behavior.
- Binaryen currently asserts the source and destination memory are the same and fatals on multi-memory; a Starshine port must not drop nonzero source/destination memory indices accidentally.
- Starshine represents this as `MemoryCopy(MemIdx, MemIdx)` in lib IR and as `HotOp::MemoryCopy` in HOT.

## Positive shape: `memory.fill`

Input:

```wat
(func (param $dst i32) (param $value i32) (param $len i32)
  (local.get $dst)
  (local.get $value)
  (local.get $len)
  memory.fill)
```

Schematic output:

```wat
(func $__memory_fill (param i32 i32 i32)
  ;; generated helper body: bounds checks + byte-store loop
)

(func (param $dst i32) (param $value i32) (param $len i32)
  (local.get $dst)
  (local.get $value)
  (local.get $len)
  (call $__memory_fill))
```

Caveats:

- The helper must implement the same byte-fill semantics as `memory.fill`, including truncating the value to a byte.
- The operation is a memory write and may trap; a replacement call must be treated conservatively by effect analysis unless helper effects are modeled precisely.

## Non-shape: `memory.init`, `data.drop`, and passive segments

Do not rewrite these under this pass:

```wat
(i32.const 0)
(i32.const 0)
(i32.const 4)
memory.init 0

data.drop 0
```

Those instructions are data-segment operations. They belong to other lowering or packing families. Starshine's data-count validation also distinguishes them from `memory.copy` / `memory.fill`: `src/validate/validate.mbt:2086-2118` flags `MemoryInit` and `DataDrop` for data-count requirements, not `MemoryCopy` or `MemoryFill`. Binaryen's pass currently fatals if passive data/element/table segments are present.

## Non-shape: memory layout rewrites

Do not treat this as a memory-layout pass:

```wat
(memory 1 2)
(memory 1 2)
(memory.copy 0 1)
```

Combining memories, adding offset globals, or shifting addresses belongs to [`../multi-memory-lowering/index.md`](../multi-memory-lowering/index.md), not this pass. Binaryen's current implementation fatals on multi-memory, so a Binaryen-compatible first Starshine slice should support memory zero only or reject the shape explicitly.

## Non-shape: data segment packing

Do not treat this as a segment packing pass:

```wat
(data (i32.const 0) "abc\00\00\00")
```

Trimming, splitting, or converting data segments belongs to [`../memory-packing/index.md`](../memory-packing/index.md). `llvm-memory-copy-fill-lowering` starts from instruction operations, not from raw data segment bytes.

## Non-shape: table bulk operations

Do not rewrite table bulk operations under this pass:

```wat
(local.get $dst)
(local.get $src)
(local.get $len)
table.copy 0 0

(local.get $dst)
(ref.null extern)
(local.get $len)
table.fill 0
```

Binaryen's owner file treats `table.copy` and `table.fill` as unsupported fatal shapes in this pass.

## Validation-oriented reduced tests for Starshine

A future local port should begin with:

1. one `memory.copy` fixture with distinct locals for destination, source, and length;
2. one `memory.fill` fixture with distinct locals for destination, value, and length;
3. one operand-order fixture where an operand can trap before the helper call;
4. one negative/no-op fixture containing `memory.init` / `data.drop` but no `memory.copy` / `memory.fill`;
5. one multi-memory fixture, explicitly rejected or preserved because upstream fatals;
6. one memory64 fixture, explicitly rejected or preserved because upstream fatals;
7. one table-bulk fixture for `table.copy` / `table.fill` non-support;
8. one feature-metadata fixture if the local implementation clears bulk-memory feature state.
