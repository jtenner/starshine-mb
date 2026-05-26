# SGO multi-input single-use GC official lit regression

_Date:_ 2026-05-23
_Status:_ filed into living SGO docs/backlog

## Question

Continue parser-supported `simplify-globals-single_use.wast` source alignment after the single-use GC guardrails in [`0584`](./0584-2026-05-23-sgo-single-use-gc-lit-regression.md), [`0585`](./0585-2026-05-23-sgo-nested-single-use-gc-lit-regression.md), and [`0586`](./0586-2026-05-23-sgo-multiple-single-use-gc-lit-regression.md): pin the official multiple-inputs-into-one-global startup shape without broadening into function-code-only single use, multi-use, imported-source, object-identity-sensitive GC duplication, or refinalization work.

## Sources

- Official Binaryen v129 lit fixture: `.tmp/sgo-lit/simplify-globals-single_use.wast`.
- Local test anchor: [`src/passes/simplify_globals_optimizing_test.mbt`](../../../../src/passes/simplify_globals_optimizing_test.mbt).
- Prior inventory: [`0579`](./0579-2026-05-23-sgo-remaining-lit-inventory.md).

## Local change

Added `simplify-globals-optimizing follows Binaryen multi-input single-use GC initializer lit`.

The test mirrors the official "more than one nesting into one global" module:

- `$single-use1` is an immutable `anyref` initialized by `struct.new $A (ref.i31 (i32.const 42)) (ref.null any)`;
- `$single-use2` is an immutable `anyref` initialized by `struct.new $A (ref.null any) (ref.i31 (i32.const 1337))`;
- `$other` has one startup initializer that constructs `struct.new $A` from both source globals.

The expected `$other` initializer contains both copied constructor stacks followed by the outer `struct.new`, and the test asserts that no `nested-cleanup` trace appears.

## Validation

- `moon test src/passes`: `1501/1501` passed.

The guardrail passed without implementation changes. No direct 10k SGO fuzz was run because no transform behavior changed.

## Follow-up ranking

- The remaining parser-supported startup candidate in `simplify-globals-single_use.wast` is the copy-chain module.
- Keep function-code-only single-use, multi-use, imported-source, broad object-identity, and refinalization-sensitive cases separate with focused oracle support.

## Non-claims

- This does not claim full Binaryen `SimplifyGlobals.cpp` parity.
- This does not broaden function-code replacement, multi-use folding, object-identity-sensitive `struct.new_default` duplication, same-init expression matching, runtime facts, or GC refinalization.
- `[SGO]003` remains active/partial.
