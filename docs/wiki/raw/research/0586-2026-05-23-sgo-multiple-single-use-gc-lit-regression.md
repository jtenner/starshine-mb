# SGO multiple single-use GC official lit regression

_Date:_ 2026-05-23
_Status:_ filed into living SGO docs/backlog

## Question

Continue parser-supported `simplify-globals-single_use.wast` source alignment after [`0584`](./0584-2026-05-23-sgo-single-use-gc-lit-regression.md) and [`0585`](./0585-2026-05-23-sgo-nested-single-use-gc-lit-regression.md): pin the official multiple-independent startup/global-initializer single-use shape without broadening into function-code-only single use, multi-use, imported-source, object-identity-sensitive GC duplication, or refinalization work.

## Sources

- Official Binaryen v129 lit fixture: `.tmp/sgo-lit/simplify-globals-single_use.wast`.
- Local test anchor: [`src/passes/simplify_globals_optimizing_test.mbt`](../../../../src/passes/simplify_globals_optimizing_test.mbt).
- Prior source-alignment notes: [`0579`](./0579-2026-05-23-sgo-remaining-lit-inventory.md), [`0584`](./0584-2026-05-23-sgo-single-use-gc-lit-regression.md), and [`0585`](./0585-2026-05-23-sgo-nested-single-use-gc-lit-regression.md).

## Local change

Added `simplify-globals-optimizing follows Binaryen multiple single-use GC initializer lit`.

The test mirrors the official multiple-independent optimizations module:

- `$single-use1`, `$single-use2`, and `$single-use3` are immutable `anyref` globals initialized by `struct.new $A (ref.i31 (i32.const ...))` with values `42`, `1337`, and `99999`;
- `$other1`, `$other2`, and `$other3` each have a single startup initializer use of one source global;
- the pass folds all three independent source initializers into the corresponding later global initializers in one module.

The test asserts `$other1`, `$other2`, and `$other3` each receive the copied constructor stack and that no `nested-cleanup` trace appears.

## Validation

- `moon test src/passes`: `1500/1500` passed.

The guardrail passed without implementation changes. No direct 10k SGO fuzz was run because no transform behavior changed.

## Follow-up ranking

- Remaining parser-supported startup candidates in `simplify-globals-single_use.wast` include multiple nested inputs into one global and copy chains.
- Keep function-code-only single-use, multi-use, imported-source, broad object-identity, and refinalization-sensitive cases separate with focused oracle support.

## Non-claims

- This does not claim full Binaryen `SimplifyGlobals.cpp` parity.
- This does not broaden function-code replacement, multi-use folding, object-identity-sensitive `struct.new_default` duplication, same-init expression matching, runtime facts, or GC refinalization.
- `[SGO]003` remains active/partial.
