---
kind: concept
status: supported
last_reviewed: 2026-07-19
sources:
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_131/src/passes/Inlining.cpp
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_131/src/passes/opt-utils.h
  - ../../../../../src/passes/inlining.mbt
  - ../../../../../src/passes/inlining_test.mbt
  - ../../../../../src/passes/inlining_wbtest.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
related:
  - ./index.md
  - ./starshine-strategy.md
  - ../inlining/implementation-structure-and-tests.md
---

# `inlining-optimizing`: implementation structure and tests

## Shared engine

All direct planning, splitting, rewrite, EH repair, root survival, removal, and metadata behavior lives in `src/passes/inlining.mbt` and is shared with plain `inlining`. See [`../inlining/implementation-structure-and-tests.md`](../inlining/implementation-structure-and-tests.md) for that map.

## Optimizing-only clusters

- `inlining_nested_function_pipeline_passes(...)`: exact represented v131 default function roster.
- `inl_trace_nested_cleanup(...)`: nested trace boundary.
- `inl_run_nested_cleanup(...)`: touched-set conversion, propagating prefix, filtered pass execution, validation/fallback, and touched local compaction.
- `pass_manager.mbt`: forwards optimize/shrink levels and all inlining policy options.

## Test ownership

`src/passes/inlining_test.mbt` proves:

- exact nested order;
- `precompute-propagate` prefix;
- touched-only cleanup;
- imported-function touched-index correctness;
- no broad large-module bypass;
- no broad surviving-tail-call bypass;
- plain mode does not run nested cleanup;
- trace slot emission;
- nested cleanup behavior after body copying.

Direct transform tests are shared with plain inlining and include toolchain policy, trivial classes, splitting, tail/EH repair, roots, metadata, and helper deletion.

`src/passes/inlining_wbtest.mbt` proves internal arithmetic, graph, unary, table64, and branch-depth invariants used by both siblings.

## Current validation

- focused behavior: `120/120`;
- white-box: `14/14`;
- full repository: `9452/9452`;
- official v131 aggregate: `10000/10000` normalized matches, no failures.

## Infrastructure boundary

`[O4Z-NESTED]001` may consolidate the expansion API with DAE and SGO. Any refactor must preserve the exact roster, option gates, touched filtering, validation fallback, trace, and pass-local timing.
