# SGO loop independent global-set prefix

Date: 2026-05-25

## Slice

`[SGO]003C5` / loop-specific read-only-to-write FlowScanner breadth.

## Goal

Land the narrow Binaryen-positive value-loop prefix found in [`0638`](./0638-2026-05-25-sgo-loop-self-guard-boundary-study.md) without reopening the broad loop FlowScanner that had regressed existing coverage.

## Source evidence

The prior probe in `0638` showed Binaryen removes fake traffic for this shape while preserving the independent wrong-global effect:

```wat
loop (result i32)
  i32.const 7
  global.set $h
  global.get $g
end
if
  i32.const 1
  global.set $g
end
```

It also showed Binaryen keeps branchy loop/backedge shapes and trapping candidate consumers conservative. Those guardrails remain covered by existing tests.

## Implementation

Added `sgo_loop_condition_independent_global_set_prefix_read_matches(...)` in `src/passes/simplify_globals_optimizing.mbt`.

The matcher is intentionally narrower than the ordinary block FlowScanner:

- it only runs for a direct loop-result condition immediately consumed by the no-else same-global constant-set guard;
- it requires the loop body, after the existing transparent condition-body flattening, to end in exactly one `global.get` of the candidate;
- it allows only `nop` and one or more `const; global.set <different global>` prefix pairs before that read;
- it does not apply to adjacent `i32.eqz`, compare, reverse-compare, nested-if arm-flow, `try_table`, branchy, trapping, call, memory/table-growth, or candidate-derived operand shapes.

This preserves the conservative boundaries from `0638` while covering the exact independent-effect prefix.

## Tests

Updated `src/passes/simplify_globals_optimizing_test.mbt` so the former conservative fixture now expects `$once` to become immutable and its fake `global.get` / `global.set` traffic to disappear, while an exported `$other` write remains observable in the optimized function body.

Existing neighboring guardrails still cover:

- direct loop self-guard positives;
- branchy `br_if` loop negatives;
- trapping candidate-consumer loop negatives;
- loop-wrapped `i32.eqz`, compare, reverse-compare, and simple pure-condition positives/negatives.

## Validation

- TDD failure before implementation: `moon test src/passes` failed at `simplify-globals-optimizing removes loop-wrapped independent global-set effect prefixes`, with `$once` still mutable.
- Focused pass tests after implementation: `moon test src/passes` passed (`1612/1612`) with the existing DAE/pass-manager warnings.
- Standard Moon validation: `moon fmt`, `moon info`, and full `moon test` passed (`3688/3688`), with the existing DAE warnings during `moon info` and existing DAE/pass-manager warnings during tests.
- Direct SGO fuzz: `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --out-dir .tmp/pass-fuzz-sgo-loop-prefix-0677-10000` compared `6759/10000` before the configured `20` Binaryen/tool command-failure stop, with `6759` normalized matches, `0` mismatches, `0` Starshine validation failures, and `0` generator failures.

## Classification

This is a semantic-safe Binaryen-positive behavior implementation. The accepted family is limited by an explicit transform contract and the prior Binaryen probe. No fuzz mismatch is attributed to this slice at the time of writing.
