---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-rse-current-main-recheck.md
  - ../../../raw/research/0463-2026-05-05-rse-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-26-rse-cfg-source-correction.md
  - ../../../raw/research/0382-2026-04-26-rse-cfg-source-correction-and-port-readiness.md
  - ../../../raw/binaryen/2026-04-22-rse-primary-sources.md
  - ../../../raw/binaryen/2026-04-25-rse-source-correction.md
  - ../../../../../src/passes/rse.mbt
  - ../../../../../src/passes/rse_test.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./cfg-and-value-tracking.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
---

# `rse` Implementation Structure And Tests

This page is the read-along map for the corrected Binaryen `version_129` `rse` contract.
It exists because the 2026-04-25 correction accurately narrowed the semantic scope but misidentified the implementation as a straight-line `PostWalker`.

## Upstream owner files

| Source | Role for `rse` |
| --- | --- |
| [`src/passes/RedundantSetElimination.cpp`](https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RedundantSetElimination.cpp) | Entire pass implementation: `CFGWalker` pass declaration, per-block `Info`, block start/end value arrays, value-flow fixed point, same-value set/tee rewriting, refined `local.get` retargeting, conditional `ReFinalize`, and final change reporting. |
| [`src/passes/pass.cpp`](https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp) | Public pass registration and late optimization-pipeline placement. |
| [`src/passes/passes.h`](https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h) | Factory declaration for the public pass. |
| [`src/ir/numbering.h`](https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/numbering.h) | Expression value-numbering and block merge value-number support used to compare RHS and local facts. |
| [`src/ir/properties.h`](https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h) | `Properties::getFallthrough(...)` support for finding the value that a `local.set` RHS contributes through fallthrough-producing wrappers. |
| [`src/cfg/cfg-traversal.h`](https://github.com/WebAssembly/binaryen/blob/version_129/src/cfg/cfg-traversal.h) | CFG walker and block traversal substrate used by the pass. |
| [`src/wasm/wasm-type.h`](https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm/wasm-type.h) | Type relation helpers used by the strict-subtype local-get retargeting gate. |

## What is not an owner file

These helper families are useful elsewhere in Binaryen, but they are not `version_129` `rse` owner dependencies:

- `src/ir/local-graph.h`
- `src/ir/liveness.h`
- generic dataflow optimizer files under `src/dataflow/`
- global, memory, table, struct, or array store optimizers

The corrected phrasing is not “no dataflow at all.”
It is “the dataflow is a small pass-local CFG/value-number flow, not `LocalGraph` / liveness dead-store elimination.”

## Core implementation map

Read `RedundantSetElimination.cpp` in this order:

1. **Pass declaration** - `RedundantSetElimination` is a `WalkerPass` over `CFGWalker<..., Visitor<LocalGet, LocalSet>, Info>`.
2. **`Value` / `LocalValues` state** - the pass stores per-local value facts, including block merge values.
3. **`Info`** - each block owns `start`, `end`, and collected `gets` / `sets`.
4. **`doWalkFunction`** - the top-level function path creates the CFG, flows values, optimizes, and returns whether anything changed.
5. **`flowValues`** - work-queue fixed point that computes block `start` values from predecessors and block `end` values after local writes.
6. **`getValueNumber` / fallthrough helpers** - derive the RHS value number for a set, using current local value facts for `local.get` RHSes and ordinary value numbering otherwise.
7. **`optimize`** - rescan collected gets/sets per block from the computed block-start facts.
8. **`replaceSet` / set handling** - remove same-value set/tee shells while preserving RHS evaluation.
9. **local-get retargeting helpers** - choose a same-value local with a strict subtype when safe.
10. **conditional `ReFinalize`** - repair types after type-sensitive replacements.

## Official test surfaces

| Test | What it proves |
| --- | --- |
| [`test/passes/rse_all-features.wast`](https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/rse_all-features.wast) | Primary hand-written pass test input for same-value local writes, copied locals, CFG value flow, tees, effects, and negative cases. |
| [`test/passes/rse_all-features.txt`](https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/rse_all-features.txt) | Expected output for the all-features pass test; useful for exact before/after audits. |
| [`test/lit/passes/rse-gc.wast`](https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/rse-gc.wast) | GC/reference-type precision checks for local-get retargeting to a refined local. |

## Current-main spot check

The 2026-05-05 raw recheck stayed aligned with the same owner and test files.
No teaching-relevant drift was found:

- the owner file remains `RedundantSetElimination.cpp`;
- the pass still uses a `CFGWalker`-based flow/optimize split;
- same-value local set/tee removal and refined local-get retargeting remain the visible transforms;
- no `LocalGraph` / liveness / broad overwritten-write eliminator appeared.

## Starshine read-across

The local follow-along points are now active:

- `src/passes/rse.mbt:2-8` owns the direct pass descriptor, `src/passes/rse.mbt:12-16` the summary, and `src/passes/rse.mbt:692-700` the raw lowered-function rewrite helper.
- `src/passes/optimize.mbt:253-256` registers `"redundant-set-elimination"` as an active hot pass.
- `src/passes/pass_manager.mbt:7324-7334` dispatches the pass and runs the raw fast path before hot lift.
- `src/passes/rse_test.mbt:41-71`, `src/passes/registry_test.mbt:189-193`, and `src/cmd/cmd_wbtest.mbt:3922-3959` cover focused pass behavior, registry classification, and CLI execution.
- `scripts/lib/pass-fuzz-compare-task.ts` maps the Starshine long name to Binaryen `--rse` for oracle comparison.

Future implementation work should stay in `src/passes/rse.mbt`, adding fixed-point CFG merge values and strict-subtype refined local-get retargeting without changing the pass into generic liveness dead-store elimination.
