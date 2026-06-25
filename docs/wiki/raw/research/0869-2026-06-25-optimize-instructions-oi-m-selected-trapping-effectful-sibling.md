# Optimize-instructions OI-M selected trapping lane with effectful sibling coverage

Date: 2026-06-25

## Scope

This OI-M slice adds focused direct-HOT coverage for `tuple.extract(tuple.make(...))` when the selected lane may trap and a later non-selected sibling has an effect.

This is coverage/status evidence for the existing single-result tuple localizer, not a new tuple-scratch implementation. It narrows the risk that selected trapping lanes are preserved only in the all-pure-sibling forwarding case.

## Binaryen oracle

Probe: `.tmp/oi-m-tuple-selected-trapping-with-sibling-probe.wat`

`wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-selected-trapping-with-sibling-probe.wat -o -` preserves the selected `i32.load` and the later sibling call through tuple scratch:

- `local.tee` stores the selected load result;
- a `drop` preserves selected-lane evaluation before the sibling;
- a second `drop` preserves the later effectful sibling call;
- `local.get` returns the selected value.

Starshine does not need to match Binaryen's raw tuple-scratch spelling for direct-HOT status coverage, but it must preserve the same selected-load-before-sibling-call order and return the selected load value.

## Starshine coverage

`src/passes/optimize_instructions_test.mbt` adds:

- `optimize-instructions preserves selected trapping tuple.extract lane with effectful sibling`

The direct-HOT fixture builds a one-use tuple whose selected lane is an exact `i32.load`, whose later sibling is an `i64`-returning call, and whose final sibling is a pure constant. After OI, Starshine must produce a block with:

1. a `local.set` storing the exact selected `i32.load`;
2. a `drop` preserving the sibling `Call`;
3. a `local.get` reloading the selected value from the same temp local.

The focused test passed immediately, so no implementation change was needed. This is coverage/status evidence for an already implemented selected-lane localization path.

## Validation

- Binaryen oracle probe above passed.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*selected trapping tuple.extract lane with effectful sibling*'` passed `1/1`.

## Remaining boundaries

This does not close OI-M. Public tuple text/binary fixture coverage, tuple-scratch localization for multi-result selected children and siblings, broader multivalue block reconstruction, multi-use tuple extraction, full `simplify-locals` and `tuple-optimization` public parity, and the recorded direct-HOT full-neighbor verifier failure (`InvalidChildRef(3, 0, 0)`) remain open.
