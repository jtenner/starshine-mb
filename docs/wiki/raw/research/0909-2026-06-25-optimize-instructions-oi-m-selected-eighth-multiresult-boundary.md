# Optimize Instructions OI-M Selected Eighth Multi-Result Tuple Boundary

Date: 2026-06-25

## Question

How does Binaryen `version_130` handle a `tuple.extract` selecting the eighth scalar result from a multi-result tuple child, and should Starshine localize it yet?

## Oracle probe

Probe: `.tmp/oi-m-tuple-multiresult-selected-eighth-probe.wat`

```wat
(module
  (import "env" "many" (func $many (result i32 i64 f32 f64 i32 i64 f32 f64)))
  (func (result f64)
    (tuple.extract 9 7
      (tuple.make 9
        (call $many)
        (f64.const 9)))))
```

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-multiresult-selected-eighth-probe.wat -o -
```

Observed Binaryen output:

- Binaryen materializes the eight-result call into a tuple scratch local.
- It drops the first scalar lane from that scratch, stores/drops the selected eighth `f64` lane through a scalar temp, then reloads that temp as the function result.
- The non-selected trailing `f64.const 9` sibling disappears because it is pure and not needed after localization.

## Starshine slice

This is a boundary/status slice, not an implementation slice. Starshine's current direct-HOT tuple localizer only proves selected children with a single result plus already-covered single-result effectful sibling drop/localization. Multi-result selected children require tuple-scratch plus scalar-temp reconstruction that is not implemented safely yet.

Added focused direct-HOT coverage in `src/passes/optimize_instructions_test.mbt` with `optimize-instructions intentionally keeps tuple.extract with multi-result selected eighth lane boundary`. The test asserts that Starshine keeps the `TupleExtract` at index `7`, the `TupleMake`, and the multi-result `Call` unchanged until a safe selected-child tuple-scratch localizer exists.

## Validation

- `wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-multiresult-selected-eighth-probe.wat -o -` passed and showed the tuple-scratch localization described above.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*selected eighth lane*'` passed `1/1`.

Full required slice validation is recorded in the commit that cites this note.

## Remaining work

Remaining OI-M work includes implementing safe multi-result selected/sibling tuple-scratch localization, public/binary tuple fixture coverage where representable, replay/reduction of the full `simplify-locals` `InvalidChildRef(3, 0, 0)` blocker, dedicated `tuple-optimization` neighbor reductions, and broader tee/drop reconstruction beyond the covered single-result selected/sibling localizer.
