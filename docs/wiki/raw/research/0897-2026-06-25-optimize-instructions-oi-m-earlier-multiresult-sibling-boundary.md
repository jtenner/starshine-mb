# OptimizeInstructions OI-M earlier multi-result tuple sibling boundary

Date: 2026-06-25

## Question

Can Starshine's current direct-HOT `tuple.extract(tuple.make(...))` localizer safely claim parity for a non-selected earlier tuple sibling that produces multiple results?

## Binaryen oracle

Probe: `.tmp/oi-m-tuple-multiresult-earlier-sibling-probe.wat`

```wat
(module
  (func $pair (result i64 i32)
    (i64.const 1)
    (i32.const 2))
  (func (param $x i32) (result i32)
    (tuple.extract 3 2
      (tuple.make 2
        (call $pair)
        (local.get $x))))
)
```

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-multiresult-earlier-sibling-probe.wat -o -
```

Result: Binaryen accepts the fixture and emits tuple-scratch reconstruction. It stores the multi-result `$pair` call in a tuple scratch, drops the earlier scalar lane(s), rebuilds an intermediate tuple with the selected local, then stores/reloads the selected scalar result. This proves the shape belongs to Binaryen's OI tuple-scratch surface, but it also requires multi-result tuple scratch that Starshine does not yet implement.

## Starshine status

Added direct-HOT boundary coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions intentionally keeps tuple.extract with earlier multi-result sibling boundary`

The fixture builds a one-use tuple whose earlier child is a two-result call and whose selected lane is a scalar `local.get`. After `optimize-instructions`, Starshine keeps the root as `TupleExtract`, keeps the `TupleMake`, and keeps the multi-result `Call` available.

## Classification

Boundary/status evidence, not an implementation slice. This keeps the multi-result sibling tuple-scratch gap explicit and prevents the covered single-result sibling localizer from being overgeneralized.

## Validation

- Binaryen oracle command above passed.
- Focused Starshine command passed: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*earlier multi-result sibling*'` (`1/1`).

## Remaining work

OI-M still needs a real multi-result selected/sibling tuple-scratch localizer, public/binary tuple fixture coverage where representable, full `simplify-locals` replay for the known verifier blocker, dedicated `tuple-optimization` neighbor reductions, and broader tee/drop reconstruction.
