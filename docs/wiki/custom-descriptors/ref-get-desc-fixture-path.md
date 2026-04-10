---
kind: concept
status: supported
last_reviewed: 2026-04-09
sources:
  - ../raw/research/0022-2026-03-22-ref-get-desc-type-immediate.md
  - ../raw/research/0023-2026-03-22-wast-legacy-gc-ref-aliases.md
  - ../raw/research/0024-2026-03-22-wast-struct-get-surface.md
  - ../raw/research/0025-2026-03-22-wast-global-import-exact-ref-types.md
  - ../raw/research/0026-2026-03-22-wast-rec-group-flat-type-indices.md
  - ../raw/research/0027-2026-03-22-exact-ref-null-immediates.md
  - ../raw/research/0028-2026-03-22-ref-get-desc-bottom-null-operands.md
related:
  - ../wast/gc-type-authoring.md
  - ./static-fixtures.md
  - ../../../src/wast/parser.mbt
  - ../../../src/wast/legacy_gc_aliases_test.mbt
  - ../../../src/wast/struct_get_surface_test.mbt
  - ../../../src/wast/global_import_ref_type_test.mbt
  - ../../../src/wast/ref_null_exact_surface_test.mbt
  - ../../../src/validate/env.mbt
  - ../../../src/validate/match.mbt
  - ../../../src/lib/types.mbt
---

# `ref_get_desc.wast` Fixture Path

## Durable Conclusions

- `ref.get_desc` carries an inspected type immediate end to end through WAST, lib, binary, and validation layers.
- Higher-level WAST compatibility for the fixture now includes:
  - legacy GC aliases like `anyref`, `eqref`, `structref`, and `arrayref`,
  - folded `struct.get`, `struct.get_s`, and `struct.get_u`,
  - imported globals with parenthesized exact typed refs,
  - flat implicit functype indexing after grouped `rec` entries.
- `ref.null` preserves a full `RefType` immediate, so exact nullable refs survive lowering and binary roundtrip.
- `ref.get_desc` accepts bottom-null operands when they are subtype-compatible with the inspected target:
  - `none` for defined struct and array refs,
  - `nofunc` for defined function refs.
- Descriptor results stay exact only for exact-compatible operands, even after the bottom-null compatibility fix.
- The mixed-runtime `ref_get_desc.wast` static path is now green on the native harness.

## Practical Rule

- Treat the fixture as a full-stack compatibility path, not just a parser issue. Text surface, lowering, type matching, and descriptor-result typing all need to agree.
- Preserve exactness only when the operand really justifies it; permissive operand acceptance is not the same as widening exact descriptor results.

## Sources

- Archived research docs:
  [`../raw/research/0022-2026-03-22-ref-get-desc-type-immediate.md`](../raw/research/0022-2026-03-22-ref-get-desc-type-immediate.md),
  [`../raw/research/0023-2026-03-22-wast-legacy-gc-ref-aliases.md`](../raw/research/0023-2026-03-22-wast-legacy-gc-ref-aliases.md),
  [`../raw/research/0024-2026-03-22-wast-struct-get-surface.md`](../raw/research/0024-2026-03-22-wast-struct-get-surface.md),
  [`../raw/research/0025-2026-03-22-wast-global-import-exact-ref-types.md`](../raw/research/0025-2026-03-22-wast-global-import-exact-ref-types.md),
  [`../raw/research/0026-2026-03-22-wast-rec-group-flat-type-indices.md`](../raw/research/0026-2026-03-22-wast-rec-group-flat-type-indices.md),
  [`../raw/research/0027-2026-03-22-exact-ref-null-immediates.md`](../raw/research/0027-2026-03-22-exact-ref-null-immediates.md),
  [`../raw/research/0028-2026-03-22-ref-get-desc-bottom-null-operands.md`](../raw/research/0028-2026-03-22-ref-get-desc-bottom-null-operands.md)
