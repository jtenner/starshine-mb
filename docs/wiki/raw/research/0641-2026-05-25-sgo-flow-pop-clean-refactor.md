---
kind: research-note
status: completed
created: 2026-05-25
sources:
  - ../../../../src/passes/simplify_globals_optimizing.mbt
  - ../../binaryen/passes/simplify-globals-optimizing/parity-matrix.md
  - ../../binaryen/passes/simplify-globals-optimizing/starshine-port-readiness-and-validation.md
  - ../../../../.tmp/pass-fuzz-sgo-flow-pop-clean-refactor-10k/result.json
---

# SGO FlowScanner clean-pop refactor (`[SGO]003O`)

## Scope

This is a refactor-only maintainability slice for the `simplify-globals-optimizing` read-only-to-write FlowScanner helpers. It does not broaden matcher behavior.

## Change

Added two small helper predicates in `src/passes/simplify_globals_optimizing.mbt`:

- `sgo_flow_pop_clean(...)`: pops one stack value and accepts it only when it is untainted;
- `sgo_flow_pop_clean_then_push_clean(...)`: pops one untainted value and pushes a clean replacement value.

The first two FlowScanner paths now use these helpers for repeated local/global set, `drop`, `local.tee`, trapping-read, and `if` condition checks that previously spelled out the same `match sgo_flow_pop(...)` shape inline.

## Behavior

No behavior changed. The refactor preserves:

- stack underflow failure behavior;
- tainted-value rejection;
- clean replacement push behavior for `local.tee` and clean trapping-read operands;
- existing FlowScanner boundaries around calls, control, caught `try_table`, trapping/effectful candidate consumers, and unsupported post-consumers.

## Validation

- `moon test src/passes`: `1596/1596` passed.
- `moon info`, `moon fmt`, `moon test`: completed; full test count was `3672/3672` passed, with only existing DAE unused warnings from `moon info`.
- Direct SGO fuzz: `.tmp/pass-fuzz-sgo-flow-pop-clean-refactor-10k` reported `9975/10000` compared, `9975` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, and `25` Binaryen/tool command failures.
- Command-failure classes: `22` `binaryen-rec-group-zero`, `1` `binaryen-bad-section-size`, `1` `binaryen-table-index-out-of-range`, and `1` `binaryen-invalid-tag-index`.

## Remaining risks

This does not resolve any remaining Binaryen `SimplifyGlobals.cpp` breadth gap. `[SGO]003` remains active/partial; future refactor-only work should still rerun direct SGO fuzz when matcher/dataflow code is touched.
