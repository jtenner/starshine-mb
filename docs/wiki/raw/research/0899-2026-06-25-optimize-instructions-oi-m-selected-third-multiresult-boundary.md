# OptimizeInstructions OI-M selected third multi-result tuple boundary

## Summary

This boundary/status slice extends the OI-M multi-result selected-lane tuple-scratch evidence to the third scalar result of a multi-result child.

Binaryen `version_130` can localize the selected value through tuple scratch and scalar temps. Starshine intentionally keeps the direct-HOT `tuple.extract(tuple.make(...))` spelling for this shape until a safe multi-result tuple-scratch localizer exists.

## Binaryen oracle

Probe: `.tmp/oi-m-tuple-multiresult-selected-third-probe.wat`.

Observed with:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-multiresult-selected-third-probe.wat -o -
```

Binaryen rewrites the selected third lane of an imported `(result i64 i32 f64)` call by:

- storing the multi-result call in tuple scratch,
- dropping the earlier non-selected `i64` lane,
- rebuilding/localizing a tuple containing the selected `f64` lane plus the later scalar sibling,
- storing/dropping the selected `f64` scalar temp,
- returning the selected scalar local.

## Starshine coverage

Added direct-HOT boundary test `optimize-instructions intentionally keeps tuple.extract with multi-result selected third lane boundary` in `src/passes/optimize_instructions_test.mbt`.

The fixture constructs a `tuple.make` whose first child is a three-result call and whose selected extract index is the third call result. The test asserts that `optimize-instructions` succeeds but keeps the `TupleExtract`, `TupleMake`, and multi-result `Call` nodes unchanged.

This is boundary/status evidence, not a red-first implementation slice. It prevents overgeneralizing the covered single-result tuple.extract localizer or the earlier multi-result boundary variants to a third-lane multi-result selected child.

## Validation

- Binaryen oracle command above passed.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*selected third lane*'` passed `1/1`.

## Remaining work

OI-M still needs a real multi-result tuple-scratch localizer for selected and sibling lanes before Starshine can claim Binaryen parity for these multi-result tuple shapes. Public/binary tuple fixture coverage remains limited by local tuple text/parser support, and the full `simplify-locals` replay blocker that previously produced `InvalidChildRef(3, 0, 0)` remains open.
