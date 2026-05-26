# SGO loop independent segment-drop prefix

## Question

Can `[SGO]003C5` extend the narrow direct-loop prefix matcher from independent grow/drop effects to operandless `elem.drop` and `data.drop` effects before the yielded candidate `global.get`?

## Binaryen evidence

Focused probes with Binaryen `wasm-opt --all-features --simplify-globals-optimizing -S` on the exact loop shape:

```wat
loop (result i32)
  elem.drop $e
  global.get $once
end
if
  i32.const 1
  global.set $once
end
```

and the matching `data.drop $d` variant both made `$once` immutable and removed the fake `global.get` / `global.set` guard while preserving the segment-drop effect in the optimized function body. This is a narrow Binaryen-positive segment-drop prefix, not evidence for broad loop FlowScanner reuse.

## Local change

- Added focused positives in `src/passes/simplify_globals_optimizing_test.mbt` for loop-wrapped independent `elem.drop` and `data.drop` prefixes.
- Confirmed TDD failure first: `moon test src/passes` failed both new tests because `$once` stayed mutable.
- Updated `sgo_loop_condition_independent_global_set_prefix_read_matches(...)` in `src/passes/simplify_globals_optimizing.mbt` to accept only operandless `ElemDrop` / `DataDrop` as independent one-instruction loop prefixes before the final candidate read.

## Safety boundary

The slice preserves the existing narrow loop contract:

- only a non-branching value loop ending in one `global.get <candidate>` is accepted;
- the new effects have no value operands that could be candidate-derived;
- no caught control, branch, call, trapping candidate consumer, atomics, SIMD memory, relaxed SIMD, or broad FlowScanner behavior was enabled.

## Validation

- `moon test src/passes` passed after implementation: `1641/1641`.
- `moon fmt` completed successfully.
- `moon info` completed with the existing DAE unused-value warnings and no errors.
- Full `moon test` passed: `3717/3717`.
- Direct SGO fuzz passed the slice criteria: `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --out-dir .tmp/pass-fuzz-sgo-loop-segment-drop-0690-10000` compared `6759/10000` cases before the configured Binaryen/tool command-failure stop, with `6759` normalized matches, `0` mismatches, `0` Starshine validation failures, and `20` command failures. Agent classification: tool/Binaryen failures only (`17` `binaryen-rec-group-zero`, `1` `binaryen-bad-section-size`, `1` `binaryen-table-index-out-of-range`, and `1` `binaryen-invalid-tag-index`); no semantic mismatch family was observed.
