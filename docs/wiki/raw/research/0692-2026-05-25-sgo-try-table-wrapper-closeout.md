# SGO try_table wrapper closeout

Date: 2026-05-25

## Question

Can `[SGO]003C6` be closed without more optimizer broadening in this run?

## Decision

Yes. Close `[SGO]003C6` as accepted / evidence-gated for the currently evidenced no-catch `try_table` wrapper surface.

No optimizer behavior changed in this closeout. The slice already has behavior-bearing evidence from the 0603 through 0632 micro-slices and the later full SGO fuzz lanes summarized in the parity matrix and `agent-todo.md`.

## Covered surface

The implemented and tested no-catch `try_table` read-only-to-write surface includes:

- direct `try_table (result i32)` candidate reads feeding no-else same-global constant-set guards;
- adjacent `i32.eqz`, compare-with-const, and reverse compare-with-const guards;
- exact `if return; set` tails, including block-wrapped set tails;
- supported external pure-condition chains;
- select guards where the no-catch `try_table` value appears as the condition, first selected value, or second selected value;
- select results through adjacent `i32.eqz`, compare, reverse-compare, supported pure post-consumers, and exact `if return; set` tails;
- reference-specific no-catch `try_table (result funcref)` values through `ref.is_null`, compare/reverse-compare, select positions, pure post-consumers, and exact `if return; set` tails.

## Guardrails kept

Catch-bearing `try_table` wrappers stay conservative. The focused tests around the 0603-0632 series preserve caught-wrapper negatives for direct/block-wrapped, pure-chain, select, reverse-compare, `ref.is_null`, and exact `if return; set` families.

This closeout does not claim full Binaryen `FlowScanner` parity. It only closes the explicit no-catch wrapper child slice. Future try/exception broadening needs a fresh exact Binaryen-positive child slice with paired catch/delegate/control-transfer guardrails and direct SGO fuzz evidence.

## Validation

No Moon or fuzz commands were required for this docs/backlog-only closeout because no source, tests, registry, CLI behavior, or optimizer output changed.

Latest behavior-bearing evidence remains the prior SGO no-catch `try_table` micro-slices and subsequent direct SGO fuzz lanes, including the latest loop-prefix lane `.tmp/pass-fuzz-sgo-loop-segment-drop-0690-10000` with `6759/10000` compared before the configured `20` Binaryen/tool command-failure stop, `0` mismatches, and `0` Starshine validation failures.

## Follow-up

Continue `[SGO]003C` with `[SGO]003C7` branch/control guardrails or move to `[SGO]003D` call/generated-effects breadth if a fresh Binaryen-positive fixture justifies behavior work.
