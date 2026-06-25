# Optimize-instructions OI-M trapping tuple sibling coverage

Date: 2026-06-25

## Scope

This OI-M slice adds focused trap-preservation coverage for the locally implemented one-use `tuple.extract(tuple.make(...))` localization. The covered shape selects a scalar lane from a tuple while non-selected earlier and later siblings are trapping `i32.load` expressions.

The point of the slice is to ensure trapping siblings are treated as non-pure tuple children and are preserved as dropped effects. It is status/coverage evidence for the existing direct-HOT localizer, not a new tuple-scratch implementation.

## Binaryen oracle

Probe: `.tmp/oi-m-tuple-trapping-sibling-probe.wat`

`wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-trapping-sibling-probe.wat -o -` preserves both sibling loads as drops while selecting the middle scalar lane. Binaryen uses a temp local around the selected value so the later trapping load can execute before the selected value is returned.

## Starshine coverage

`src/passes/optimize_instructions_test.mbt` adds:

- `optimize-instructions preserves trapping tuple.extract sibling loads`

The direct-HOT fixture builds:

- an earlier non-selected `i32.load` sibling;
- the selected scalar `local.get` lane;
- a later non-selected `i32.load` sibling.

After `optimize-instructions`, Starshine must emit an effect-preserving block with four roots:

1. `drop(earlier load)`;
2. `local.set(selected temp)`;
3. `drop(later load)`;
4. `local.get(selected temp)`.

The focused test passed immediately, so no implementation change was needed. Red-first behavior evidence was not applicable; this is coverage for an already implemented trap-preserving path.

## Validation

- Binaryen oracle probe above passed.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*trapping tuple.extract sibling loads*'` passed `1/1`.
- `moon fmt` passed.
- `moon test src/passes` passed in the same slice.

## Remaining boundaries

This does not close OI-M. Public tuple text/binary fixture coverage, tuple-scratch localization for multi-result selected children and siblings, broader multivalue block reconstruction, multi-use tuple extraction, full `simplify-locals` and `tuple-optimization` public parity, and the recorded direct-HOT full-neighbor verifier failure (`InvalidChildRef(3, 0, 0)`) remain open.
