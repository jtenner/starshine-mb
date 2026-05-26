# SGO single-use official lit negative guardrails

_Date:_ 2026-05-23
_Status:_ filed into living SGO docs/backlog

## Question

After covering the parser-supported positive startup/global-initializer shapes in Binaryen v129 `simplify-globals-single_use.wast` through [`0584`](./0584-2026-05-23-sgo-single-use-gc-lit-regression.md), [`0585`](./0585-2026-05-23-sgo-nested-single-use-gc-lit-regression.md), [`0586`](./0586-2026-05-23-sgo-multiple-single-use-gc-lit-regression.md), [`0587`](./0587-2026-05-23-sgo-multi-input-single-use-gc-lit-regression.md), and [`0588`](./0588-2026-05-23-sgo-single-use-chain-lit-regression.md), pin the compact official negatives from the same file so future single-use broadening remains startup-only and source-backed.

## Sources

- Official Binaryen v129 lit fixture: `.tmp/sgo-lit/simplify-globals-single_use.wast`.
- Local test anchor: [`src/passes/simplify_globals_optimizing_test.mbt`](../../../../src/passes/simplify_globals_optimizing_test.mbt).
- Prior inventory: [`0579`](./0579-2026-05-23-sgo-remaining-lit-inventory.md).

## Local change

Added four negative guardrail tests:

1. `simplify-globals-optimizing follows Binaryen single-use multi-global-use negative lit`
   - `$single-use` is read by two later global initializers.
   - Both later initializers remain `global.get $single-use`.
2. `simplify-globals-optimizing follows Binaryen single-use function-second-use negative lit`
   - `$single-use` is read by one later global initializer and also in function code.
   - The later global initializer remains `global.get $single-use`, and the function read remains present.
3. `simplify-globals-optimizing follows Binaryen single-use imported-source negative lit`
   - `$single-use` is imported, so there is no local initializer code to copy.
   - The later global initializer remains `global.get $single-use`.
4. `simplify-globals-optimizing follows Binaryen single-use function-only negative lit`
   - `$single-use` is only read in function code.
   - The function read remains present because function code can execute more than once.

The startup-related negatives also assert no `nested-cleanup` trace appears.

## Validation

- `moon test src/passes`: `1506/1506` passed.

The guardrails passed without implementation changes. No direct 10k SGO fuzz was run because no transform behavior changed.

## Follow-up ranking

- The parser-supported positive startup/global-initializer examples and compact negatives in `simplify-globals-single_use.wast` are now covered locally.
- Keep object-identity-sensitive GC duplication, `ref.cast`/refinalization-sensitive positives, function-effects, and sibling `propagate-globals-globally` work separate with focused oracle support.

## Non-claims

- This does not claim full Binaryen `SimplifyGlobals.cpp` parity.
- This does not broaden function-code replacement, multi-use folding, imported-source folding, object-identity-sensitive `struct.new_default` duplication, same-init expression matching, runtime facts, or GC refinalization.
- `[SGO]003` remains active/partial.
