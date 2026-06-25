# Optimize Instructions OI-M Selected Fifth Multi-Result Tuple Boundary

Date: 2026-06-25

## Question

How does Binaryen `version_130` handle `tuple.extract` selecting the fifth scalar lane from a multi-result call that is embedded in a larger tuple, and should Starshine broaden its direct selected-child tuple localizer?

## Oracle probe

Probe: `.tmp/oi-m-tuple-multiresult-selected-fifth-probe.wat`

```wat
(module
  (func $penta (import "m" "penta") (result i32 i64 f32 f64 i32))
  (func $selected_fifth (export "selected_fifth") (result i32)
    (tuple.extract 6 4
      (tuple.make 2
        (call $penta)
        (i64.const 9))))
)
```

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-multiresult-selected-fifth-probe.wat -o -
```

Observed Binaryen output:

- Binaryen creates a tuple scratch local for the five-result imported call.
- It extracts/drops the earlier lanes from that scratch, builds a smaller tuple containing the selected fifth lane plus the later `i64.const`, stores the selected scalar in an `i32` temp, drops it once as part of tuple-localization reconstruction, then returns the temp.
- This is the same tuple-scratch localization family as the earlier selected first/second/third/fourth multi-result boundary slices, widened to a five-result selected-child producer.

## Starshine slice

Added direct-HOT boundary coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions intentionally keeps tuple.extract with multi-result selected fifth lane boundary` constructs a tuple whose selected child is a five-result call and whose later sibling is a pure `i64.const`.
- The test asserts Starshine leaves the root `TupleExtract`, `TupleMake`, selected `Call`, and index `4` unchanged.
- This is intentionally boundary/status evidence, not a behavior implementation slice. Starshine's current selected-child localizer is only proven for single-result selected children. A correct Binaryen-parity implementation for multi-result selected children needs tuple scratch plus scalar temp reconstruction, not a direct generalization of the single-result path.

## Validation

- `wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-multiresult-selected-fifth-probe.wat -o -` passed and showed Binaryen tuple-scratch localization.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*selected fifth lane*'` is the focused Starshine boundary test for this slice.

Full required slice validation is recorded in the commit that cites this note.

## Remaining work

OI-M still needs a real multi-result selected/sibling tuple-scratch localizer before Starshine should match Binaryen on these selected-child shapes. Existing blockers also remain: public/binary tuple fixture coverage where representable, full `simplify-locals` replay for the `InvalidChildRef(3, 0, 0)` blocker, dedicated `tuple-optimization` neighbor reductions, and broader tee/drop reconstruction.
