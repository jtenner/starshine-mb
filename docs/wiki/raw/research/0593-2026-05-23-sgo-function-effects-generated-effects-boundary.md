# SGO function-effects generated-effects boundary guardrail

_Date:_ 2026-05-23
_Status:_ filed into living SGO docs/backlog

## Question

Record the direct Starshine `simplify-globals-optimizing` boundary for the first Binaryen v129 `simplify-globals_func-effects.wast` module, whose positive behavior depends on running `--generate-global-effects` before `--simplify-globals`.

## Sources

- Official Binaryen v129 lit fixture: `.tmp/sgo-lit/simplify-globals_func-effects.wast`.
- Local test anchor: [`src/passes/simplify_globals_optimizing_test.mbt`](../../../../src/passes/simplify_globals_optimizing_test.mbt).
- Prior function-effects negatives: [`0591`](./0591-2026-05-23-sgo-function-effects-call-negatives.md), [`0592`](./0592-2026-05-23-sgo-function-effects-wrong-global-negative.md).

## Local change

Added `simplify-globals-optimizing keeps function-effects generated-effects positive conservative`.

The source fixture writes `$A` and `$C`, reads `$A` / `$B` / `$C`, calls `$set`, then reads them again. Binaryen's lit run uses `--generate-global-effects`, which can prove `$set` writes `$A` while leaving `$B` and `$C` facts usable across the call. Direct Starshine SGO does not run a generated global-effects analysis, so this test adapts the post-call reads to be value-observable and pins the conservative direct-pass boundary:

- `$A` remains mutable.
- `$B` may become immutable and fold to `20`.
- `$C` remains mutable in direct SGO because the call barrier blocks assuming it is unaffected by `$set`.
- The call remains present, and value-observable post-call reads of `$A` and `$C` remain present.

Pre-call dropped pure reads may disappear through cleanup; the test does not use those raw dropped-read shapes as assertions.

## Validation

- `moon test src/passes`: `1512/1512` passed.

The guardrail passed without implementation changes. No direct 10k SGO fuzz was run because no transform behavior changed.

## Follow-up ranking

- A future generated-effects/shared-analysis slice may target Binaryen's positive behavior for unaffected globals across calls, but it needs explicit effect summaries and paired negatives.
- Until then, direct SGO should keep ordinary calls as barriers for runtime facts not proven by local syntax.

## Non-claims

- This does not claim full Binaryen `SimplifyGlobals.cpp` parity.
- This does not implement `--generate-global-effects`, global-effect summaries, interprocedural call effects, or call-through propagation.
- `[SGO]003` remains active/partial.
