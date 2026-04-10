---
kind: concept
status: supported
last_reviewed: 2026-04-09
sources:
  - ../raw/research/0029-2026-03-22-passive-typed-empty-elem-surface.md
  - ../raw/research/0030-2026-03-22-exact-struct-ref-equivalence.md
  - ../raw/research/0031-2026-03-22-exact-func-ref-equivalence.md
related:
  - ./static-fixtures.md
  - ../../../src/wast/passive_typed_elem_surface_test.mbt
  - ../../../src/wast/exact_type_equivalence_test.mbt
  - ../../../src/validate/match.mbt
  - ../../../src/wast/spec_harness.mbt
---

# Exact Reference Equivalence

## Durable Conclusions

- Higher-level WAST now accepts passive typed empty `elem` declarations such as `(elem (ref null $func))`, which are part of the `exact.wast` front-end surface.
- Exact reference matching no longer requires raw type-index identity.
- For exact defined struct refs, compatibility is based on full structural closure equivalence with cycle guards.
- For exact defined function refs, compatibility also compares params and results structurally instead of stopping at the outer function type index.
- Exact matching still rejects true subtype-vs-supertype distinctions; structural equivalence is not a general subtype widening rule.

## Practical Rule

- Use exact equivalence only on exact-to-exact comparison paths.
- Compare the whole reachable defined-type closure, not just the outer constructor or immediate index.
- Keep fixture harness pinning separate from the semantic rule itself; this page is the rule, while [`./static-fixtures.md`](./static-fixtures.md) is the harness policy.

## Sources

- Archived research docs:
  [`../raw/research/0029-2026-03-22-passive-typed-empty-elem-surface.md`](../raw/research/0029-2026-03-22-passive-typed-empty-elem-surface.md),
  [`../raw/research/0030-2026-03-22-exact-struct-ref-equivalence.md`](../raw/research/0030-2026-03-22-exact-struct-ref-equivalence.md),
  [`../raw/research/0031-2026-03-22-exact-func-ref-equivalence.md`](../raw/research/0031-2026-03-22-exact-func-ref-equivalence.md)
