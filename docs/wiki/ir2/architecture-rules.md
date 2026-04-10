---
kind: concept
status: supported
last_reviewed: 2026-04-09
sources:
  - ../../0059-2026-03-24-ir2-architecture-rules.md
related:
  - ./cfg-contract.md
  - ./local-ssa-policy.md
  - ./execution-plan.md
  - ../../../src/ir/README.md
  - ../../../src/ir/architecture.mbt
---

# IR2 Architecture Rules

## Durable Conclusions

- `HotFunc` is the only owned optimizer body representation.
- Boundary decode, encode, validation, printing, and debug stay on raw `@lib.Module` / `@lib.Expr` forms.
- CFG, dominance, post-dominance, liveness, use-def, effects, loop info, and SSA are revision-keyed overlays, not alternate owned IR layers.
- The pass contract is `lift -> verify -> analyze -> mutate -> verify -> lower`.
- Semantic mutation must go through the public hot-IR mutation surface and bump `revision`.
- Deleted recursive optimizer-body compatibility layers must not return.

## Current Module Map Rule

- Grow `src/ir` through dedicated modules such as `architecture`, `hot_core`, `hot_mutate`, `hot_query`, and the analysis/cache slices instead of rebuilding one large monolithic file.
- Treat `hot.mbt` as a compatibility-free facade over the split modules, not as permission to re-centralize ownership or analysis logic there.

## Practical Rule

- The numbered doc in `docs/` remains the canonical normative architecture ADR; keep this page synchronized with it.
- Land architecture rules before landing a pass that needs a new IR invariant, cache rule, or mutation contract.
- Keep pass descriptors honest about required analyses and invalidations.
- Public docs must not imply that deleted ownership layers still exist.

## Sources

- Canonical normative doc: [`../../0059-2026-03-24-ir2-architecture-rules.md`](../../0059-2026-03-24-ir2-architecture-rules.md)
- Package-local ownership summary: [`../../../src/ir/README.md`](../../../src/ir/README.md)
