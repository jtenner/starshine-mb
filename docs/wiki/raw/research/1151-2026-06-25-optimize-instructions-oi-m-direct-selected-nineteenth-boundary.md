# OptimizeInstructions OI-M direct selected-nineteenth boundary

Date: 2026-06-25

## Question

Does Binaryen `version_130` synthesize tuple scratch for a direct `tuple.extract 19 18 (call $multi)` when the caller directly selects the nineteenth scalar result and there are no sibling `tuple.make` values to preserve or drop?

## Binaryen oracle

Probe file: `.tmp/oi-m-tuple-multiresult-selected-nineteenth-probe.wat`.

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-multiresult-selected-nineteenth-probe.wat -o -
```

Observed result:

- Binaryen prints the nineteen-result callee body as `tuple.make 19`.
- The caller still contains direct `tuple.extract 19 18 (call $multi)`.
- No tuple scratch locals or sibling-preserving drop sequence is synthesized for this no-sibling direct call shape.

## Starshine result

Added direct-HOT boundary/status coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions intentionally keeps direct multi-result selected nineteenth lane boundary`

The fixture builds a nineteen-result `Call`, extracts lane `18`, runs `optimize-instructions`, and asserts the root remains `TupleExtract` over the same `Call`. This is not red-first implementation work; it extends the direct no-sibling selected-fifteenth through selected-eighteenth boundary series with fresh Binaryen evidence.

## Validation

- Binaryen oracle passed with the command above.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*selected nineteenth lane*'` passed `1/1`.

## Remaining work

This does not implement selected-child tuple-scratch localization. Remaining OI-M work still includes multi-result selected/sibling tuple-scratch localization, reducing or classifying sibling-bearing selected-lane Binaryen validation failures if relevant, full `simplify-locals` replay/reduction for the `InvalidChildRef(3, 0, 0)` blocker, dedicated `tuple-optimization` neighbor reductions, and broader tee/drop reconstruction.
