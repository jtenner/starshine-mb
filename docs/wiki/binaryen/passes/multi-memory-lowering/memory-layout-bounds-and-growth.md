---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-multi-memory-lowering-primary-sources.md
  - ../../../raw/research/0370-2026-04-25-multi-memory-lowering-source-dossier.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
---

# Memory layout, bounds, and growth in `multi-memory-lowering`

## Why the pass is harder than address shifting

It is tempting to describe `multi-memory-lowering` as:

> replace memory index `N` with memory `0` and add a constant offset.

That is only the easiest case. The real pass must preserve the illusion that separate memories still exist after the output has one combined memory.

Three details make it nontrivial:

1. original memories can grow independently;
2. accesses to one original memory must not silently access a different original memory's range;
3. active data segments initialize memories before any function-body instruction runs.

## Layout model

Binaryen lays original memories out consecutively inside one combined memory:

```wat
;; conceptual layout, not exact emitted WAT
combined memory bytes:
  [original memory 0][original memory 1][original memory 2]...
```

Memory `0` starts at byte offset `0`. Each later original memory gets a mutable offset global storing its current byte base.

A load from memory `2` conceptually changes from:

```wat
(i32.load (memory 2) $addr)
```

to:

```wat
(i32.load
  (i32.add $addr (global.get $memory_2_base)))
```

The exact emitted names are Binaryen-generated, but the shape is the important contract.

## `memory.size`

`memory.size` needs a helper because the combined memory's total size is not the same as the virtual size of each original memory.

For a middle memory, the virtual size is derived from adjacent base offsets. For the last memory, it depends on the combined memory's current size minus that memory's base offset.

This is why `memory.size (memory 1)` does not lower to plain `memory.size 0`.

## `memory.grow`

`memory.grow` is the hardest family.

If the last original memory grows, the combined memory can grow and that memory's virtual range extends at the end.

If a non-last original memory grows, Binaryen must:

1. grow the combined memory;
2. move all later memory ranges upward with `memory.copy`;
3. update offset globals for later memories;
4. preserve the return behavior expected by the original `memory.grow` instruction.

Without that movement, growing original memory `1` would overlap or overwrite bytes that belong to original memory `2`.

## Bounds-checking sibling

Unchecked lowering can make an out-of-bounds access for one original memory land inside another original memory's range in the combined memory.

The checked sibling inserts explicit trap checks so a lowered access stays within the selected original memory's virtual data length.

Keep the source caveat visible: Binaryen's owner-file comments record that these checks still do not perfectly model every effective-address overflow case. The sibling is bounds-checking support, not a proof that all trap behavior is bit-for-bit identical for every overflow edge.

## Active data segments

Active data segment offsets are initialization-time addresses, so the pass has to retarget them too.

Binaryen's reviewed positive path handles constant active offsets:

```wat
(data (memory 1) (i32.const 16) "...")
```

becomes conceptually:

```wat
(data (memory 0) (i32.const memory_1_base_plus_16) "...")
```

Non-constant active offsets are not a source-confirmed positive case in `version_129`; the owner file still records a TODO/assertion there.

## Practical teaching rule

When explaining this pass, start from the combined-memory layout, then explain instruction retargeting. If readers start with instruction retargeting alone, they will miss why `memory.size`, `memory.grow`, active data segments, and optional bounds checks are central rather than incidental.
