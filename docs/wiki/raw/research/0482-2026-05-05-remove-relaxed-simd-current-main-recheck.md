# Research 0482: 2026-05-05 remove-relaxed-simd current-main recheck

## Question

Does Binaryen `remove-relaxed-simd` still match the existing dossier contract on current `main`, and do the Starshine pages need any behavioral correction?

## Source base

- [`../binaryen/2026-05-05-remove-relaxed-simd-current-main-recheck.md`](../binaryen/2026-05-05-remove-relaxed-simd-current-main-recheck.md)
- `docs/wiki/binaryen/passes/remove-relaxed-simd/`

## Finding

No teaching-relevant drift was found.

The current-main recheck still supports the same durable story already captured in the dossier:

- Binaryen uses trap replacement, not deterministic relaxed-SIMD lowering.
- `ChildLocalizer` preserves child effects before the trap.
- The pass still walks functions and refinalizes them.
- Unary, binary, and ternary relaxed opcode families are the real rewrite surface.
- Ordinary SIMD is outside the pass.
- Dot-product spelling remains a cross-surface caveat, not a behavior change.

## Wiki consequence

The dossier only needed freshness, not a contract rewrite.

I refreshed the pass pages with a 2026-05-05 current-main recheck note, but kept the behavior claims unchanged.

## Follow-up

If Starshine ever implements the pass, the first slice should still be registry honesty, child-effect preservation, typed `v128` trap contexts, ordinary-SIMD preservation, and dot-product spelling documentation.
