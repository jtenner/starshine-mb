# SGO clean leaf replacement helper rename

## Scope

Refactor-only `[SGO]003O3` value-stack matcher naming slice for `simplify-globals-optimizing`.

This slice clarifies the FlowScanner helper used by instructions that consume one clean stack value and produce a new clean leaf replacement value. The old name, `sgo_flow_pop_clean_then_push_clean(...)`, described the mechanics but not the semantic reason the helper exists in the scanner.

## Change

- Renamed `sgo_flow_pop_clean_then_push_clean(...)` to `sgo_flow_pop_clean_then_push_clean_leaf(...)`.
- Updated all call sites in the prefix, clean-prefix, arm-result, block-wrapped nested-if, and nested-if arm-flow scanners.

The new name keeps the stack contract explicit: pop exactly one untainted value, reject stack underflow or tainted operands, and push an untainted leaf result.

## Behavior

No optimizer behavior changed.

Preserved boundaries:

- stack-underflow failure behavior is unchanged;
- tainted candidate-derived operands are still rejected;
- the pushed replacement value is still clean and non-i31-ref;
- read budgets, call-result handling, clean pair/triple effects, and value-producing arm merges are unchanged.

## Validation

- `moon test src/passes` — `1600/1600` passed.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-clean-leaf-replacement-rename-10k` — `9975/10000` compared, `9975` normalized matches, `0` mismatches, `0` validation failures, `25` Binaryen/tool command failures.

## Status

`[SGO]003O3` is complete. `[SGO]003O` remains open for `[SGO]003O4`. `[SGO]003` remains active/partial; this is not a full Binaryen `SimplifyGlobals.cpp` parity claim.
