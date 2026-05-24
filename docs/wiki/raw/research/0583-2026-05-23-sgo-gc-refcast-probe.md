# SGO GC ref.cast lit probe

_Date:_ 2026-05-23
_Status:_ filed into living SGO docs/backlog

## Question

Continue the [`0579`](./0579-2026-05-23-sgo-remaining-lit-inventory.md) ranking after the nested GC initializer regression in [`0582`](./0582-2026-05-23-sgo-nested-gc-lit-regression.md): check whether the narrow Binaryen v129 `simplify-globals-gc.wast` `ref.cast(ref.func-global)` positive and the paired less-refined alias negative are smooth enough for a source-alignment slice.

## Sources

- Official Binaryen v129 lit fixture: `.tmp/sgo-lit/simplify-globals-gc.wast`.
- Local implementation/test anchor: [`src/passes/simplify_globals_optimizing_test.mbt`](../../../../src/passes/simplify_globals_optimizing_test.mbt).
- Prior ranking: [`0579`](./0579-2026-05-23-sgo-remaining-lit-inventory.md) and [`0582`](./0582-2026-05-23-sgo-nested-gc-lit-regression.md).

## Findings

The less-refined alias negative is parser-supported and now pinned locally. The test `simplify-globals-optimizing keeps less-refined GC global aliases conservative` mirrors the official second module: `$a` and `$b` are `(ref $struct)`, `$c` is `(ref null $struct)`, and `$get-c` must continue reading `$c` rather than being retargeted to the more refined aliases. This preserves Binaryen's conservative boundary when replacement would require broader refinalization.

The narrow positive is not yet ready as a source-alignment test:

- the official folded WAT uses `ref.cast`, but the local WAT parser recognizes `ref.test` and descriptor casts while lacking normal `ref.cast` keyword lowering;
- a programmatic lib-level probe with `Instruction::ref_cast` still failed through the `simplify-globals-optimizing` pipeline, indicating a local validation/refinalization frontier before this exact positive can be landed safely.

Because this is a GC/refinalization-sensitive surface, the positive was not forced or approximated. No implementation code changed.

## Validation

- Initial `moon test src/passes` failed for the WAT-shaped positive because normal `ref.cast` is not parser-supported.
- A temporary programmatic positive using `Instruction::ref_cast` also failed through the pipeline, confirming the positive needs a focused parser/validation/refinalization follow-up rather than a quick guardrail.
- Final `moon test src/passes`: `1497/1497` passed with only the less-refined alias negative landed.

No direct 10k SGO fuzz was run because this was tests/docs-only and made no implementation behavior change.

## Follow-up ranking

- Treat the `ref.cast(ref.func-global)` positive as blocked on normal `ref.cast` WAT support and/or a focused validation/refinalization fix.
- Keep object-identity `struct.new_default` duplication separate and deferred; do not batch it with `ref.cast` work.
- If continuing official-lit source alignment without parser/validator work, prefer another exact parser-supported startup/global-initializer guardrail from `simplify-globals-single_use.wast`; avoid function-effects, sibling `propagate-globals-globally`, broad same-init, loop/control, and trapping/effectful surfaces without focused oracle support.

## Non-claims

- This does not claim full Binaryen `SimplifyGlobals.cpp` parity.
- This does not implement GC refinalization or broaden type-changing replacement.
- `[SGO]003` remains active/partial.
