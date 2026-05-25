# SGO FlowScanner predicate grouping audit

## Scope

Research-only `[SGO]003O1` refactor slice for `simplify-globals-optimizing`.

The goal was to inspect the remaining FlowScanner opcode predicate clusters after the 0648 clean-leaf helper and 0649 clean pair/triple effect helper slices, and either extract exactly one obviously duplicated pure/effect predicate group or document that no remaining extraction is worth landing right now.

## Audit

The current FlowScanner predicate surface is already centralized around these single-source helpers in `src/passes/simplify_globals_optimizing.mbt`:

- `sgo_is_flow_clean_pair_effect_instr(...)` for `table.set` and scalar stores that consume two clean stack values.
- `sgo_is_flow_clean_triple_effect_instr(...)` for memory/table bulk operations that consume three clean stack values.
- `sgo_is_flowscanner_nullary_pure_instr(...)` for value-only `memory.size` / `table.size` leaves.
- `sgo_is_flowscanner_unary_pure_instr(...)` for unary pure value transforms.
- `sgo_is_flowscanner_binary_pure_instr(...)` for binary pure value transforms.
- `sgo_is_flowscanner_trapping_read_instr(...)` for scalar loads and `table.get` that may trap/read and therefore require clean operands before pushing clean replacement values.

Call sites reuse these helpers across the primary prefix scanner, clean-prefix scanner, arm-result scanner, block-wrapped nested-if scanner, and nested-if arm-flow scanner. The remaining long unary/binary pure opcode lists are broad single-source classifiers, not duplicated predicate clusters. Splitting them further by scalar/SIMD/ref families would be cosmetic and risks blurring the current stack-arity contract unless paired with a larger naming cleanup.

## Decision

No code extraction in this slice.

`[SGO]003O1` is closed as a research-only audit. The remaining readability work should stay in the already-visible naming slices:

- `[SGO]003O2` for condition matcher naming.
- `[SGO]003O3` for value-stack matcher naming.
- `[SGO]003O4` for closeout/keep-open bookkeeping after those slices are resolved.

## Behavior

No optimizer behavior changed.

Preserved boundaries:

- no accepted opcode family was widened;
- no stack arity or stack-underflow rule changed;
- candidate-read accounting and taint propagation remain scanner-specific where required;
- call, control-flow, trapping-read, and effectful boundaries are unchanged.

## Validation

This slice is docs/backlog-only, but the parent `[SGO]003O` shared exit criteria still asks for focused pass tests:

- `moon test src/passes` — `1600/1600` passed.

Direct SGO fuzz is not required because no matcher code changed.

## Status

`[SGO]003O1` is complete. `[SGO]003O` remains open for `[SGO]003O2`, `[SGO]003O3`, and `[SGO]003O4`. `[SGO]003` remains active/partial; this is not a full Binaryen `SimplifyGlobals.cpp` parity claim.
