---
kind: research-note
status: completed
created: 2026-05-25
sources:
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/simplify_globals_optimizing_test.mbt
  - ../../binaryen/passes/simplify-globals-optimizing/parity-matrix.md
  - ../../binaryen/passes/simplify-globals-optimizing/starshine-port-readiness-and-validation.md
---

# SGO nested cleanup wrapper frontier (`[SGO]003N`)

## Scope

This slice documents the current nested-cleanup structural guard for `simplify-globals-optimizing`. It is research/source-alignment only: no matcher or scheduler behavior changed.

## Current guard

`run_hot_pipeline_sgo_nested_cleanup_filter_touched(...)` filters touched functions before the nested default cleanup lane. The active filters are:

- large touched function: more than `192` locals or more than `1000` scanned instructions;
- structural frontier: `run_hot_pipeline_sgo_instrs_have_value_block_with_if(...)`, i.e. a value-producing `block` or `if` containing nested `if` control.

When every touched function is filtered, SGO traces `nested-cleanup-skip` with either `reason=large-touched-function` or `reason=value-block-control` and returns the valid SGO core rewrite without forcing nested cleanup.

## Local evidence

Existing focused coverage already pins this frontier:

- `simplify-globals-optimizing removes recursive nested read-only-to-write pattern thrice` proves the SGO core can remove the recursive no-else same-global traffic, but the resulting value-block/control shape is structurally filtered (`filtered-structural=1`, `reason=value-block-control`).
- Large-function tests around the same cleanup filter prove the size filters are per-touched-function, not whole-module or touched-count gates.
- The pass manager code keeps the structural filter separate from the large-function filter, so mixed touched sets can still clean safe touched functions while preserving structurally filtered ones.

## Decision

Do not lift the structural wrapper guard inside `[SGO]003`. The guard is scheduler/HOT-cleanup safety, not a missing read-only-to-write matcher. Future behavior should move to a dedicated `[SGO]004` nested cleanup/runtime scheduler slice with a minimal verifier reproduction and a fix in the correct layer: SGO scheduling, HOT lift/lower, or one nested cleanup pass.

## Non-goals kept out of scope

This slice does not broaden:

- recursive nested-pattern matching beyond the current no-else same-global source-backed carveout;
- branch/control-transfer or `else` nested patterns;
- caught `try_table`, calls, trapping/effectful candidate consumers, runtime join facts, or post-cleanup pass ordering;
- the large-function filters.

## Validation

- `moon test src/passes` passed after documentation updates.
- Full quick gate passed with `moon info`, `moon fmt`, and `moon test`.
- Direct SGO fuzz was not required because no optimizer behavior or matcher/dataflow code changed.
