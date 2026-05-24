# SGO non-init changed-write negative lit guardrail

_Date:_ 2026-05-23
_Status:_ filed into living SGO docs/backlog

## Question

Add an exact parser-supported source-alignment guardrail for the second Binaryen v129 `simplify-globals-non-init.wast` module, where globals that also receive non-initial or unknown writes must stay mutable.

## Sources

- Official Binaryen v129 lit fixture: `.tmp/sgo-lit/simplify-globals-non-init.wast`.
- Local test anchor: [`src/passes/simplify_globals_optimizing_test.mbt`](../../../../src/passes/simplify_globals_optimizing_test.mbt).
- Positive paired guardrail: [`0594`](./0594-2026-05-23-sgo-non-init-same-init-lit-regression.md).

## Local change

Added `simplify-globals-optimizing follows Binaryen non-init changed-write negative lit`.

The source-shaped module has two mutable i32 globals:

- `$global-0`, initialized to `0`, then written both `0` and `1`.
- `$global-1`, initialized to `1`, then written `1` and an unknown parameter value.

A second function reads both globals. The local guardrail asserts both globals remain mutable, the setting function keeps writes to both globals, the unknown `local.get` operand remains present, and the reading function still contains `global.get`s for both globals.

## Validation

- `moon test src/passes`: `1514/1514` passed.

The guardrail passed without implementation changes. No direct 10k SGO fuzz was run because no transform behavior changed.

## Follow-up ranking

- This pairs with [`0594`](./0594-2026-05-23-sgo-non-init-same-init-lit-regression.md): same-init scalar writes are removable, but a changed literal or unknown write keeps the global mutable.
- The imported-initializer non-init boundary remains covered by the earlier local guardrail; do not treat imported `global.get` initializers as locally known constants.
- Do not broaden same-init expression matching from this scalar direct-literal boundary.

## Non-claims

- This does not claim full Binaryen `SimplifyGlobals.cpp` parity.
- This does not broaden same-init expression equivalence beyond the existing direct-literal/approved alias subsets.
- `[SGO]003` remains active/partial.
