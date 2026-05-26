# SGO single-use copy-chain GC official lit regression

_Date:_ 2026-05-23
_Status:_ filed into living SGO docs/backlog

## Question

Finish the parser-supported positive startup shapes in Binaryen v129 `simplify-globals-single_use.wast` after the single-use GC guardrails in [`0584`](./0584-2026-05-23-sgo-single-use-gc-lit-regression.md), [`0585`](./0585-2026-05-23-sgo-nested-single-use-gc-lit-regression.md), [`0586`](./0586-2026-05-23-sgo-multiple-single-use-gc-lit-regression.md), and [`0587`](./0587-2026-05-23-sgo-multi-input-single-use-gc-lit-regression.md): pin the official related-optimization copy-chain module without broadening into function-code-only single use, multi-use, imported-source, object-identity-sensitive GC duplication, or refinalization work.

## Sources

- Official Binaryen v129 lit fixture: `.tmp/sgo-lit/simplify-globals-single_use.wast`.
- Local test anchor: [`src/passes/simplify_globals_optimizing_test.mbt`](../../../../src/passes/simplify_globals_optimizing_test.mbt).
- Prior inventory: [`0579`](./0579-2026-05-23-sgo-remaining-lit-inventory.md).

## Local change

Added `simplify-globals-optimizing follows Binaryen single-use copy-chain GC initializer lit`.

The test mirrors the official "multiple related optimizations in one module: a chain" module:

- `$single-use1` is an immutable `anyref` initialized by `ref.i31 (i32.const 42)`;
- `$other1` constructs `struct.new $A` from the source global;
- `$other2` constructs another `struct.new $A` from `$other1`;
- `$other3` is initialized from `$other2`.

The expected initializers prove each later startup use sees the copied chain:

- `$other1`: `i32.const 42`, `ref.i31`, `struct.new`;
- `$other2`: `i32.const 42`, `ref.i31`, `struct.new`, `struct.new`;
- `$other3`: same nested constructor stack as `$other2`.

The test also asserts that no `nested-cleanup` trace appears.

## Validation

- `moon test src/passes`: `1502/1502` passed.

The guardrail passed without implementation changes. No direct 10k SGO fuzz was run because no transform behavior changed.

## Follow-up ranking

- The parser-supported positive startup/global-initializer examples in `simplify-globals-single_use.wast` are now covered by local guardrails.
- Good next exact guardrails from the same lit file are the negative cases: second global use, function-code second use, imported source, and function-code-only single use.
- Keep object-identity-sensitive GC duplication and `ref.cast`/refinalization-sensitive positives separate with focused oracle support.

## Non-claims

- This does not claim full Binaryen `SimplifyGlobals.cpp` parity.
- This does not broaden function-code replacement, multi-use folding, imported-source folding, object-identity-sensitive `struct.new_default` duplication, same-init expression matching, runtime facts, or GC refinalization.
- `[SGO]003` remains active/partial.
