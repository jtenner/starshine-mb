# SGO function-effects call negative guardrails

_Date:_ 2026-05-23
_Status:_ filed into living SGO docs/backlog

## Question

Map the compact negative read-only-to-write call shapes from Binaryen v129 `simplify-globals_func-effects.wast` into direct Starshine `simplify-globals-optimizing` guardrails without implementing Binaryen's `--generate-global-effects` summary pass or weakening direct SGO call barriers.

## Sources

- Official Binaryen v129 lit fixture: `.tmp/sgo-lit/simplify-globals_func-effects.wast`.
- Local test anchor: [`src/passes/simplify_globals_optimizing_test.mbt`](../../../../src/passes/simplify_globals_optimizing_test.mbt).
- Remaining-lit inventory: [`0579`](./0579-2026-05-23-sgo-remaining-lit-inventory.md).

## Local change

Added three source-shaped negative guardrails:

1. `simplify-globals-optimizing keeps function-effects get-call read-only-to-write negative`
   - The apparent condition calls `$get`, whose body reads `$global`, before a direct write in the then body.
   - The global remains mutable, the call remains present, the direct `global.set` remains present, and `$get` still reads the global.
2. `simplify-globals-optimizing keeps function-effects set-call read-only-to-write negative`
   - The condition directly reads `$global`, but the then body calls `$set` instead of containing the direct write.
   - The global remains mutable, the condition read remains present, and `$set` still writes the global.
3. `simplify-globals-optimizing keeps function-effects get-and-set-call read-only-to-write negative`
   - Both the apparent read and write are hidden behind calls.
   - The global remains mutable and both calls remain present.

These mirror the official warning that calls to functions with global get/set effects are not the same thing as local syntactic `global.get` / `global.set` events for the direct read-only-to-write matcher.

## Validation

- `moon test src/passes`: `1510/1510` passed.

The guardrails passed without implementation changes. No direct 10k SGO fuzz was run because no transform behavior changed.

## Follow-up ranking

- Keep direct SGO call barriers conservative until Starshine has an explicit function-effects analysis with focused oracle support.
- The first positive module in `simplify-globals_func-effects.wast`, where `--generate-global-effects` lets Binaryen preserve facts for unaffected globals across a call, remains deferred for a separate generated-effects/shared-analysis slice.
- The wrong-global variant from the same lit file can be added later as another compact guardrail if needed.

## Non-claims

- This does not claim full Binaryen `SimplifyGlobals.cpp` parity.
- This does not implement `--generate-global-effects`, global-effect summaries, interprocedural call effects, or call-through propagation.
- `[SGO]003` remains active/partial.
