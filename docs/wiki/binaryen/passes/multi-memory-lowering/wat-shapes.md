---
kind: concept
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-multi-memory-lowering-port-readiness-primary-sources.md
  - ../../../raw/binaryen/2026-04-25-multi-memory-lowering-primary-sources.md
  - ../../../raw/research/0393-2026-04-26-multi-memory-lowering-port-readiness.md
  - ../../../raw/research/0370-2026-04-25-multi-memory-lowering-source-dossier.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./memory-layout-bounds-and-growth.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
---

# `multi-memory-lowering` WAT shapes

These shapes are schematic. They teach the transform surface; they are not exact Binaryen printer output.

## Positive family 1: scalar memory access

Before:

```wat
(module
  (memory $a 1)
  (memory $b 1)
  (func (param $p i32) (result i32)
    (i32.load (memory $b) (local.get $p))))
```

After:

```wat
(module
  (memory $combined 2)
  (global $b_base (mut i32) (i32.const 65536))
  (func (param $p i32) (result i32)
    (i32.load
      (i32.add (local.get $p) (global.get $b_base)))))
```

The exact offset depends on page size and previous memories' initial sizes. For a future Starshine port, this is the first body-rewrite shape to test after module memory declarations and active data offsets are repaired.

## Positive family 2: active data segment

Before:

```wat
(memory $a 1)
(memory $b 1)
(data (memory $b) (i32.const 8) "hello")
```

After:

```wat
(memory $combined 2)
(global $b_base (mut i32) (i32.const 65536))
(data (memory $combined) (i32.const 65544) "hello")
```

Binaryen's reviewed positive path is constant offsets. Non-constant active offsets are still a source TODO/assertion family.

## Positive family 3: `memory.copy`

Before:

```wat
(memory $a 1)
(memory $b 1)
(func (param $dst i32) (param $src i32) (param $len i32)
  (memory.copy $b $a
    (local.get $dst)
    (local.get $src)
    (local.get $len)))
```

After:

```wat
(memory $combined 2)
(global $b_base (mut i32) (i32.const 65536))
(func (param $dst i32) (param $src i32) (param $len i32)
  (memory.copy $combined $combined
    (i32.add (local.get $dst) (global.get $b_base))
    (local.get $src)
    (local.get $len)))
```

Both destination and source operands are repaired according to their original memory indexes.

## Positive family 4: `memory.size`

Before:

```wat
(memory $a 1)
(memory $b 2)
(func (result i32)
  (memory.size $b))
```

After:

```wat
(memory $combined 3)
(global $b_base (mut i32) (i32.const 65536))
(func $__memory_size_b (result i32)
  ;; computes virtual size for original memory $b
)
(func (result i32)
  (call $__memory_size_b))
```

The helper is required because the combined memory's total size is not the same as `$b`'s virtual size.

## Positive family 5: non-last `memory.grow`

Before:

```wat
(memory $a 1)
(memory $b 1)
(func (param $delta i32) (result i32)
  (memory.grow $a (local.get $delta)))
```

After:

```wat
(memory $combined 2)
(global $b_base (mut i32) (i32.const 65536))
(func $__memory_grow_a (param $delta i32) (result i32)
  ;; grows combined memory, moves $b upward, updates $b_base,
  ;; and returns the old virtual size for $a or -1 on failure
)
(func (param $delta i32) (result i32)
  (call $__memory_grow_a (local.get $delta)))
```

This is the easiest shape to under-document. It is why the pass is a module transform with generated helpers. It should not be the first Starshine implementation slice; prove unchecked structural lowering and last-memory helper behavior before adding byte movement for non-last growth.

## Positive family 6: checked sibling trap

Before:

```wat
(memory $a 1)
(memory $b 1)
(func (param $p i32) (result i32)
  (i32.load (memory $b) (local.get $p)))
```

After, in the checked sibling:

```wat
(func (param $p i32) (result i32)
  (if (address_outside_virtual_memory_b (local.get $p))
    (then (unreachable)))
  (i32.load
    (i32.add (local.get $p) (global.get $b_base))))
```

The checked sibling traps for out-of-virtual-memory accesses before the combined memory can accidentally expose a neighboring original memory's bytes. Keep Binaryen's source-commented effective-address overflow caveat visible; do not claim stronger checked semantics without a deliberate local divergence and tests.

## Bailout family 1: single-memory modules

Input with zero or one memory is already compatible with non-multi-memory engines. Binaryen skips the transform.

## Bailout family 2: imported or exported non-first memory

The reviewed source preserves import/export identity only through the combined first memory. Imported memories after the first and exported memories after the first are not positive shapes.

## Bailout family 3: mixed memory properties

All memories must share address type, sharedness, and page size. `multi-memory-lowering` is not the pass that reconciles memory32 with memory64 or shared with unshared memory.

## Bailout family 4: non-constant active data offset

The reviewed positive path shifts constant active data offsets. Non-constant active data offsets are still source-marked with TODO/assertion behavior and should not be advertised as supported parity until rechecked for a future Binaryen version.
