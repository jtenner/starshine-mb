# Optimize-instructions OI-M multi-result tuple sibling boundary

Date: 2026-06-25

## Question

Can Starshine's current `tuple.extract(tuple.make(...))` OI-M helper safely cover non-selected tuple siblings that produce multiple results?

## Binaryen `version_130` evidence

Probe: `.tmp/oi-m-tuple-multiresult-sibling-probe.wat`

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-multiresult-sibling-probe.wat -o -
```

Binaryen accepts the fixture and preserves the multi-result sibling effects by materializing tuple scratch locals and scalar drops around the selected result. It does not simply erase the multi-result sibling.

## Starshine status

Starshine's current direct-HOT OI-M tuple helper covers:

- one-use `tuple.extract(tuple.make(...))` forwarding when non-selected siblings are pure;
- selected-lane localization when non-selected effectful siblings produce at most one value.

It intentionally does not yet reconstruct tuple scratch for non-selected siblings with more than one result. A new focused boundary test keeps this explicit:

- `src/passes/optimize_instructions_test.mbt`: `optimize-instructions intentionally keeps tuple.extract with multi-result sibling boundary`

The test builds a direct-HOT tuple whose selected lane is a scalar local and whose non-selected sibling is a multi-result effectful call. After `optimize-instructions`, the root remains `TupleExtract`, the producer remains `TupleMake`, and the multi-result `Call` remains available.

## Validation

- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*multi-result sibling*'` passed `1/1`.

## Classification

Boundary-only OI-M slice. This is a documented tuple-scratch localization gap, not parity. Reopen for implementation when Starshine has a helper that can preserve and drop multi-result sibling lanes in Binaryen-compatible order without invalid HOT/lowered output.
