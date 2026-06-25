# Optimize-instructions OI-M selected-fourth multi-result tuple boundary

Date: 2026-06-25

## Question

How should Starshine treat `tuple.extract` when the selected lane is the fourth scalar result produced by a multi-result child?

## Binaryen oracle

Probe: `.tmp/oi-m-tuple-multiresult-selected-fourth-probe.wat`.

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-multiresult-selected-fourth-probe.wat -o -
```

Result: Binaryen `version_130` localizes the selected fourth result from an imported `(result i32 i64 f32 f64)` call through tuple scratch and scalar temps before returning the selected `f64` lane. The emitted shape drops earlier tuple lanes, stores/drops the selected lane through a scalar temp, and reloads the selected value.

## Starshine boundary

Added direct-HOT boundary coverage in `src/passes/optimize_instructions_test.mbt` (`optimize-instructions intentionally keeps tuple.extract with multi-result selected fourth lane boundary`).

The test constructs a tuple where a multi-result call contributes four scalar lanes and an extra scalar sibling follows it, then selects lane `3`. Starshine currently keeps the direct `TupleExtract`, `TupleMake`, and multi-result `Call` unchanged because the existing direct tuple-extract localizer only proves single-result selected children.

This is boundary/status evidence, not a red-first implementation slice. It extends the selected multi-result child boundary beyond the first, second, and third selected-lane fixtures and prevents overgeneralizing the covered single-result selected-child localizer.

## Evidence

- Binaryen oracle command above passed.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*selected fourth lane*'` passed `1/1`.

## Remaining work

A real selected-child multi-result tuple-scratch localizer remains open. Related OI-M work includes multi-result non-selected siblings, public/binary tuple fixture coverage where representable, full `simplify-locals` replay for the `InvalidChildRef(3, 0, 0)` blocker, dedicated `tuple-optimization` neighbor reductions, and broader tee/drop reconstruction.
