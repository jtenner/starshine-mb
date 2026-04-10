---
kind: concept
status: supported
last_reviewed: 2026-04-09
sources:
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

## Practical Rule

- Use the native static harness for descriptor fixtures whose meaningful assertions are static validation properties.
- Keep mixed-runtime fixtures separate until their command-by-command runtime behavior is explicitly modeled.
- When a static fixture fails after the text layer is green, assume validator semantics are wrong before adding parser workarounds.

## Sources

- Archived research docs:
  [`../raw/research/0021-2026-03-22-custom-descriptor-static-text-coverage.md`](../raw/research/0021-2026-03-22-custom-descriptor-static-text-coverage.md),
  [`../raw/research/0032-2026-03-22-exact-custom-descriptor-static-harness.md`](../raw/research/0032-2026-03-22-exact-custom-descriptor-static-harness.md)
