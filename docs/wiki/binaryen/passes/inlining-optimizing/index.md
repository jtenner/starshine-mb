---
kind: entity
status: supported
last_reviewed: 2026-07-19
sources:
  - ../../release-horizon-and-oracles.md
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_131/src/passes/Inlining.cpp
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_131/src/passes/opt-utils.h
  - ../inlining/index.md
  - ../../../../../src/passes/inlining.mbt
  - ../../../../../src/passes/inlining_test.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../agent-todo.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./planning-partial-inlining-and-reruns.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ./deferred-inl005-inl006-work.md
  - ../inlining/index.md
  - ../dae-optimizing/index.md
  - ../precompute-propagate/index.md
---

# `inlining-optimizing`

## Status

`inlining-optimizing` is supported for Binaryen v131 behavior on the represented surface. The shared direct engine is closed with plain [`inlining`](../inlining/index.md), including toolchain policy, complete profitability classes, Pattern A/B splitting, multivalue/local repair, and EH-aware direct/indirect/ref tail handling.

The optimizing suffix now uses the v131 order:

1. inline chosen actions;
2. run touched-only `precompute-propagate`;
3. run the represented v131 default function optimization pipeline on touched functions only.

There is no open inlining-specific v131 transform gap. `[O4Z-NESTED]001` remains active only to route DAE, inlining, and SGO through one shared scheduler expansion API; it does not reopen this pass's current direct behavior or tested nested order.

## Role

This is the late optimizing sibling used by the O4z path. It is not merely “more aggressive inlining”: it uses the same profitability decisions as plain `inlining`, then immediately exposes and cleans constants, locals, dead control, and other debris created by body copying.

## Direct engine

See [`../inlining/index.md`](../inlining/index.md) for the full family matrix. In summary, the shared engine covers:

- v131 toolchain and no-inline policy channels;
- all public tuning controls;
- tiny, one-caller, shrinking-trivial, may-grow-trivial, flexible, loop, and combined-size policy;
- Pattern A/B splitting;
- direct `call` / `return_call` planning;
- local/type/control/metadata repair;
- EH-aware direct/indirect/ref tail-call localization and hoisting;
- root survival and private-helper deletion.

## Nested cleanup contract

The nested roster is represented by `inlining_nested_function_pipeline_passes(...)` and tested in exact order. Important invariants:

- `precompute-propagate` is prepended once;
- only touched callers are cleaned;
- untouched functions retain their bodies and valid debug maps;
- plain `inlining` never enters this path;
- large modules and modules with surviving tail calls no longer bypass the suffix wholesale;
- option-gated slots follow optimize/shrink policy;
- validation-or-fallback guards reject an invalid nested candidate rather than corrupting the module.

The local implementation still contains Starshine-specific cleanup and unreachable-cycle accounting used to match the oracle and preserve smaller validated outputs. Those are implementation details, not a reduced public contract.

## Evidence

Current tests:

- focused inlining behavior: `120/120`;
- inlining white-box: `14/14`;
- command: `107/107`;
- full repository: `9452/9452`.

Official v131 aggregate closeout:

```text
.tmp/pass-fuzz-inlining-optimizing-v131-closeout-10000
profile: inlining-optimizing-all
10000/10000 compared
10000 normalized matches
0 mismatches
0 validation failures
0 property failures
0 generator failures
0 command failures
```

The plain sibling independently reached `10000/10000` in `.tmp/pass-fuzz-inlining-v131-closeout-10000`.

The accepted pass-local performance fixture remains the inline-heavy helper-chain matrix documented in [`fuzzing.md`](./fuzzing.md); reopen on a repeated median regression above Binaryen or a new nested-cleanup scaling cliff.

## Boundaries that do not reopen this pass

- legacy `try_delegate` representation;
- expression-level branch hints and code metadata;
- source-map offset repair;
- copied callee debug-name synthesis;
- speculative indirect/ref callee recovery;
- shared scheduler API consolidation under `[O4Z-NESTED]001`;
- raw output-shape differences without semantic, validation, size, or performance loss.

## Page map

- [`binaryen-strategy.md`](./binaryen-strategy.md): upstream shared engine and suffix.
- [`implementation-structure-and-tests.md`](./implementation-structure-and-tests.md): code and test map.
- [`planning-partial-inlining-and-reruns.md`](./planning-partial-inlining-and-reruns.md): planner, roots, splitting, and reruns.
- [`wat-shapes.md`](./wat-shapes.md): representative shapes.
- [`starshine-strategy.md`](./starshine-strategy.md): local implementation summary.
- [`starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md): signoff and reopening criteria.
- [`deferred-inl005-inl006-work.md`](./deferred-inl005-inl006-work.md): completed former deferrals and shared metadata boundaries.
