# `type-ssa` port-readiness bridge

_Date:_ 2026-04-26  
_Status:_ absorbed into living wiki pages

## Question

Does the corrected `type-ssa` dossier give future Starshine implementers enough first-slice and validation guidance?

## Short answer

Not quite. The corrected dossier accurately teaches Binaryen's allocation-subtype contract, but it still leaves the future Starshine sequence too implicit. A faithful local port needs registry honesty, no-rewrite candidate/blocker analysis, type-section mutation, allocation retagging, and validation/refinalization proof in that order.

## Evidence

Primary-source bridge: [`../binaryen/2026-04-26-type-ssa-port-readiness-primary-sources.md`](../binaryen/2026-04-26-type-ssa-port-readiness-primary-sources.md)

Earlier correction this builds on: [`../binaryen/2026-04-26-type-ssa-source-correction-and-current-main.md`](../binaryen/2026-04-26-type-ssa-source-correction-and-current-main.md)

## Durable findings

- Binaryen `type-ssa` is still a public upstream pass centered on selected allocation sites, not a general SSA/local-flow pass.
- Current `main` did not change the teaching-relevant contract from the corrected `version_129` read.
- The official fixture still supports a validation ladder centered on struct/array allocation positives plus uninteresting and exact-observed bailouts.
- Starshine still treats `type-ssa` as unknown, not boundary-only or removed.
- Starshine has useful prerequisite representation surfaces for GC allocation instructions and type validation, but no type-section mutation/refinalization pass substrate for this exact optimization.

## Recommended Starshine order

1. Registry decision: unknown vs boundary-only vs active experimental pass.
2. Analyzer-only classification for candidate allocation sites and exact-observation blockers.
3. Official fixture-shaped reduced tests for positives and bailouts.
4. Type-section fresh-subtype construction.
5. Allocation-result retagging.
6. Validation/refinalization proof.
7. Binaryen oracle comparison and pass-fuzz only after the pass is honestly registered.

## Files updated

- `docs/wiki/binaryen/passes/type-ssa/index.md`
- `docs/wiki/binaryen/passes/type-ssa/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/type-ssa/starshine-strategy.md`
- `docs/wiki/binaryen/passes/type-ssa/starshine-port-readiness-and-validation.md`
- `docs/wiki/binaryen/passes/type-ssa/wat-shapes.md`
- `docs/wiki/index.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/log.md`
