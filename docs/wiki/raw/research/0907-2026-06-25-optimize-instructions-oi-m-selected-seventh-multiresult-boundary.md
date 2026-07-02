# Optimize Instructions OI-M Selected Seventh Multi-Result Tuple Boundary

Date: 2026-06-25

## Question

How does Binaryen `version_130` handle a `tuple.extract` selecting the seventh scalar result from a multi-result tuple child, and should Starshine localize it yet?

## Oracle probe

Probe: `.tmp/oi-m-tuple-multiresult-selected-seventh-probe.wat`

```wat
(module
  (import "env" "many" (func $many (result i32 i64 f32 f64 i32 i64 f32)))
  (func (result f32)
    (tuple.extract 8 6
      (tuple.make 8
        (call $many)
        (f32.const 9)))))
```

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-multiresult-selected-seventh-probe.wat -o -
```

Observed Binaryen output:

- Binaryen materializes the seven-result call into a tuple scratch local.
- It drops the first scalar lane from that scratch, stores/drops the selected seventh `f32` lane through a scalar temp, then reloads that temp as the function result.
- The non-selected trailing `f32.const 9` sibling disappears because it is pure and not needed after localization.

## Starshine slice

This boundary was superseded by the 2026-07-02 arity-7 implementation follow-up. Starshine's current direct-HOT tuple localizer proves selected children with one through seven scalar results plus already-covered single-result effectful sibling drop/localization. The former seven-result selected-child fail-closed case is now a positive bounded tuple-scratch/local-set slice.

Focused direct-HOT coverage in `src/passes/optimize_instructions_test.mbt` now uses `optimize-instructions localizes seventh lane from seven-result selected tuple child`. The test asserts that Starshine lowers the `TupleExtract` to a result block, stores all seven selected-child lanes to scratch locals in stack-pop order, and reloads the seventh lane from the corresponding scratch local.

## Validation

- `wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-multiresult-selected-seventh-probe.wat -o .tmp/oi-m-tuple-multiresult-selected-seventh-probe.binaryen.20260702.wat` passed and showed the tuple-scratch localization described above.
- Red-first `moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --filter '*seven-result selected tuple child*'` failed `0/1` before implementation because the root stayed `TupleExtract`, then passed `1/1` after `src/passes/optimize_instructions.mbt` admitted selected-child result count `7`.
- Focused tuple.extract tests passed `30/30`; full `optimize_instructions_test.mbt` passed `628/628`; `moon fmt`, `moon info`, full `moon test`, and native `src/cmd` build passed with pre-existing warnings.
- Direct `.tmp/oi-m-seven-result-selected-direct18-20260702` compared `18/18` with `18` raw mismatches and zero validation/generator/property/command failures.
- Grouped `.tmp/oi-m-seven-result-selected-count108-20260702` compared `108/108` with `108` raw mismatches, zero validation/generator/property/command failures, Binaryen cache `108/0`, runtime-checked metadata `108/108`, and all 18 tuple labels sampled.

## Remaining work

Remaining OI-M work includes selected-child arities 8+, multi-result non-selected sibling tuple-scratch localization, multi-use tuple producers, control/branch/EH sibling localization, public/binary tuple fixture coverage where representable, replay/reduction of the full `simplify-locals` `InvalidChildRef(3, 0, 0)` blocker, dedicated `tuple-optimization` neighbor reductions, and broader tee/drop reconstruction beyond the covered one-use selected/sibling localizer.
