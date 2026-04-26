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
  - ./helper-import-roster-filters-and-unsupported-types.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
---

# Implementation structure and test map for `instrument-memory`

## Core upstream implementation files

## `src/passes/InstrumentMemory.cpp`

This is the real pass.
It contains all major pieces:

- fixed helper-import names
- the optional string-set filter type
- the postwalk rewriter
- all rewrite visitors
- module-level helper import injection
- the public pass object with `addsEffects() == true`

If you want the true contract, read this file first.

## `src/passes/pass.cpp`

This file proves two separate facts:

1. the public pass name is **`instrument-memory`**
2. it is a public pass, but not part of the default optimization pipeline

It also exposes a small wording caveat:

- the help string says "intercept all loads and stores"
- the owner file plus lit tests prove the actual surface is wider

## Owner-file substructure that matters

Inside `InstrumentMemory.cpp`, the implementation is compact but still has clear ownership splits.

### Helper-name declarations

These anchor the actual imported API surface:

- scalar memory helpers
- grow helpers
- GC struct helpers
- GC array helpers

### `InstructionFilter` + `CHECK_EXPRESSION(...)`

These define the exact filter contract and the per-visitor early-return boundary.

### `AddInstrumentation`

This is the real transformer.
It owns every actual rewrite.

### `visitModule`

This owns helper import injection and the GC-conditional extra roster.

### `InstrumentMemory : Pass`

This owns pass-argument parsing and the explicit effects declaration.

## What the official tests each prove

## `test/lit/passes/instrument-memory.wast`

This is the main scalar-memory proof file.
It demonstrates:

- scalar load families across widths and sign modes
- scalar store families
- helper import injection
- byte-count payloads passed to `load_ptr` / `store_ptr`
- static memarg offsets passed as explicit helper arguments

This file is the main proof that the pass is more than just "wrap the whole load/store in one helper".
It shows the separate pointer and value hook structure.

## `test/lit/passes/instrument-memory-filter.wast`

This is the exact filter-contract file.
It proves:

- the pass argument uses a comma-separated string set
- `load` can be enabled independently
- `memory.grow` can be enabled independently
- filtered-out `store` operations stay unchanged
- helper imports are still present even when stores are filtered out

This file is essential because the filter behavior is not a vague user-interface extra; it changes the observable rewrite surface.

## `test/lit/passes/instrument-memory-gc.wast`

This file proves the GC extension.
It demonstrates:

- `struct.get` scalar wrapping
- `struct.set` scalar-value wrapping
- `array.get` index wrapping plus scalar-value wrapping
- `array.set` index wrapping plus scalar-value wrapping
- the GC-only helper import roster

This is the clearest official source for the fact that the pass is not limited to linear memory.

## `test/lit/passes/instrument-memory64.wast`

This file proves the address-width-sensitive variant.
It demonstrates:

- memory64 helper signatures using `i64` address-like params
- `i64.const` offset/address literals in helper arguments
- unchanged scalar result hooks for `i32` / `i64` / `f32` / `f64` payloads

This file keeps future ports from hardcoding `i32` pointer assumptions.

## Practical reading order

If you are new to the pass, read the upstream sources in this order:

1. `test/lit/passes/instrument-memory.wast`
2. `src/passes/InstrumentMemory.cpp`
3. `test/lit/passes/instrument-memory-filter.wast`
4. `test/lit/passes/instrument-memory-gc.wast`
5. `test/lit/passes/instrument-memory64.wast`
6. `src/passes/pass.cpp`

Why this order helps:

- first learn the visible scalar rewrite pattern
- then learn the compact owner file
- then learn the optional filter contract
- then learn the GC extension and memory64 variant
- then anchor public registration and the help-text caveat

## Release provenance and current-main spot check

The raw primary-source manifest anchors this page to the official Binaryen `version_129` release page, which was reviewed on 2026-04-24 and showed publish date **2026-04-01 14:31**.

A focused 2026-04-26 current-`main` recheck of `InstrumentMemory.cpp`, `pass.cpp`, `passes.h`, and the four dedicated lit files did not surface teaching-relevant contract drift beyond the tagged `version_129` claims.
That means the tagged sources remain the preferred teaching oracle for this dossier, with the caveat that the recheck was not a full upstream history audit.

## Beginner checklist

When reading a future Starshine port, verify these concrete pieces exist:

- a public pass identity distinct from preset optimization passes
- one postwalk owner for the rewrites
- `load_ptr` / `store_ptr` child rewriting, not only outer wrappers
- typed `load_val_*` / `store_val_*` scalar hooks
- `memory_grow_pre` / `memory_grow_post` split
- GC struct/array support only under GC
- exact filter-string handling
- memory64 address-type sensitivity
- effect invalidation
- preserved unsupported families rather than silently widened instrumentation

If any one of those is missing, the port is not really implementing the Binaryen pass contract.
The current local status page, [`./starshine-strategy.md`](./starshine-strategy.md), explains why Starshine does not have such a port today and which local registry / IR files a future implementation should read first. The companion readiness page, [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md), gives the recommended first-slice and validation order.

## Sources

- [`../../../raw/binaryen/2026-04-26-instrument-memory-current-main-port-readiness.md`](../../../raw/binaryen/2026-04-26-instrument-memory-current-main-port-readiness.md)
- [`../../../raw/research/0388-2026-04-26-instrument-memory-port-readiness.md`](../../../raw/research/0388-2026-04-26-instrument-memory-port-readiness.md)
- [`../../../raw/binaryen/2026-04-24-instrument-memory-primary-sources.md`](../../../raw/binaryen/2026-04-24-instrument-memory-primary-sources.md)
- [`../../../raw/research/0288-2026-04-24-instrument-memory-primary-sources-and-starshine-followup.md`](../../../raw/research/0288-2026-04-24-instrument-memory-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0231-2026-04-21-instrument-memory-binaryen-research.md`](../../../raw/research/0231-2026-04-21-instrument-memory-binaryen-research.md)
