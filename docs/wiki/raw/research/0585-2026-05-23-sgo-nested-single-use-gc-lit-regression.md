# SGO nested single-use GC official lit regression

_Date:_ 2026-05-23
_Status:_ filed into living SGO docs/backlog

## Question

Continue the parser-supported `simplify-globals-single_use.wast` source-alignment work after [`0584`](./0584-2026-05-23-sgo-single-use-gc-lit-regression.md): pin the official nested startup/global-initializer single-use shape without broadening into function-code-only single use, multi-use, or object-identity-sensitive GC duplication.

## Sources

- Official Binaryen v129 lit fixture: `.tmp/sgo-lit/simplify-globals-single_use.wast`.
- Local test anchor: [`src/passes/simplify_globals_optimizing_test.mbt`](../../../../src/passes/simplify_globals_optimizing_test.mbt).
- Prior source-alignment notes: [`0579`](./0579-2026-05-23-sgo-remaining-lit-inventory.md), [`0584`](./0584-2026-05-23-sgo-single-use-gc-lit-regression.md).

## Local change

Added `simplify-globals-optimizing follows Binaryen nested single-use GC initializer lit`.

The test mirrors the official nested single-use module:

- `$single-use` is an immutable `anyref` initialized by `struct.new $A (ref.i31 (i32.const 42))`;
- `$other` has a global initializer `struct.new $A (global.get $single-use)`;
- the single startup use is nested inside another constructor, so the pass may copy the source initializer into that nested operand.

The expected `$other` initializer becomes:

1. `i32.const 42`,
2. `ref.i31`,
3. inner `struct.new 0`,
4. outer `struct.new 0`.

The test also checks no `nested-cleanup` trace appears, preserving the current startup-only boundary.

## Validation

- `moon test src/passes`: `1499/1499` passed.

The guardrail passed without implementation changes. No direct 10k SGO fuzz was run because no transform behavior changed.

## Follow-up ranking

- Remaining `simplify-globals-single_use.wast` parser-supported startup candidates include multiple independent folds, multiple nested inputs into one global, and copy chains.
- Keep function-code-only single-use, multi-use, imported-source, broad object-identity, and refinalization-sensitive cases separate with focused oracle support.

## Non-claims

- This does not claim full Binaryen `SimplifyGlobals.cpp` parity.
- This does not broaden function-code replacement, multi-use folding, object-identity-sensitive `struct.new_default` duplication, same-init expression matching, runtime facts, or GC refinalization.
- `[SGO]003` remains active/partial.
