---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-dealign-primary-sources.md
  - ../../../raw/research/0317-2026-04-24-dealign-primary-sources-and-starshine-followup.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DeAlign.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dealign.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./align-one-rewrite-surface-and-alignment-lowering-split.md
  - ./starshine-strategy.md
supersedes:
  - ../../../raw/research/0221-2026-04-21-dealign-binaryen-research.md
---

# `dealign` WAT shapes

This page is the beginner-friendly before/after shape catalog for Binaryen `dealign`.

## Reading rule

For every covered access node, Binaryen sets the alignment immediate to `1` and leaves the rest of the node alone.

The reviewed source-backed node families are:

- scalar `Load`
- scalar `Store`
- `SIMDLoad`

The reviewed source does not contain a `SIMDStore` visitor.

## Positive family 1: scalar load

### Before

```wat
(i32.load align=4 (local.get $p))
```

### After

```wat
(i32.load align=1 (local.get $p))
```

This is the most important shape: same load, weaker alignment metadata.

## Positive family 2: scalar store

### Before

```wat
(i32.store align=4 (local.get $p) (local.get $v))
```

### After

```wat
(i32.store align=1 (local.get $p) (local.get $v))
```

The store address child and value child are preserved.

## Positive family 3: explicit `align=2` becomes `align=1`

### Before

```wat
(i32.load align=2 (local.get $p))
(i32.store align=2 (local.get $p) (i32.const 0))
```

### After

```wat
(i32.load align=1 (local.get $p))
(i32.store align=1 (local.get $p) (i32.const 0))
```

This family is directly visible in the dedicated lit file.

## Positive family 4: offset preserved

### Before

```wat
(i32.load offset=16 align=4 (local.get $p))
```

### After

```wat
(i32.load offset=16 align=1 (local.get $p))
```

`dealign` does not rewrite address arithmetic or offsets.

## Positive family 5: source-confirmed `SIMDLoad`

Reviewed `DeAlign.cpp` also visits `SIMDLoad`, so the conceptual shape is:

### Before

```wat
(v128.load align=16 (local.get $p))
```

### After

```wat
(v128.load align=1 (local.get $p))
```

This is source-confirmed from the implementation. The reviewed dedicated lit file does not visibly isolate this family.

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

The implementation still assigns `1`; the output is unchanged because the assignment is idempotent.

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

The pass does not duplicate, spill, or reorder child expressions.

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

These are source-derived examples from the generic `Load` visitor. They are useful for port planning, but the dedicated lit file's visible proof is narrower.

## Non-goal family 1: no chunk splitting

`dealign` does **not** turn this:

```wat
(i32.load align=1 (local.get $p))
```

into several byte loads. That is [`alignment-lowering`](../alignment-lowering/index.md) territory, not `dealign`.

## Non-goal family 2: no address rewrite

`dealign` does **not** transform:

```wat
(i32.load offset=4 align=4 (i32.add (local.get $base) (i32.const 8)))
```

into a different pointer expression. It only changes `align=4` to `align=1`.

## Non-goal family 3: no `SIMDStore` in reviewed source

Do not teach this as a `v128.store` pass unless a future source review finds a `SIMDStore` visitor.

## Non-goal family 4: no atomics or bulk memory in reviewed scope

The reviewed implementation file does not directly visit atomics, `memory.copy`, `memory.fill`, `memory.init`, `data.drop`, or other bulk-memory operations.

## Best short prediction rule

A memory access is a `dealign` candidate when it is one of the source-backed visited families:

- `Load`
- `Store`
- `SIMDLoad`

If so, its printed alignment should become `1`; otherwise the pass has no direct reviewed rewrite for it.

## Sources

- [`../../../raw/binaryen/2026-04-24-dealign-primary-sources.md`](../../../raw/binaryen/2026-04-24-dealign-primary-sources.md)
- [`../../../raw/research/0317-2026-04-24-dealign-primary-sources-and-starshine-followup.md`](../../../raw/research/0317-2026-04-24-dealign-primary-sources-and-starshine-followup.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DeAlign.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dealign.wast>
