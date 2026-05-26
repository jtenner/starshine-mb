# SGO single-use GC official lit regression

_Date:_ 2026-05-23
_Status:_ filed into living SGO docs/backlog

## Question

Continue the [`0579`](./0579-2026-05-23-sgo-remaining-lit-inventory.md) source-alignment plan after the GC ref.cast probe in [`0583`](./0583-2026-05-23-sgo-gc-refcast-probe.md): land one exact parser-supported guardrail from Binaryen v129 `simplify-globals-single_use.wast` without broadening into function-code single-use, multi-use, or object-identity-sensitive GC duplication beyond the official startup/global-initializer shape.

## Sources

- Official Binaryen v129 lit fixture: `.tmp/sgo-lit/simplify-globals-single_use.wast`.
- Local implementation/test anchor: [`src/passes/simplify_globals_optimizing_test.mbt`](../../../../src/passes/simplify_globals_optimizing_test.mbt).
- Prior inventories: [`0579`](./0579-2026-05-23-sgo-remaining-lit-inventory.md), [`0582`](./0582-2026-05-23-sgo-nested-gc-lit-regression.md), and [`0583`](./0583-2026-05-23-sgo-gc-refcast-probe.md).

## Local change

Added `simplify-globals-optimizing follows Binaryen single-use GC initializer lit` next to the existing single-use initializer and official-lit source-alignment regressions.

The test mirrors the first official `simplify-globals-single_use.wast` module in parser-supported WAT:

- `$single-use` is an immutable `anyref` global initialized with `struct.new $A (ref.i31 (i32.const 42))`;
- `$other` is a mutable `anyref` global whose initializer is the single startup use of `$single-use`;
- function-body uses and writes of `$other` do not affect whether `$single-use` can be folded into `$other`'s startup initializer.

The expected `$other` initializer is the copied constructor stack:

1. `i32.const 42`,
2. `ref.i31`,
3. `struct.new 0`.

The test also asserts no `nested-cleanup` trace appears, preserving the current boundary that startup-only global-initializer rewrites do not touch functions or trigger nested cleanup.

## Validation

- `moon test src/passes`: `1498/1498` passed.

The source-shaped guardrail passed without implementation changes, so this remains a test/docs-only source-alignment slice. No direct 10k SGO fuzz was run because no transform behavior changed.

## Follow-up ranking

- Additional `simplify-globals-single_use.wast` startup/global-initializer shapes can be mapped later, especially nested and multiple-independent folds, but should remain exact and parser-supported.
- Function-code-only single-use remains a negative boundary: it may execute more than once and should not be inferred from this startup initializer guardrail.
- Multi-use, imported-source, broad GC object-identity, and `ref.cast`/refinalization-sensitive cases remain separate follow-ups requiring focused oracle support.

## Non-claims

- This does not claim full Binaryen `SimplifyGlobals.cpp` parity.
- This does not broaden function-code replacement, multi-use folding, object-identity-sensitive `struct.new_default` duplication, same-init expression matching, runtime trace facts, or GC refinalization.
- `[SGO]003` remains active/partial.
