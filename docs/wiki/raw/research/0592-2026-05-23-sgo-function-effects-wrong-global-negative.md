# SGO function-effects wrong-global negative guardrail

_Date:_ 2026-05-23
_Status:_ filed into living SGO docs/backlog

## Question

Map the remaining compact wrong-global read-only-to-write negative from Binaryen v129 `simplify-globals_func-effects.wast` into a direct Starshine `simplify-globals-optimizing` guardrail without adding generated global-effect summaries.

## Sources

- Official Binaryen v129 lit fixture: `.tmp/sgo-lit/simplify-globals_func-effects.wast`.
- Local test anchor: [`src/passes/simplify_globals_optimizing_test.mbt`](../../../../src/passes/simplify_globals_optimizing_test.mbt).
- Prior function-effects call negatives: [`0591`](./0591-2026-05-23-sgo-function-effects-call-negatives.md).

## Local change

Added `simplify-globals-optimizing keeps function-effects wrong-global read-only-to-write negative`.

The source-shaped module has two globals:

- `$global`, read through a call to `$get` and then directly written in the then body.
- `$other`, directly read in the condition block as the value that drives the branch.

Binaryen's lit expects `$global` to remain mutable because the only local syntactic `global.get` in the condition is for the wrong global. The `$get` call is not counted as a direct local read-only-to-write event for `$global` by direct SGO. Starshine now pins the same conservative behavior by asserting `$global` remains mutable, the condition still calls `$get`, the then body still contains a direct `global.set`, and `$get` still contains the `$global` read.

The test intentionally does not require `$other` to remain mutable or require a raw `global.get $other` shape after optimization; Binaryen can make `$other` immutable and fold the condition value, and Starshine may do the same.

## Validation

- `moon test src/passes`: `1511/1511` passed.

The guardrail passed without implementation changes. No direct 10k SGO fuzz was run because no transform behavior changed.

## Follow-up ranking

- Keep direct SGO call barriers conservative until Starshine has an explicit function-effects analysis with focused oracle support.
- The first positive module in `simplify-globals_func-effects.wast`, where `--generate-global-effects` lets Binaryen preserve facts for unaffected globals across a call, remains deferred for a separate generated-effects/shared-analysis slice.

## Non-claims

- This does not claim full Binaryen `SimplifyGlobals.cpp` parity.
- This does not implement `--generate-global-effects`, global-effect summaries, interprocedural call effects, or call-through propagation.
- `[SGO]003` remains active/partial.
