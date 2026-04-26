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
  - ./memory-layout-bounds-and-growth.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
---

# `multi-memory-lowering` implementation structure and tests

## Owner files

### `src/passes/MultiMemoryLowering.cpp`

This is the implementation owner for both public pass names:

- `multi-memory-lowering`
- `multi-memory-lowering-with-bounds-checks`

The file contains:

- the pass-level explanation and caveats;
- `MultiMemoryLowering` state for the combined memory, original memory offsets, helper functions, and bounds-check mode;
- nested `Replacer`, which performs instruction-level retargeting;
- module-preparation helpers for combined-memory legality and layout;
- active data segment rewrite logic;
- generated `memory.size` helpers;
- generated `memory.grow` helpers;
- the `run(...)` orchestration;
- factory functions for checked and unchecked modes.

### `src/passes/pass.cpp`

The public registrations live here. The registration text is important because it confirms both names are intended public pass surface, not internal-only helpers.

### `src/passes/passes.h`

The constructor declarations keep both siblings in the public pass-constructor roster.

## Official Binaryen lit files

### `test/lit/passes/multi-memory-lowering.wast`

This is the main unchecked proof surface. It exercises the one-combined-memory output and proves the main rewrite families:

- memory declaration consolidation;
- offset global creation;
- active data segment retargeting;
- load/store address shifting;
- bulk-memory retargeting;
- `memory.size` helper calls;
- `memory.grow` helper behavior;
- memory export repair;
- MultiMemory feature removal.

### `test/lit/passes/multi-memory-lowering-with-bounds-checks.wast`

This is the checked-sibling proof surface. It exercises the same lowering family with explicit trap checks around virtual original-memory bounds.

## Test evidence boundaries

The official lit files are broad, but they should not be overread as proving every possible module shape. The source itself preserves these important boundaries:

- modules with zero or one memory are skipped;
- imported memories after the first are not supported positives;
- exported memories after the first are not supported positives;
- mismatched address type, sharedness, or page size is outside the accepted family;
- active data segments with non-constant offsets still sit behind a TODO/assertion path;
- the checked variant has a source-commented overflow-imprecision caveat.

## Source-backed relation to neighboring passes

- [`../memory64-lowering/index.md`](../memory64-lowering/index.md) lowers address width from 64-bit to 32-bit. `multi-memory-lowering` lowers memory count from many memories to one memory.
- [`../memory-packing/index.md`](../memory-packing/index.md) is a size optimization for data layout; it does not preserve separate virtual memories through offset globals and grow helpers.
- [`../remove-unused-module-elements/index.md`](../remove-unused-module-elements/index.md) can remove unused memories and data segments; it does not merge still-live memories into one.

## Starshine test gap

Starshine has no local test surface for this pass today because no local registry entry exists. Future local tests should mirror the official lit split, but the 2026-04-26 port-readiness pass recommends a narrower order:

- request behavior while the pass remains unknown or boundary-only;
- unchecked two-memory structural lowering fixtures;
- active-data and scalar/bulk body rewrite fixtures;
- `memory.size` and `memory.grow` helper fixtures;
- non-last grow movement fixtures;
- checked lowering fixtures;
- unsupported module-shape diagnostics or explicit unsupported-status tests;
- WAT frontend tests if named/indexed multi-memory syntax is added before the pass.

See [`starshine-port-readiness-and-validation.md`](starshine-port-readiness-and-validation.md) for the full validation ladder.
