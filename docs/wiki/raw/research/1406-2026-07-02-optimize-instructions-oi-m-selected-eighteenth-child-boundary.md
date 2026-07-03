# Optimize Instructions OI-M Selected-Eighteenth Child Multi-Result Slice

Date: 2026-07-02

## Question

Does Binaryen `version_130` localize the selected eighteenth scalar result from a multi-result tuple child under `--optimize-instructions`, and should Starshine claim that behavior after the arity-17 slice?

## Probe

Input fixture: `.tmp/oi-m-tuple-multiresult-selected-eighteenth-child-probe.wat`.

```wat
(module
  (import "env" "many" (func $many (result i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 i32 i64 f32 f64 i32 i64 f32 i64)))
  (func (result i64)
    (tuple.extract 19 17
      (tuple.make 19
        (call $many)
        (i32.const 18)))))
```

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-multiresult-selected-eighteenth-child-probe.wat -o .tmp/oi-m-tuple-multiresult-selected-eighteenth-child-probe.binaryen.20260702.wat
```

## Finding

Binaryen localizes the eighteen-result call into a tuple scratch local, extracts and drops the first lane, stores the selected eighteenth `i64` lane in a scalar temp, drops that temp write, and returns the scalar temp. This is the same tuple-scratch family observed for the selected arity-2 through arity-17 probes.

## Starshine coverage

Changed direct-HOT positive coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions localizes eighteenth lane from eighteen-result selected tuple child`

The test initially failed red-first because Starshine kept `TupleExtract` index `17`, the `TupleMake`, and the eighteen-result selected `Call` unchanged. The implementation then widened `optimize_instructions_try_fold_tuple_extract_tuple_make` to admit selected children with eighteen scalar results, storing selected-child results to scratch locals in stack-pop order before reloading the requested lane.

A new next-boundary test, `optimize-instructions intentionally keeps tuple.extract with multi-result selected nineteenth child-lane boundary`, is backed by `.tmp/oi-m-tuple-multiresult-selected-nineteenth-child-probe.wat` and `.tmp/oi-m-tuple-multiresult-selected-nineteenth-child-probe.binaryen.20260702.wat`.

## Validation and fuzz evidence

- Red-first: `moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --filter '*eighteenth lane*'` failed 1/2 before implementation because the selected-child case stayed `TupleExtract` while the direct eighteenth-lane boundary still passed.
- Focused post-fix eighteenth filter passed 2/2; focused nineteenth child-lane boundary passed 1/1; focused tuple.extract tests passed 24/24; full `optimize_instructions_test.mbt` passed 633/633.
- `moon fmt`, `moon info`, full `moon test` (7235/7235), and native `src/cmd` build passed with pre-existing warnings.
- Direct `.tmp/oi-m-eighteen-result-selected-direct18-20260702` compared 18/18 with 0 normalized, 0 cleanup-normalized, 18 raw mismatches, zero validation/generator/property/command failures, Binaryen cache 18/0, runtime checked/unsupported/failed 18/0/0, and runtime matrix all-equal 1/1.
- Grouped `.tmp/oi-m-eighteen-result-selected-count108-20260702` compared 108/108 with 0 normalized, 0 cleanup-normalized, 108 raw mismatches, zero validation/generator/property/command failures, Binaryen cache 108/0, runtime checked/unsupported/failed 108/0/0, runtime matrix all-equal 9/9, and all 18 tuple labels sampled.

## Status

Starshine's current tuple.extract OI localizer now supports direct one-use selected children through arity 18. This note is retained as source/probe history, not an active direct one-use arity-18 blocker. Remaining OI-M work includes selected-child arities 19+, multi-result non-selected siblings, multi-use tuple producers, generalized tuple-scratch reconstruction/localization, control/EH sibling localization, broader randomized/runtime evidence, and public/binary tuple fixture coverage where representable. Reopen this boundary if the arity-18 implementation regresses, if public/binary tuple fixture coverage exposes a lowering gap for this shape, or if a future Binaryen source/oracle refresh stops localizing it.
