---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0221-2026-04-21-dealign-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DeAlign.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dealign.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./align-one-rewrite-surface-and-alignment-lowering-split.md
---

# `dealign` WAT shapes

This page is the beginner-friendly before/after shape catalog for Binaryen `dealign`.

## Reading rule

Every positive example on this page follows one simple rule:

- if the visited access has `align > 1`, Binaryen rewrites that alignment immediate to `1`
- nothing else about the access changes

## Positive family 1: scalar load

### Before

```wat
(i32.load align=4 (local.get $p))
```

### After

```wat
(i32.load align=1 (local.get $p))
```

## Positive family 2: scalar store

### Before

```wat
(i64.store align=8 (local.get $p) (local.get $v))
```

### After

```wat
(i64.store align=1 (local.get $p) (local.get $v))
```

## Positive family 3: float load/store

### Before

```wat
(f32.load align=4 (local.get $p))
(f64.store align=8 (local.get $p) (local.get $x))
```

### After

```wat
(f32.load align=1 (local.get $p))
(f64.store align=1 (local.get $p) (local.get $x))
```

The pass does not reinterpret or split anything here.
It only changes alignment metadata.

## Positive family 4: offset preserved

### Before

```wat
(i32.load offset=16 align=4 (local.get $p))
```

### After

```wat
(i32.load offset=16 align=1 (local.get $p))
```

This is an important beginner clue:

- `dealign` is not rewriting address arithmetic

## Positive family 5: SIMD load/store from source-confirmed scope

Conceptually, reviewed `DeAlign.cpp` also applies the same rule to:

```wat
(v128.load align=16 (local.get $p))
(v128.store align=16 (local.get $p) (local.get $v))
```

becoming:

```wat
(v128.load align=1 (local.get $p))
(v128.store align=1 (local.get $p) (local.get $v))
```

This family is source-confirmed from the implementation file.
The reviewed dedicated lit file is much more visibly scalar-focused, so keep that proof-strength distinction in mind.

## Preserved family 1: already `align=1`

### Before

```wat
(i32.load align=1 (local.get $p))
(i32.store align=1 (local.get $p) (i32.const 0))
```

### After

```wat
(i32.load align=1 (local.get $p))
(i32.store align=1 (local.get $p) (i32.const 0))
```

If the alignment is already `1`, the pass is a no-op.

## Preserved family 2: child expressions stay intact

### Before

```wat
(i32.store align=4
  (call $ptr)
  (call $value))
```

### After

```wat
(i32.store align=1
  (call $ptr)
  (call $value))
```

The pass does not duplicate or spill children.
It just weakens the alignment immediate.

## Preserved family 3: width and signedness stay intact

### Before

```wat
(i32.load16_s align=2 (local.get $p))
(i64.load32_u align=4 (local.get $p))
```

### After

```wat
(i32.load16_s align=1 (local.get $p))
(i64.load32_u align=1 (local.get $p))
```

The opcode family is preserved.
Only the alignment field changes.

## Non-goal family 1: no chunk splitting

`dealign` does **not** turn this:

```wat
(i32.load align=1 (local.get $p))
```

into several byte loads.
That is `alignment-lowering` territory, not `dealign`.

## Non-goal family 2: no address rewrite

`dealign` does **not** transform:

```wat
(i32.load offset=4 align=4 (i32.add (local.get $base) (i32.const 8)))
```

into some different pointer expression.
It simply changes `align=4` to `align=1`.

## Non-goal family 3: no atomics or bulk memory in reviewed scope

The reviewed implementation file does not directly visit atomics, `memory.copy`, `memory.fill`, `memory.init`, or other bulk-memory operations.
So do not teach this pass as an “all memory instructions” pass.

## Best short prediction rule

A memory access is a `dealign` candidate only if all of these are true:

- it is one of the visited load/store families
- its current alignment is greater than `1`
- it appears inside a defined function
- the module has a memory

If any of those fail, Binaryen leaves it alone.

## Sources

- [`../../../raw/research/0221-2026-04-21-dealign-binaryen-research.md`](../../../raw/research/0221-2026-04-21-dealign-binaryen-research.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DeAlign.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dealign.wast>
