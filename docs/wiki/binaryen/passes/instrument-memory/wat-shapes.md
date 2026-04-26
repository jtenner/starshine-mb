---
kind: concept
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-instrument-memory-current-main-port-readiness.md
  - ../../../raw/research/0388-2026-04-26-instrument-memory-port-readiness.md
  - ../../../raw/binaryen/2026-04-24-instrument-memory-primary-sources.md
  - ../../../raw/research/0288-2026-04-24-instrument-memory-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0231-2026-04-21-instrument-memory-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./helper-import-roster-filters-and-unsupported-types.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
---

# WAT shapes for `instrument-memory`

This page shows the main before/after shapes that matter for teaching the pass.
The shapes are grounded in the 2026-04-24 primary-source manifest and the 2026-04-26 current-main no-drift recheck. They remain upstream-only for Starshine today; see [`./starshine-strategy.md`](./starshine-strategy.md) for the local non-adoption status and [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md) for the future-port checklist.

## 1. Scalar load: pointer prehook plus value posthook

Before:

```wat
(drop
  (i32.load16_u offset=8
    (i32.const 0)
  )
)
```

After:

```wat
(drop
  (call $load_val_i32
    (i32.const N)
    (i32.load16_u offset=8
      (call $load_ptr
        (i32.const N)
        (i32.const 2)
        (i32.const 8)
        (i32.const 0)
      )
    )
  )
)
```

Key idea:

- the pointer is observed before the load
- the scalar value is observed after the load
- the helper sees byte width and static offset explicitly

## 2. Scalar store: pointer and value children rewritten, store stays a store

Before:

```wat
(i64.store16 offset=5 align=2
  (i32.const 0)
  (i64.const 5)
)
```

After in the same style:

```wat
(i64.store16 offset=5 align=2
  (call $store_ptr
    (i32.const N)
    (i32.const 2)
    (i32.const 5)
    (i32.const 0)
  )
  (call $store_val_i64
    (i32.const N)
    (i64.const 5)
  )
)
```

Key idea:

- the store node survives
- both meaningful children are instrumented

## 3. `memory.grow`: pre/post grow hooks

Before:

```wat
(drop
  (memory.grow
    (i32.const 4)
  )
)
```

After:

```wat
(drop
  (call $memory_grow_post
    (i32.const N)
    (memory.grow
      (call $memory_grow_pre
        (i32.const N)
        (i32.const 4)
      )
    )
  )
)
```

Key idea:

- grow uses a two-hook shape
- the delta is observed before the grow
- the grow result is observed after the grow

## 4. `struct.get`: whole scalar field read wrapped

Before:

```wat
(drop
  (struct.get $struct 1
    (local.get $x)
  )
)
```

After:

```wat
(drop
  (call $struct_get_val_f32
    (i32.const N)
    (struct.get $struct 1
      (local.get $x)
    )
  )
)
```

Key idea:

- GC field reads are supported, but only for scalar result types

## 5. `struct.set`: value child wrapped, set survives

Before:

```wat
(struct.set $struct 0
  (local.get $x)
  (i32.const 42)
)
```

After:

```wat
(struct.set $struct 0
  (local.get $x)
  (call $struct_set_val_i32
    (i32.const N)
    (i32.const 42)
  )
)
```

Key idea:

- exactly parallel to ordinary store value instrumentation

## 6. `array.get`: index hook plus value hook

Before:

```wat
(drop
  (array.get $array
    (local.get $x)
    (i32.const 10)
  )
)
```

After:

```wat
(drop
  (call $array_get_val_f64
    (i32.const N2)
    (array.get $array
      (local.get $x)
      (call $array_get_index
        (i32.const N1)
        (i32.const 10)
      )
    )
  )
)
```

Key idea:

- one source op can consume two IDs
- the index and the scalar payload are observed separately

## 7. `array.set`: index hook plus value hook

Before:

```wat
(array.set $array
  (local.get $x)
  (i32.const 42)
  (f64.const 3.14159)
)
```

After:

```wat
(array.set $array
  (local.get $x)
  (call $array_set_index
    (i32.const N1)
    (i32.const 42)
  )
  (call $array_set_val_f64
    (i32.const N2)
    (f64.const 3.14159)
  )
)
```

Key idea:

- array writes are two-hook shapes too

## 8. Filtered-out store family stays unchanged

From the dedicated filter file, a filtered run that enables only `load,memory.grow` leaves stores like this unchanged:

```wat
(i32.store16
  (i32.const 0)
  (i32.const 2)
)
```

Key idea:

- filtering is per family
- the pass can be a no-op on one instruction family even while rewriting others

## 9. Memory64 widens pointer-side helper arguments

Before in a memory64 module:

```wat
(drop
  (i32.load
    (i64.const 0)
  )
)
```

After:

```wat
(drop
  (call $load_val_i32
    (i32.const N)
    (i32.load
      (call $load_ptr
        (i32.const N)
        (i32.const 4)
        (i64.const 0)
        (i64.const 0)
      )
    )
  )
)
```

Key idea:

- pointer-like helper args widen to `i64`
- scalar observed value hooks do not change kind just because the memory address width changed

## 10. Preserved unsupported family: no generic ref-valued GC payload wrapping

A shape like this is **not** part of the documented positive surface:

```wat
(drop
  (struct.get $t 0
    (local.get $x)
  )
)
```

when field `0` is a reference type rather than `i32/i64/f32/f64`.

Key idea:

- the pass is scalar-only on GC payload values in reviewed `version_129`
- do not teach it as a universal heap tracer

## 11. Preserved unsupported family: unrelated memory ops stay as-is

Shapes like these are not instrumented by the reviewed owner file:

```wat
(memory.size)
(memory.copy
  (i32.const 0)
  (i32.const 16)
  (i32.const 8)
)
(memory.fill
  (i32.const 0)
  (i32.const 255)
  (i32.const 32)
)
```

Key idea:

- broad name, narrow real rewrite surface

## Teaching summary

If someone remembers only one visual rule, it should be this:

> `instrument-memory` usually does not replace an operation with one big tracing call; it rewrites the interesting children and/or wraps the scalar result so Binaryen can observe the original operation while still preserving its shape.

## Sources

- [`../../../raw/binaryen/2026-04-24-instrument-memory-primary-sources.md`](../../../raw/binaryen/2026-04-24-instrument-memory-primary-sources.md)
- [`../../../raw/research/0288-2026-04-24-instrument-memory-primary-sources-and-starshine-followup.md`](../../../raw/research/0288-2026-04-24-instrument-memory-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0231-2026-04-21-instrument-memory-binaryen-research.md`](../../../raw/research/0231-2026-04-21-instrument-memory-binaryen-research.md)
