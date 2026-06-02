---
kind: concept
status: supported
last_reviewed: 2026-06-02
sources:
  - ../../../raw/binaryen/2026-06-02-remove-unused-version-130-current-main-recheck.md
  - ../../../raw/binaryen/2026-05-06-remove-unused-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-27-remove-unused-port-readiness-primary-sources.md
  - ../../../raw/binaryen/2026-04-25-remove-unused-primary-sources.md
  - ../../../raw/research/0494-2026-05-06-remove-unused-shape-catalog-and-current-main-recheck.md
  - ../../../raw/research/0420-2026-04-27-remove-unused-port-readiness.md
  - ../../../raw/research/0339-2026-04-25-remove-unused-source-bridge.md
  - ../../../raw/research/0195-2026-04-21-remove-unused-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./historical-lineage-and-modern-supersession.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../remove-unused-module-elements/index.md
---

# `remove-unused` module shapes

This page is the canonical shape catalog for local `remove-unused`.

Because this dossier is about a historical upstream pass lineage, the examples are intentionally simple and stay separate from modern `remove-unused-module-elements`.

## Reading rule

When this page says “the pass rewrites,” it means the **historical** upstream `remove-unused-functions` behavior, not modern `remove-unused-module-elements`. For Starshine implementation choices and tests derived from these shapes, see [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

The 2026-06-02 version_130 / current-main recheck confirmed the same lineage story: current Binaryen still exposes the modern module-element cleanup names, not this short alias.

## Positive shape 1: dead private helper with no roots and no callers

### Before

```wat
(module
  (func $live)
  (func $dead)
  (export "live" (func $live))
)
```

### After, historically

```wat
(module
  (func $live)
  (export "live" (func $live))
)
```

### Why

- `$live` is rooted by export
- `$dead` is not rooted and not reachable by direct call

## Positive shape 2: dead helper reachable from a rooted function stays

### Before

```wat
(module
  (func $helper)
  (func $live
    (call $helper)
  )
  (export "live" (func $live))
)
```

### After

```wat
(module
  (func $helper)
  (func $live
    (call $helper)
  )
  (export "live" (func $live))
)
```

### Why

- export roots `$live`
- direct-call reachability marks `$helper` live too

## Positive shape 3: start-rooted function stays

### Before

```wat
(module
  (func $boot)
  (func $dead)
  (start $boot)
)
```

### After

```wat
(module
  (func $boot)
  (start $boot)
)
```

### Why

- start roots `$boot`
- `$dead` is still unreachable

## Positive shape 4: table-segment functions stay conservatively

### Before

```wat
(module
  (table 1 funcref)
  (elem (i32.const 0) func $maybe_indirect)
  (func $maybe_indirect)
  (func $dead)
)
```

### After, historically

```wat
(module
  (table 1 funcref)
  (elem (i32.const 0) func $maybe_indirect)
  (func $maybe_indirect)
)
```

### Why

The old pass rooted every function named in a table segment.
It did not try to prove whether an indirect call would actually happen.

## Negative shape 1: non-function declarations were out of scope

### Before

```wat
(module
  (memory 1)
  (data (i32.const 0) "x")
  (func $live)
  (export "live" (func $live))
)
```

### After, historically

```wat
(module
  (memory 1)
  (data (i32.const 0) "x")
  (func $live)
  (export "live" (func $live))
)
```

### Why

Historical `remove-unused-functions` did not touch memories or data segments.

This is one of the clearest differences from modern RUME.

## Negative shape 2: function-type cleanup was out of scope

If dead function deletion left behind type-section cleanup opportunities, the old pass did not own that broader module-compaction story.

Modern `remove-unused-module-elements` does.

## Negative shape 3: no non-function weakening/nullification

Modern RUME sometimes preserves a declaration but weakens or nulls the payload that points at dead things.
The historical function-only pass had no equivalent surface.

## Negative shape 4: ordinary function bodies stay untouched

Before:

```wat
(module
  (global $a i32 (i32.const 10))

  (func $use (result i32)
    (global.get $a)
  )
)
```

After, historically:

```wat
(module
  (global $a i32 (i32.const 10))

  (func $use (result i32)
    (global.get $a)
  )
)
```

### Why

The old pass did not walk ordinary function bodies. It only followed the direct-call closure from rooted functions.

## Comparison table: old pass versus modern RUME

| Family | Historical `remove-unused-functions` | Modern `remove-unused-module-elements` |
| --- | --- | --- |
| Dead functions | Yes | Yes |
| Start/export roots | Yes | Yes |
| Table-element conservative roots | Yes | Yes, but inside a broader module-element graph |
| Dead globals/tables/memories/tags | No | Yes |
| Dead elem/data segments | No | Yes |
| Function-type cleanup | No | Yes |
| Reference-only root weakening | No | Yes |
| Non-function payload nullification/weakening | No | Yes |

## Starshine caveat

Current Starshine does **not** apply these historical rewrites for `remove-unused`. The local name is boundary-only and rejects active requests. Use [`./starshine-strategy.md`](./starshine-strategy.md) for the local status and [`../remove-unused-module-elements/index.md`](../remove-unused-module-elements/index.md) for the implemented modern module-element cleanup pass.

## Best beginner summary

If someone remembers only one thing from this page, it should be this:

> Historical upstream `remove-unused-functions` only removed unreachable functions, while modern `remove-unused-module-elements` is a much broader declaration-graph cleanup pass.

## Sources

- [`../../../raw/binaryen/2026-05-06-remove-unused-current-main-recheck.md`](../../../raw/binaryen/2026-05-06-remove-unused-current-main-recheck.md)
- [`../../../raw/binaryen/2026-06-02-remove-unused-version-130-current-main-recheck.md`](../../../raw/binaryen/2026-06-02-remove-unused-version-130-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-27-remove-unused-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-27-remove-unused-port-readiness-primary-sources.md)
- [`../../../raw/binaryen/2026-04-25-remove-unused-primary-sources.md`](../../../raw/binaryen/2026-04-25-remove-unused-primary-sources.md)
- [`../../../raw/research/0494-2026-05-06-remove-unused-shape-catalog-and-current-main-recheck.md`](../../../raw/research/0494-2026-05-06-remove-unused-shape-catalog-and-current-main-recheck.md)
- [`../../../raw/research/0420-2026-04-27-remove-unused-port-readiness.md`](../../../raw/research/0420-2026-04-27-remove-unused-port-readiness.md)
- [`../../../raw/research/0339-2026-04-25-remove-unused-source-bridge.md`](../../../raw/research/0339-2026-04-25-remove-unused-source-bridge.md)
- [`../../../raw/research/0195-2026-04-21-remove-unused-binaryen-research.md`](../../../raw/research/0195-2026-04-21-remove-unused-binaryen-research.md)
- <https://github.com/WebAssembly/binaryen/blob/5881b541a4b276dcd5576aa065e4fb860531fc7b/src/passes/RemoveUnusedFunctions.cpp>
- <https://github.com/WebAssembly/binaryen/blob/98e9e604c7e2e4f928abe8f05691df90cddf09e4/src/passes/RemoveUnusedModuleElements.cpp>
