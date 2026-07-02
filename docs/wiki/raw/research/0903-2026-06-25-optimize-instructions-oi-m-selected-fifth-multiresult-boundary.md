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

## 2026-07-02 supersession

This boundary is superseded for the direct one-use arity-5 selected-child shape. The former boundary test in `src/passes/optimize_instructions_test.mbt` is now positive coverage named `optimize-instructions localizes fifth lane from five-result selected tuple child`.

- Red-first focused run `moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --filter '*five-result selected tuple child*'` failed 0/1 before implementation because the root stayed `TupleExtract`.
- `src/passes/optimize_instructions.mbt` now admits selected-child arity 5, stores all selected child result lanes to scratch locals in stack-pop order, and reloads lane index 4.
- The change remains bounded: selected-child arities 6+, multi-result non-selected siblings, multi-use tuple producers, control/EH siblings, and generalized tuple-scratch reconstruction remain active OI-M work.

## Validation

- `wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-multiresult-selected-fifth-probe.wat -o .tmp/oi-m-tuple-multiresult-selected-fifth-probe.binaryen.20260702.wat` passed and showed Binaryen tuple-scratch localization.
- Red-first `moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --filter '*five-result selected tuple child*'` failed 0/1 before implementation, then passed 1/1 after the bounded arity-5 implementation.
- Focused `moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --filter '*tuple.extract*'` passed 32/32; full `optimize_instructions_test.mbt` passed 628/628; `moon fmt`, `moon info`, full `moon test`, and native `src/cmd` build passed with pre-existing warnings.
- Direct `.tmp/oi-m-five-result-selected-direct18-20260702` compared 18/18 with 18 raw mismatches, zero validation/generator/property/command failures, Binaryen cache 18/0, runtime checked/unsupported/failed 18/0/0, and runtime matrix all-equal 1/1.
- Grouped `.tmp/oi-m-five-result-selected-count108-20260702` compared 108/108 with 108 raw mismatches, zero validation/generator/property/command failures, Binaryen cache 108/0, runtime checked/unsupported/failed 108/0/0, runtime matrix all-equal 9/9, and all 18 tuple labels sampled.

## Remaining work

OI-M still needs selected-child arities 6+, multi-result non-selected siblings, multi-use tuple producers, control/EH siblings, public/binary tuple fixture coverage where representable, full `simplify-locals` replay for the `InvalidChildRef(3, 0, 0)` blocker, dedicated `tuple-optimization` neighbor reductions, generalized tuple-scratch reconstruction, and broader tee/drop reconstruction.
