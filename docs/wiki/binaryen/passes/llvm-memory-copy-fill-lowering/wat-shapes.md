---
kind: shape-catalog
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-llvm-memory-copy-fill-lowering-primary-sources.md
  - ../../../raw/research/0384-2026-04-26-llvm-memory-copy-fill-lowering-source-dossier.md
  - ../../../../../src/wast/types.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/validate/typecheck.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./helper-call-lowering-and-boundaries.md
  - ./starshine-strategy.md
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
(import "env" "...memory_copy_helper..."
  (func $__memory_copy_helper (param i32 i32 i32)))

(func (param $dst i32) (param $src i32) (param $len i32)
  (local.get $dst)
  (local.get $src)
  (local.get $len)
  (call $__memory_copy_helper))
```

Caveats:

- The helper must preserve `memory.copy` overlap behavior.
- If the target module has multiple memories, helper selection and address/memory-index semantics need a source-confirmed design.
- Starshine represents this as `MemoryCopy(MemIdx, MemIdx)` in lib IR and as `HotOp::MemoryCopy` in HOT, so a future pass must not drop the source/destination memory indices accidentally.

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
(import "env" "...memory_fill_helper..."
  (func $__memory_fill_helper (param i32 i32 i32)))

(func (param $dst i32) (param $value i32) (param $len i32)
  (local.get $dst)
  (local.get $value)
  (local.get $len)
  (call $__memory_fill_helper))
```

Caveats:

- The helper must implement the same byte-fill semantics as `memory.fill`, including truncating the value to a byte.
- The operation is a memory write and may trap; a replacement call must be treated conservatively by effect analysis unless helper effects are modeled precisely.

## Non-shape: `memory.init` and `data.drop`

Do not rewrite these under this pass:

```wat
(i32.const 0)
(i32.const 0)
(i32.const 4)
memory.init 0

data.drop 0
```

Those instructions are data-segment operations. They belong to other lowering or packing families. Starshine's data-count validation also distinguishes them from `memory.copy` / `memory.fill`: `src/validate/validate.mbt:2086-2118` flags `MemoryInit` and `DataDrop` for data-count requirements, not `MemoryCopy` or `MemoryFill`.

## Non-shape: memory layout rewrites

Do not treat this as a memory-layout pass:

```wat
(memory 1 2)
(memory 1 2)
(memory.copy 0 1)
```

Combining memories, adding offset globals, or shifting addresses belongs to [`../multi-memory-lowering/index.md`](../multi-memory-lowering/index.md), not this pass. A future Starshine port can still decide it only supports memory zero, but that is a port boundary decision, not a `memory-packing` or `multi-memory-lowering` rewrite.

## Non-shape: data segment packing

Do not treat this as a segment packing pass:

```wat
(data (i32.const 0) "abc\00\00\00")
```

Trimming, splitting, or converting data segments belongs to [`../memory-packing/index.md`](../memory-packing/index.md). `llvm-memory-copy-fill-lowering` starts from instruction operations, not from raw data segment bytes.

## Validation-oriented reduced tests for Starshine

A future local port should begin with:

1. one `memory.copy` fixture with distinct locals for destination, source, and length;
2. one `memory.fill` fixture with distinct locals for destination, value, and length;
3. one operand-order fixture where an operand can trap before the helper call;
4. one negative/no-op fixture containing `memory.init` / `data.drop` but no `memory.copy` / `memory.fill`;
5. one multi-memory fixture, either supported by source-confirmed helper semantics or explicitly rejected/skipped.
