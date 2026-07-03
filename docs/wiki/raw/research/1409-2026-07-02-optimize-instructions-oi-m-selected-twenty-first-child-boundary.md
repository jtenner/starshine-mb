# Optimize Instructions OI-M Selected-Twenty-First Child Multi-Result Boundary

Date: 2026-07-02

## Question

Does Binaryen `version_130` localize the selected twenty-first scalar result from a multi-result tuple child under `--optimize-instructions`, and should Starshine claim that behavior after the arity-20 slice?

## Probe

Input fixture: `.tmp/oi-m-tuple-multiresult-selected-twenty-first-child-probe.wat`.

```wat
(module
  (import "env" "many" (func $many (result i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 i32 i64 f32 f64 i32 i64 f32 i64 f32 f64 i32)))
  (func (result i32)
    (tuple.extract 22 20
      (tuple.make 22
        (call $many)
        (i32.const 21)))))
```

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-multiresult-selected-twenty-first-child-probe.wat -o .tmp/oi-m-tuple-multiresult-selected-twenty-first-child-probe.binaryen.20260702.wat
```

## Finding

Binaryen localizes the twenty-one-result call into a tuple scratch local, extracts and drops the first lane, stores the selected twenty-first `i32` lane in a scalar temp, drops that temp write, and returns the scalar temp. This is the same tuple-scratch family observed for selected arities 2 through 20.

## Starshine coverage

Added direct-HOT positive coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions localizes twenty-first lane from twenty-one-result selected tuple child`

Red-first evidence: the focused twenty-first-lane test failed before implementation because Starshine kept the root as `TupleExtract`. The implementation then widened the bounded direct one-use selected-child allowlist from arity 20 to arity 21 and the test passed.

Validation/fuzz evidence from the implementing slice:

- `moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --filter '*twenty-first lane*'` passed after the fix.
- `moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --filter '*twenty-second child-lane*'` kept the next boundary passing.
- `moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --filter '*tuple.extract*'` passed.
- Direct and grouped OI-M compare/runtime evidence is recorded in `docs/wiki/log.md` and `docs/wiki/binaryen/passes/optimize-instructions/parity-matrix.json`.

## Status

Starshine's current tuple.extract OI localizer now supports direct one-use selected children through arity 21. This note is retained as source/probe history, not an active direct one-use arity-21 blocker. Remaining OI-M work includes selected-child arities 22+, multi-result non-selected siblings, multi-use tuple producers, generalized tuple-scratch reconstruction/localization, control/EH sibling localization, broader randomized/runtime evidence, and public/binary tuple fixture coverage where representable. Reopen this boundary if the arity-21 implementation regresses, if public tuple fixture support exposes a stronger Binaryen-shaped test, or if a future Binaryen source/oracle refresh changes this behavior.
