# Optimize-instructions OI-M simplify-locals neighbor coverage

Date: 2026-06-25

## Question

Does the covered Starshine `tuple.extract(tuple.make(...))` selected-lane localization remain explicit and effect-preserving when the next local-cleanup neighbor is `simplify-locals-nostructure`?

## Binaryen `version_130` evidence

Probe: `.tmp/oi-m-tuple-probe.wat`

```sh
wasm-opt --all-features -S --optimize-instructions --simplify-locals-nostructure .tmp/oi-m-tuple-probe.wat -o -
```

For the probed effectful-sibling export, Binaryen keeps a temp-local spelling around the non-selected effect after the neighbor pass:

- `local.set` of the selected `i32.const 7`;
- `drop(call $effect)` for the non-selected tuple sibling;
- `local.get` of the selected temp.

This is neighbor evidence for the covered single-result sibling subset, not proof of broader tuple-scratch parity.

## Starshine status

Starshine's direct-HOT OI localizer already rewrites the same covered one-use, single-result effectful sibling subset into a block containing selected-lane `local.set`, sibling `drop`, and selected-lane `local.get`. New focused coverage now immediately runs `simplify-locals-nostructure` after `optimize-instructions` on that direct-HOT shape and asserts the temp-local/effect-drop block survives.

Test added:

- `src/passes/optimize_instructions_test.mbt`: `optimize-instructions tuple.extract localization survives simplify-locals-nostructure neighbor`

No pass implementation changed.

## Validation

- `wasm-opt --all-features -S --optimize-instructions --simplify-locals-nostructure .tmp/oi-m-tuple-probe.wat -o -` passed and kept the temp-local/effect-drop spelling for the effectful-sibling export.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*tuple.extract localization survives*'` passed `1/1`.

## Classification

Coverage/status OI-M slice. This narrows the open neighbor-interaction risk for the already-covered single-result effectful sibling subset. It does not implement tuple-scratch localization, multi-result selected lanes, multi-use tuple proofs, public text/binary tuple fixture coverage, or broader `tuple-optimization` / local-cleanup neighborhood signoff.
