---
kind: concept
status: supported
last_reviewed: 2026-07-19
sources:
  - ./index.md
  - ../inlining/starshine-strategy.md
  - ../../../../../src/passes/inlining.mbt
  - ../../../../../src/passes/inlining_test.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./planning-partial-inlining-and-reruns.md
  - ./starshine-port-readiness-and-validation.md
  - ../dae-optimizing/index.md
---

# Starshine Strategy For `inlining-optimizing`

## Current status

`inlining-optimizing` is an active, supported module pass. Its direct engine is the same v131-aligned engine documented for plain [`inlining`](../inlining/starshine-strategy.md). Optimizing mode adds touched-function cleanup in Binaryen's v131 order.

## Local execution path

1. Build summaries and choose direct inlining actions.
2. Rewrite all selected callsites in each caller.
3. Repair locals, multivalue blocks, returns, branch depths, nested tail calls, and EH hoists.
4. Remove now-dead private helpers and remap sections/metadata.
5. Convert absolute touched-function bits to defined-function bits.
6. Run touched-only `precompute-propagate`.
7. Run `inlining_nested_function_pipeline_passes(...)` on touched functions.
8. Validate or fall back if a nested candidate is invalid.

## Nested-pipeline invariants

- exact v131 ordering is tested;
- option-gated passes follow optimize/shrink levels;
- untouched functions are not mutated;
- imports do not shift touched defined-function indices;
- large modules are not skipped wholesale;
- surviving tail calls are not a blanket bypass;
- plain `inlining` never runs the suffix;
- trace output identifies each nested slot.

The shared scheduler abstraction for DAE/inlining/SGO is still tracked under `[O4Z-NESTED]001`. Consolidating that API must preserve this pass's current tested order and behavior.

## Direct behavior inherited from `inlining`

- all six Binaryen tuning controls and aliases;
- v131 `@binaryen.inline` policy;
- no/full/partial inline markers;
- complete represented trivial-instruction policy;
- direct-call-only recursion hazard tracking;
- Pattern A/B partial splitting;
- EH-aware direct/indirect/ref tail-call repair;
- table64 indirect target spills;
- branch/catch depth repair;
- root survival, helper deletion, and metadata remapping.

## Performance

The durable pass-local fixture is the inline-heavy helper-chain matrix described in [`fuzzing.md`](./fuzzing.md). The accepted post-repair ratios meet the repository's `<= 1x Binaryen` target across 1, 5, 10, 20, 50, and 100 helper cases. Reopen on repeated regression above that target or a new nested-pass scaling cliff.

## Evidence

- focused behavior: `120/120`;
- white-box: `14/14`;
- full repository: `9452/9452`;
- official-v131 aggregate: `.tmp/pass-fuzz-inlining-optimizing-v131-closeout-10000`, `10000/10000` normalized matches and zero failures.

## Non-pass boundaries

Expression-level branch hints, source maps, copied callee debug-name synthesis, and legacy `try_delegate` remain shared representation/metadata work. They do not reduce the represented v131 wasm behavior contract.

## Reopening criteria

Reopen for a minimized semantic/validation mismatch, a source-backed missing v131 family, a measured size regression without a Starshine benefit, a pass-local timing regression, or a shared scheduler change that alters the tested touched-only roster.
