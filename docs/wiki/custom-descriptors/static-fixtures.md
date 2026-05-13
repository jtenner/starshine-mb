---
kind: concept
status: supported
last_reviewed: 2026-05-13
sources:
  - ../raw/wasm/2026-05-13-gc-type-and-custom-descriptor-sources.md
  - ../raw/research/0021-2026-03-22-custom-descriptor-static-text-coverage.md
  - ../raw/research/0032-2026-03-22-exact-custom-descriptor-static-harness.md
related:
  - ../wast/gc-type-authoring.md
  - ./exact-reference-equivalence.md
  - ./ref-get-desc-fixture-path.md
  - ../../../src/wast/spec_harness.mbt
  - ../../../src/wast/lower_to_lib.mbt
  - ../../../src/validate/env.mbt
  - ../../../src/validate/match.mbt
---

# Custom-Descriptor Static Fixtures

## Durable Conclusions

- `tests/spec/proposals/custom-descriptors/descriptors.wast` is a committed native static-harness fixture.
- `tests/spec/proposals/custom-descriptors/exact.wast` is also pinned on the native static path.
- These static fixtures are separate from the mixed-runtime `ref_get_desc.wast` path.
- Lifting `descriptors.wast` exposed real validator issues, not just text-surface gaps:
  - recursive-group absolute index resolution,
  - final-type supertype reachability,
  - struct trailing-field subtyping.
- Higher-level lowering tests now cover descriptor subtype chains in ordinary `src/wast` coverage in addition to the spec harness.
- The 2026-05-13 primary-source refresh records a live caveat: the custom-descriptors proposal currently restricts `describes` / `descriptor` clauses to struct type definitions, while Starshine's generic `TypeDefMetadata` plus WAST lowering tests also allow descriptor metadata on array type definitions. Treat that array surface as local compatibility/proposal-tracking evidence, not as upstream proposal acceptance.

## Practical Rule

- Use the native static harness for descriptor fixtures whose meaningful assertions are static validation properties.
- Keep mixed-runtime fixtures separate until their command-by-command runtime behavior is explicitly modeled.
- When a static fixture fails after the text layer is green, assume validator semantics are wrong before adding parser workarounds.
- If a fixture relies on descriptor metadata outside struct definitions, cite [`../wast/gc-type-authoring.md`](../wast/gc-type-authoring.md) and keep the proposal-vs-local caveat explicit.

## Sources

- Current primary-source snapshot: [`../raw/wasm/2026-05-13-gc-type-and-custom-descriptor-sources.md`](../raw/wasm/2026-05-13-gc-type-and-custom-descriptor-sources.md)
- Archived research docs:
  [`../raw/research/0021-2026-03-22-custom-descriptor-static-text-coverage.md`](../raw/research/0021-2026-03-22-custom-descriptor-static-text-coverage.md),
  [`../raw/research/0032-2026-03-22-exact-custom-descriptor-static-harness.md`](../raw/research/0032-2026-03-22-exact-custom-descriptor-static-harness.md)
