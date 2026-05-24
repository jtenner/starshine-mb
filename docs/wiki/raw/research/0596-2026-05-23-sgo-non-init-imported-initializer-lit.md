# SGO non-init imported-initializer lit guardrail

_Date:_ 2026-05-23
_Status:_ filed into living SGO docs/backlog

## Question

Add an exact parser-supported source-alignment guardrail for the third Binaryen v129 `simplify-globals-non-init.wast` module, where a mutable global initialized from an imported global must not be treated as having a locally known constant initial value.

## Sources

- Official Binaryen v129 lit fixture: `.tmp/sgo-lit/simplify-globals-non-init.wast`.
- Local test anchor: [`src/passes/simplify_globals_optimizing_test.mbt`](../../../../src/passes/simplify_globals_optimizing_test.mbt).
- Paired scalar direct-literal guardrails: [`0594`](./0594-2026-05-23-sgo-non-init-same-init-lit-regression.md) and [`0595`](./0595-2026-05-23-sgo-non-init-changed-write-negative-lit.md).

## Local change

Added `simplify-globals-optimizing follows Binaryen non-init imported-initializer negative lit`.

The source-shaped module imports immutable `$global-0`, defines mutable `$global-1` with initializer `(global.get $global-0)`, writes literal `1` to `$global-1`, and reads both globals in a second function.

The local guardrail asserts:

- `$global-1`'s defined initializer remains `global.get` of the imported global;
- `$global-1` remains mutable;
- `$sets` keeps `global.set $global-1` and the literal `1` operand;
- `$gets` keeps reads of both the imported and defined globals.

This is intentionally redundant with the older local imported-initializer guardrail, but uses the exact official source shape and naming so the three parser-supported modules in `simplify-globals-non-init.wast` are directly traceable.

## Validation

- `moon test src/passes`: `1515/1515` passed.

The guardrail passed without implementation changes. No direct 10k SGO fuzz was run because no transform behavior changed.

## Follow-up ranking

- Together with [`0594`](./0594-2026-05-23-sgo-non-init-same-init-lit-regression.md) and [`0595`](./0595-2026-05-23-sgo-non-init-changed-write-negative-lit.md), the parser-supported `simplify-globals-non-init.wast` modules are now mapped to exact local direct SGO guardrails.
- Do not treat imported `global.get` initializers as locally known constants.
- Do not broaden same-init expression matching from this imported-initializer negative.

## Non-claims

- This does not claim full Binaryen `SimplifyGlobals.cpp` parity.
- This does not broaden same-init expression equivalence beyond the existing direct-literal/approved alias subsets.
- `[SGO]003` remains active/partial.
