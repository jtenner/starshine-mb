# Optimize Instructions OI-M: earlier/later tuple sibling neighbor coverage

Date: 2026-06-25

## Summary

This slice adds focused direct-HOT neighbor coverage for the already implemented single-result `tuple.extract(tuple.make(...))` localization when both an earlier and a later non-selected sibling have effects.

The test runs `optimize-instructions` and then `simplify-locals-nostructure` on a direct-HOT tuple shape with:

- an earlier effectful single-result sibling;
- a selected scalar `local.get` lane;
- a pure non-selected sibling;
- a later effectful single-result sibling.

Starshine must keep the OI-localized block valid and effect-preserving through the neighbor pass: earlier drop, selected temp set, later drop, selected temp reload.

## Binaryen evidence and scope

Probe: `.tmp/oi-m-tuple-earlier-later-neighbor-probe.wat`

Commands:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-earlier-later-neighbor-probe.wat -o -
wasm-opt --all-features -S --optimize-instructions --simplify-locals-nostructure .tmp/oi-m-tuple-earlier-later-neighbor-probe.wat -o -
```

Binaryen `version_130` preserves the earlier and later calls while selecting the middle lane. Under direct OI it uses a temp around the selected lane; after `simplify-locals-nostructure`, the temp can disappear for the probed public WAT because the selected lane is the original `local.get`.

Starshine's local WAT parser does not accept this tuple text syntax through `pass_test_run_pipeline`, so this slice is intentionally direct-HOT neighbor coverage, not public text-pipeline parity. Public tuple/multivalue reconstruction and tuple-scratch localization remain open.

## Starshine change

- `src/passes/optimize_instructions_test.mbt` adds `optimize-instructions earlier and later tuple.extract localization survives simplify-locals-nostructure neighbor`.
- No implementation change was needed; this locks the existing OI localization and neighbor pass interaction for the covered single-result effectful-sibling subset.

## Validation

- Focused `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*earlier and later tuple.extract localization survives simplify-locals-nostructure*'` passed `1/1`.
- `moon fmt` passed.
- `moon test src/passes` passed `2803/2803`.

## Remaining boundaries

This does not close OI-M. Public tuple text/binary fixture coverage, tuple-scratch localization for multi-result selected children and siblings, broader multivalue block reconstruction, multi-use tuple extraction, full `simplify-locals` and `tuple-optimization` public parity, and the recorded direct-HOT full-neighbor verifier failure (`InvalidChildRef(3, 0, 0)`) remain open.
