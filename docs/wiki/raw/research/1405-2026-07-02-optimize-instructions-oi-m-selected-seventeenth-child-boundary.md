# Optimize Instructions OI-M Selected-Seventeenth Child Multi-Result Slice

Date: 2026-07-02

## Question

Does Binaryen `version_130` localize the selected seventeenth scalar result from a multi-result tuple child under `--optimize-instructions`, and should Starshine claim that behavior after the arity-16 slice?

## Probe

Input fixture: `.tmp/oi-m-tuple-multiresult-selected-seventeenth-child-probe.wat`.

```wat
(module
  (import "env" "many" (func $many (result i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 i32 i64 f32 f64 i32 i64 f32)))
  (func (result f32)
    (tuple.extract 18 16
      (tuple.make 18
        (call $many)
        (i32.const 17)))))
```

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-multiresult-selected-seventeenth-child-probe.wat -o .tmp/oi-m-tuple-multiresult-selected-seventeenth-child-probe.binaryen.20260702.wat
```

## Finding

Binaryen localizes the seventeen-result call into a tuple scratch local, extracts and drops the first lane, stores the selected seventeenth `f32` lane in a scalar temp, drops that temp write, and returns the scalar temp. This is the same tuple-scratch family observed for the selected arity-2 through arity-16 probes.

## Starshine coverage

Added direct-HOT positive coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions localizes seventeenth lane from seventeen-result selected tuple child`

The test initially failed red-first because Starshine kept `TupleExtract` index `16`, the `TupleMake`, and the seventeen-result selected `Call` unchanged. The implementation then widened `optimize_instructions_try_fold_tuple_extract_tuple_make` to admit selected children with seventeen scalar results, storing selected-child results to scratch locals in stack-pop order before reloading the requested lane.

The former next-boundary test for the eighteenth child-lane was superseded by the later arity-18 implementation slice. The current next-boundary test is `optimize-instructions intentionally keeps tuple.extract with multi-result selected nineteenth child-lane boundary`, backed by `.tmp/oi-m-tuple-multiresult-selected-nineteenth-child-probe.wat` and `.tmp/oi-m-tuple-multiresult-selected-nineteenth-child-probe.binaryen.20260702.wat`.

## Status

Starshine's current tuple.extract OI localizer now supports direct one-use selected children through arity 19. This note is retained as source/probe history, not an active direct one-use arity-17 blocker. Remaining OI-M work includes selected-child arities 20+, multi-result non-selected siblings, multi-use tuple producers, generalized tuple-scratch reconstruction/localization, control/EH sibling localization, broader randomized/runtime evidence, and public/binary tuple fixture coverage where representable. Reopen this boundary if the arity-17 implementation regresses, if public/binary tuple fixture coverage exposes a lowering gap for this shape, or if a future Binaryen source/oracle refresh stops localizing it.
