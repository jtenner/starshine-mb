# 0696 — 2026-06-02 loop-invariant-code-motion current-main recheck

## Question

Did Binaryen current `main` drift from the existing corrected `version_129` `loop-invariant-code-motion` / `licm` contract in any teaching-relevant way?

## Sources checked

- `docs/wiki/raw/binaryen/2026-04-24-loop-invariant-code-motion-primary-sources.md`
- `docs/wiki/raw/binaryen/2026-04-25-loop-invariant-code-motion-current-main-port-readiness.md`
- `docs/wiki/raw/binaryen/2026-06-02-loop-invariant-code-motion-current-main-recheck.md`

## Finding

No teaching-relevant drift was found on the reviewed surfaces.

Observed current-main facts:

- the upstream public pass name still resolves to `licm`
- `LoopInvariantCodeMotion.cpp` still owns the statement-move algorithm
- `pass.cpp` still exposes the pass as a normal public Binaryen pass
- the loop-entry scan remains prefix-scoped and control-transfer limited
- the candidate surface remains none-typed whole statements, not arbitrary value-expression hoisting
- effect, trap, and local-dependency guards remain the same safety backbone
- `licm.wast` still teaches the same positive and bailout families, including `pause` / control-transfer boundaries

## Durable update

The living `loop-invariant-code-motion` dossier pages now point at this recheck so future maintainers can see that the corrected contract was reverified after the earlier 2026-04-25 bridge.
No semantic retcon was required; this is a freshness and reference-hygiene update only.

## Living pages refreshed

- `docs/wiki/binaryen/passes/loop-invariant-code-motion/index.md`
- `docs/wiki/binaryen/passes/loop-invariant-code-motion/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/loop-invariant-code-motion/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/loop-invariant-code-motion/effects-loops-and-hoisting-rules.md`
- `docs/wiki/binaryen/passes/loop-invariant-code-motion/wat-shapes.md`
- `docs/wiki/binaryen/passes/loop-invariant-code-motion/starshine-strategy.md`
- `docs/wiki/binaryen/passes/loop-invariant-code-motion/starshine-port-readiness-and-validation.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/log.md`

## Supersession note

This note extends the earlier 2026-04-25 `loop-invariant-code-motion` source bridge.
It does not replace the earlier algorithm or implementation-test explanations, which remain the canonical detailed contract pages.
