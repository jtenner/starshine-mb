---
kind: concept
status: supported
last_reviewed: 2026-04-09
sources:
  - ../raw/research/0018-2026-03-22-wast-struct-type-surface.md
  - ../raw/research/0019-2026-03-22-wast-array-type-surface.md
  - ../raw/research/0020-2026-03-22-wast-rec-group-surface.md
  - ../raw/research/0026-2026-03-22-wast-rec-group-flat-type-indices.md
related:
  - ../custom-descriptors/static-fixtures.md
  - ../../../src/wast/parser.mbt
  - ../../../src/wast/module_wast.mbt
  - ../../../src/wast/lower_to_lib.mbt
  - ../../../src/wast/rec_group_typeuse_test.mbt
---

# Higher-Level WAST GC Type Authoring

## Durable Conclusions

- Higher-level `src/wast` now authors GC type definitions directly instead of forcing binary-only coverage.
- Supported type bodies are `func`, `struct`, and `array`.
- Supported type headers include bare bodies, `sub`, `final`, named or numeric supertypes, `descriptor`, and `describes`.
- `(rec ...)` groups are preserved as first-class grouped fields in the AST and roundtrip back to normalized text.
- `describes` must appear before `descriptor` in a type header; the parser rejects the reversed order instead of silently normalizing it.
- Lowering uses the flat explicit type index space even when grouped `rec` entries are present.
- Implicit function types synthesized from inline signatures append after the flattened subtype count, not after the raw number of `rec` containers.

## Current Scope

- `struct` fields preserve mutability, packed storage, and reference nullability.
- `array` element storage preserves packed-vs-value encoding and mutability.
- Empty and singleton `rec` groups remain textually distinct.
- Printed GC type definitions roundtrip through the same higher-level parser.

## Practical Rule

- Future GC/custom-descriptor fixture lifts should extend this higher-level text path instead of adding ad hoc binary-only detours.
- Treat grouped `rec` structure and flat type numbering as separate invariants: preserve grouping in the AST, but resolve later type uses through the flattened subtype space.

## Sources

- Archived research docs:
  [`../raw/research/0018-2026-03-22-wast-struct-type-surface.md`](../raw/research/0018-2026-03-22-wast-struct-type-surface.md),
  [`../raw/research/0019-2026-03-22-wast-array-type-surface.md`](../raw/research/0019-2026-03-22-wast-array-type-surface.md),
  [`../raw/research/0020-2026-03-22-wast-rec-group-surface.md`](../raw/research/0020-2026-03-22-wast-rec-group-surface.md),
  [`../raw/research/0026-2026-03-22-wast-rec-group-flat-type-indices.md`](../raw/research/0026-2026-03-22-wast-rec-group-flat-type-indices.md)
