---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-rse-source-correction.md
  - ../../../raw/research/0348-2026-04-25-rse-source-correction-and-starshine-followup.md
  - ../../../raw/binaryen/2026-04-22-rse-primary-sources.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./cfg-and-value-tracking.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
---

# `rse` Implementation Structure And Tests

This page is the read-along map for the corrected Binaryen `version_129` `rse` contract.
It exists because the older dossier over-attributed helper ownership to `LocalGraph` and liveness.

## Upstream owner files

| Source | Role for `rse` |
| --- | --- |
| [`src/passes/RedundantSetElimination.cpp`](https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RedundantSetElimination.cpp) | Entire pass implementation: `PostWalker`, per-local value-number state, local-get refinement, same-value set/tee removal, invalidation, refinalization, and nested `vacuum`. |
| [`src/passes/pass.cpp`](https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp) | Public pass registration and scheduling in the optimization pipeline. |
| [`src/passes/passes.h`](https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h) | Factory declaration for the public pass. |
| [`src/passes/opt-utils.h`](https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h) | Neighboring helper surface for nested cleanup scheduling around the late tail; not the core `rse` algorithm. |
| [`src/ir/numbering.h`](https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/numbering.h) | Value identity engine used to decide whether the current RHS equals the remembered local value. |
| [`src/ir/properties.h`](https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h) | Effect/local-state classification that informs conservative clearing. |
| [`src/wasm/wasm-type.h`](https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm/wasm-type.h) | Type relation helpers used by the `local.get` refinement gate. |

## What is not an owner file

These helper families are useful elsewhere in Binaryen, but they are not `version_129` `rse` owner dependencies:

- `src/ir/local-graph.h`
- `src/ir/liveness.h`
- CFG predecessor-merge utilities
- dataflow fixed-point helpers

If a future Starshine implementation starts from those concepts, that would be a deliberate local expansion or a different Binaryen-version port, not a faithful reading of the reviewed `version_129` pass.

## Core implementation shape

The pass body is small enough to summarize as a direct source map:

1. Construct a value-numbering context for the function.
2. Allocate a local-value array sized to the function's locals.
3. Postwalk children before parents.
4. On `local.get`, if a known value exists and its type is assignable to the get type, refine the value-numbering fact for the get.
5. On `local.set` / `local.tee`, value-number the RHS and compare it with the remembered value for that local.
6. If equal, replace the set/tee shell while preserving the RHS evaluation.
7. If different, record the RHS value number as the current local value.
8. Clear one local or all locals when the walker reaches unsafe expression forms.
9. Refinalize the function.
10. Run `vacuum` after the pass so leftover drops can disappear.

## Official test surfaces

| Test | What it proves |
| --- | --- |
| [`test/passes/rse_all-features.wast`](https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/rse_all-features.wast) | Primary hand-written pass test input for same-value local writes, tees, effects, barriers, and feature interactions. |
| [`test/passes/rse_all-features.txt`](https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/rse_all-features.txt) | Expected output for the all-features pass test; useful for exact before/after audits. |
| [`test/lit/passes/rse-gc.wast`](https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/rse-gc.wast) | GC/ref-type precision checks for the `local.get` refinement path. |

## Current-main spot check

The 2026-04-25 raw correction also checked current `main` URLs for the same owner and test files.
No teaching-relevant drift was found:

- the owner file remains `RedundantSetElimination.cpp`;
- the pass remains a value-numbered local-get/local-set walker;
- no `LocalGraph` / liveness / predecessor fixed-point engine appeared;
- the official `rse` test surfaces remain the same families to read first.

## Starshine read-across

The local follow-along points are exact but currently negative:

- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) keeps `"redundant-set-elimination"` in `pass_registry_removed_names()`.
- [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt) has no `"rse"` or `"redundant-set-elimination"` dispatcher arm in the hot-pass match.
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md) tracks backlog slice `RSE`, now corrected to same-value local set/tee elimination rather than broad write elimination.

A faithful future implementation should probably live in a new `src/passes/redundant_set_elimination.mbt` or similarly named owner file, with focused tests next to it and dispatcher/registry wiring in the files above.
