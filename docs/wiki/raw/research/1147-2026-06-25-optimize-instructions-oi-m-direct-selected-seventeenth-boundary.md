---
kind: research
status: supported
created: 2026-06-25
sources:
  - ../../binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md
  - ../../../wiki/binaryen/passes/optimize-instructions/index.md
  - ../../../wiki/binaryen/passes/optimize-instructions/starshine-strategy.md
  - ../../../../src/passes/optimize_instructions_test.mbt
---

# OptimizeInstructions OI-M direct selected-seventeenth multi-result boundary

## Question

Does Binaryen `version_130` localize a direct `tuple.extract 17 16 (call $multi)` through tuple scratch when there are no sibling tuple values to preserve or drop?

## Evidence

Probe: `.tmp/oi-m-tuple-multiresult-selected-seventeenth-probe.wat`:

```wat
(module
  (type $multi_t (func (result i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 i32 i64 f32 f64 i32 i64 i32)))
  (func $multi (type $multi_t)
    i32.const 0
    i64.const 1
    f32.const 2
    f64.const 3
    i32.const 4
    i64.const 5
    f32.const 6
    f64.const 7
    i32.const 8
    i64.const 9
    i32.const 10
    i64.const 11
    f32.const 12
    f64.const 13
    i32.const 14
    i64.const 15
    i32.const 16)
  (func (result i32)
    call $multi
    tuple.extract 17 16))
```

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-multiresult-selected-seventeenth-probe.wat -o -
```

Binaryen kept the direct `tuple.extract 17 16 (call $multi)` in the caller. It printed the callee body as a `tuple.make 17`, but did not synthesize tuple scratch locals around the caller's direct no-sibling selected lane.

## Starshine coverage

Added direct-HOT boundary/status test `optimize-instructions intentionally keeps direct multi-result selected seventeenth lane boundary` in `src/passes/optimize_instructions_test.mbt`.

The test constructs a seventeen-result `Call` node and a direct `TupleExtract` of lane `16`, then asserts the pass leaves the extract and call unchanged. This is boundary/status evidence, not red-first implementation work. It extends the direct no-sibling selected-fifteenth and selected-sixteenth boundaries and remains narrower than sibling-bearing selected-child tuple-scratch localization.

## Validation

- `wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-multiresult-selected-seventeenth-probe.wat -o -` — passed; Binaryen kept direct `tuple.extract 17 16 (call $multi)`.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*selected seventeenth lane*'` — passed `1/1`.

## Follow-up

Broader OI-M work remains open: multi-result selected/sibling tuple-scratch localization, the sibling-bearing fifteenth-lane Binaryen validation-failure triage if still relevant, public/binary tuple fixture coverage where representable, the full `simplify-locals` `InvalidChildRef(3, 0, 0)` blocker, dedicated `tuple-optimization` neighbor reductions, and broader tee/drop reconstruction.
