# SGO if-return read-only-to-write negative lit guardrails

_Date:_ 2026-05-23  
_Status:_ filed into living SGO docs/backlog

## Question

Can Starshine locally pin the parser-supported negative `if return; set` variants from Binaryen v129 `simplify-globals-read_only_to_write.wast` without broadening `[SGO]003` control-flow behavior?

## Sources

- Binaryen v129 lit source: `.tmp/sgo-lit/simplify-globals-read_only_to_write.wast`
- Local test: `src/passes/simplify_globals_optimizing_test.mbt`
- Living status docs:
  - `docs/wiki/binaryen/passes/simplify-globals-optimizing/parity-matrix.md`
  - `docs/wiki/binaryen/passes/simplify-globals-optimizing/starshine-port-readiness-and-validation.md`
  - `agent-todo.md`

## Result

Added `simplify-globals-optimizing follows Binaryen if-return read-only-to-write negative lit` as a direct SGO guardrail. The fixture combines three official negative shapes with separate globals:

1. the otherwise-positive `if return; set` form followed by an extra `nop` in the function body,
2. an `if return` guard with an `else` arm before the set,
3. an `if` whose body is `nop` instead of `return` before the set.

The test runs SGO twice and asserts that each global remains mutable and that each corresponding function still contains the matching `global.get` and `global.set`.

## Validation

- `moon test src/passes`: `1516/1516` passed.

The test passed without implementation changes, so this is a tests/docs-only guardrail. No direct 10k SGO fuzz was run because transform behavior did not change.

## Non-claims

- This does not broaden Starshine's `if return; set` optimization.
- This does not authorize broader branch/return/control-transfer matching.
- This does not claim full Binaryen `SimplifyGlobals.cpp` parity; `[SGO]003` remains active/partial.
