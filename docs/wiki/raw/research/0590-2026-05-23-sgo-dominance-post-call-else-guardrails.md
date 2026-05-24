# SGO dominance post-call and else guardrails

_Date:_ 2026-05-23
_Status:_ filed into living SGO docs/backlog

## Question

Follow up the Binaryen `simplify-globals-dominance.wast` mapping in [`0575`](./0575-2026-05-23-sgo-dominance-lit-regression.md) with a compact source-shaped guardrail for the two official boundaries: a dominated then-body read before a recursive call may be replaced, but a value-observable read after the call and a value-observable else-arm read must remain conservative.

## Sources

- Official Binaryen v129 lit fixture: `.tmp/sgo-lit/simplify-globals-dominance.wast`.
- Local test anchor: [`src/passes/simplify_globals_optimizing_test.mbt`](../../../../src/passes/simplify_globals_optimizing_test.mbt).
- Prior dominance mapping: [`0575`](./0575-2026-05-23-sgo-dominance-lit-regression.md).

## Local change

Added `simplify-globals-optimizing follows Binaryen dominance lit post-call and else barriers`.

The test adapts the official dominance module so the relevant reads remain value-observable rather than being erased as dropped pure reads by later cleanup:

- the function writes `10` to a mutable global;
- the then arm uses a pre-call `global.get $g` as one operand of an `i32.add`;
- the same then arm makes a recursive call and then uses a post-call `global.get $g` as the other operand;
- the else arm returns `global.get $g`.

The assertions require the optimized body to contain the replacement constant `I32(10)`, the recursive call, and at least one remaining `global.get`, pinning the intended boundary without depending on raw Binaryen text shape.

## Validation

- `moon test src/passes`: `1507/1507` passed.

The guardrail passed without implementation changes. No direct 10k SGO fuzz was run because no transform behavior changed.

## Follow-up ranking

- The official dominance positive and its post-call / else-arm conservative boundaries are now source-aligned locally.
- Do not infer general else-join or post-call propagation from this file; call and else boundaries remain conservative unless a future focused Binaryen-positive fixture proves a narrower safe case.

## Non-claims

- This does not claim full Binaryen `SimplifyGlobals.cpp` parity.
- This does not broaden runtime trace propagation, call-effect facts, else-arm propagation, post-if joins, generated function-effects handling, or same-init expression matching.
- `[SGO]003` remains active/partial.
