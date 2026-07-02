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

Superseded for the direct one-use arity-8 selected-child case by the 2026-07-02 implementation follow-up. Starshine's direct-HOT tuple localizer now proves selected children with one through eight scalar results plus already-covered single-result effectful/trapping sibling drop/localization. The ninth-result selected-child case is now the next fail-closed arity boundary.

Focused direct-HOT coverage in `src/passes/optimize_instructions_test.mbt` now uses `optimize-instructions localizes eighth lane from eight-result selected tuple child`. The test asserts that Starshine rewrites the direct one-use shape into a block that stores all eight selected-child result lanes in stack-pop order and reloads the selected eighth lane from its scratch local.

## Validation

- `wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-multiresult-selected-eighth-probe.wat -o .tmp/oi-m-tuple-multiresult-selected-eighth-probe.binaryen.20260702.wat` passed and showed the tuple-scratch localization described above.
- Red-first `moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --filter '*eight-result selected tuple child*'` failed `0/1` before implementation because the shape stayed `TupleExtract`, then passed `1/1` after the arity cap admitted eight selected-child result lanes.
- Focused `tuple.extract` tests passed `29/29`; full `optimize_instructions_test.mbt` passed `628/628`; `moon fmt`, `moon info`, full `moon test`, and native `src/cmd` build passed with pre-existing warnings.
- Direct `.tmp/oi-m-eight-result-selected-direct18-20260702` compared `18/18` with `18` raw mismatches and zero validation/generator/property/command failures, runtime checked/unsupported/failed `18/0/0`, and runtime matrix all-equal `1/1`.
- Grouped `.tmp/oi-m-eight-result-selected-count108-20260702` compared `108/108` with `108` raw mismatches and zero validation/generator/property/command failures, runtime checked/unsupported/failed `108/0/0`, runtime matrix all-equal `9/9`, and all 18 tuple labels sampled.

## Remaining work

Remaining OI-M work includes selected-child arities 9+, multi-result non-selected sibling tuple-scratch localization, multi-use tuple producers, control/branch/EH sibling localization, public/binary tuple fixture coverage where representable, replay/reduction of the full `simplify-locals` `InvalidChildRef(3, 0, 0)` blocker, dedicated `tuple-optimization` neighbor reductions, and broader tee/drop reconstruction beyond the covered one-use selected/sibling localizer.
