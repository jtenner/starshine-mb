# SGO non-init same-init lit regression

_Date:_ 2026-05-23
_Status:_ filed into living SGO docs/backlog

## Question

Add an exact parser-supported source-alignment guardrail for the first Binaryen v129 `simplify-globals-non-init.wast` module, where mutable globals only receive writes equal to their initial values and can be made immutable.

## Sources

- Official Binaryen v129 lit fixture: `.tmp/sgo-lit/simplify-globals-non-init.wast`.
- Local test anchor: [`src/passes/simplify_globals_optimizing_test.mbt`](../../../../src/passes/simplify_globals_optimizing_test.mbt).
- Remaining-lit inventory: [`0579`](./0579-2026-05-23-sgo-remaining-lit-inventory.md).

## Local change

Added `simplify-globals-optimizing follows Binaryen non-init same-init writes lit`.

The source-shaped module has two mutable i32 globals:

- `$global-0`, initialized to `0`, then written `0` twice.
- `$global-1`, initialized to `1`, then written `1` twice.

A second function reads both globals only to keep the traffic observable before simplification. The local guardrail asserts both globals become immutable and both functions are free of `global.set` / `global.get` after direct SGO and nested cleanup. It intentionally does not require Binaryen's raw `drop(i32.const ...)` text shape because later cleanup may erase dropped pure constants.

## Validation

- `moon test src/passes`: `1513/1513` passed.

The guardrail passed without implementation changes. No direct 10k SGO fuzz was run because no transform behavior changed.

## Follow-up ranking

- The remaining `simplify-globals-non-init.wast` negatives for non-init writes and imported-initializer provenance are already covered by local guardrails; keep them as boundaries.
- Do not broaden same-init expression matching from this scalar direct-literal positive. Prior probes found block-wrapped and alias-sensitive cases where Binaryen stays conservative.

## Non-claims

- This does not claim full Binaryen `SimplifyGlobals.cpp` parity.
- This does not broaden same-init expression equivalence beyond the existing direct-literal/approved alias subsets.
- `[SGO]003` remains active/partial.
