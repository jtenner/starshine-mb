# Optimize Instructions OI-M Selected-Twenty-Third Child Multi-Result Boundary

Date: 2026-07-02

## Question

Does Binaryen `version_130` localize the selected twenty-third scalar result from a multi-result tuple child under `--optimize-instructions`, and should Starshine claim that behavior after the arity-22 slice?

## Probe

Input fixture: `.tmp/oi-m-tuple-multiresult-selected-twenty-third-child-probe.wat`.

```wat
(module
  (import "env" "many" (func $many (result i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 i32 i64 f32 f64 i32 i64 f32 i64 f32 f64 i32 i64 f32)))
  (func (result f32)
    (tuple.extract 24 22
      (tuple.make 24
        (call $many)
        (i32.const 23)))))
```

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-multiresult-selected-twenty-third-child-probe.wat -o .tmp/oi-m-tuple-multiresult-selected-twenty-third-child-probe.binaryen.20260702.wat
```

## Finding

Binaryen localizes the twenty-three-result call into a tuple scratch local, extracts and drops the first lane, stores the selected twenty-third `f32` lane in a scalar temp, drops that temp write, and returns the scalar temp. This is the same tuple-scratch family observed for selected arities 2 through 22.

## Starshine coverage

The 2026-07-02 arity-23 implementation slice changed the direct-HOT boundary coverage into positive coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions localizes twenty-third lane from twenty-three-result selected tuple child`

The positive test failed red-first because Starshine kept `TupleExtract`, then passed after `src/passes/optimize_instructions.mbt` admitted selected-child result count 23. The test asserts the replacement is a block with 23 stack-pop-order `local.set` roots and a final `local.get` for the selected twenty-third lane.

## Validation and fuzz evidence

- Red-first: `moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --filter '*twenty-third lane*'` failed 0/1 before implementation because the shape stayed `TupleExtract`.
- Post-fix focused twenty-third lane test passed 1/1.
- New next-boundary test `optimize-instructions intentionally keeps tuple.extract with multi-result selected twenty-fourth child-lane boundary` passed 1/1.
- Focused `*tuple.extract*` tests passed 24/24 and full `optimize_instructions_test.mbt` passed 638/638.
- `moon fmt`, `moon info`, full `moon test` (7240/7240), and native `src/cmd` build passed with pre-existing warnings.
- Direct `.tmp/oi-m-twenty-three-result-selected-direct18-20260702` compared 18/18 with 18 raw mismatches, zero validation/generator/property/command failures, Binaryen cache 18/0, runtime checked/unsupported/failed 18/0/0, and runtime matrix all-equal 1/1.
- Grouped `.tmp/oi-m-twenty-three-result-selected-count108-20260702` compared 108/108 with 108 raw mismatches, zero validation/generator/property/command failures, Binaryen cache 108/0, runtime checked/unsupported/failed 108/0/0, runtime matrix all-equal 9/9, and all 18 OI-M tuple labels sampled.

## Status

Starshine's current tuple.extract OI localizer now supports direct one-use selected children through arity 24. This note is retained as source/probe history, not an active direct one-use arity-23 blocker. Remaining OI-M work includes selected-child arities 25+, multi-result non-selected siblings, multi-use tuple producers, generalized tuple-scratch reconstruction/localization, control/EH sibling localization, broader randomized/runtime evidence, and public/binary tuple fixture coverage where representable. Reopen this boundary if the arity-23 implementation regresses, if broader wrappers show an effect/trap/validation hazard, if Binaryen source/oracle behavior changes, or if the direct-HOT proof cannot be lifted to public tuple fixtures.
