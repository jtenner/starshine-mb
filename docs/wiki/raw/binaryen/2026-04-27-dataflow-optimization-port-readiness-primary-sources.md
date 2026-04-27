# Binaryen `dataflow-optimization` / `dfo` port-readiness primary-source recheck

_Capture date:_ 2026-04-27  
_Status:_ immutable current-main source bridge for `docs/wiki/binaryen/passes/dataflow-optimization/starshine-port-readiness-and-validation.md`

## Scope

This source manifest rechecks the official Binaryen `main` surfaces needed to turn the existing `dataflow-optimization` dossier into a concrete Starshine port-readiness and validation guide.
It does not supersede the earlier `version_129` dossier or the 2026-04-25 no-drift recheck; it records that those conclusions are still the right basis for implementation planning.

Use this file together with:

- `docs/wiki/binaryen/passes/dataflow-optimization/index.md`
- `docs/wiki/binaryen/passes/dataflow-optimization/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/dataflow-optimization/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/dataflow-optimization/flat-ir-dataflow-ir-and-boundaries.md`
- `docs/wiki/binaryen/passes/dataflow-optimization/wat-shapes.md`
- `docs/wiki/binaryen/passes/dataflow-optimization/starshine-strategy.md`
- `docs/wiki/binaryen/passes/dataflow-optimization/starshine-port-readiness-and-validation.md`

## Official sources rechecked

### Core implementation

- `src/passes/DataFlowOpts.cpp`
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/DataFlowOpts.cpp>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/DataFlowOpts.cpp>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DataFlowOpts.cpp>

### DataFlow graph helpers

- `src/dataflow/graph.h`
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/dataflow/graph.h>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/dataflow/graph.h>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/dataflow/graph.h>
- `src/dataflow/node.h`
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/dataflow/node.h>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/dataflow/node.h>
- `src/dataflow/users.h`
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/dataflow/users.h>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/dataflow/users.h>
- `src/dataflow/utils.h`
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/dataflow/utils.h>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/dataflow/utils.h>

### Flat IR and registration

- `src/ir/flat.h`
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/flat.h>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/flat.h>
- `src/passes/pass.cpp`
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>

### Shipped proof surface

- `test/lit/passes/flatten_simplify-locals-nonesting_dfo_O3.wast`
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/flatten_simplify-locals-nonesting_dfo_O3.wast>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_simplify-locals-nonesting_dfo_O3.wast>

## Durable observations

- Current `DataFlowOpts.cpp` still frames the pass as a DataFlow SSA IR optimizer that needs `flatten` before it and normal cleanup afterward. It is still a function-parallel walker.
- Current `DataFlowOpts.cpp` still performs the same implementation sequence: `Flat::verifyFlatness(func)`, `graph.build(func, getModule())`, `nodeUsers.build(graph)`, seed every graph node into a worklist, then write back only optimized graph nodes.
- The current rewrite surface remains narrow: skip constant and unused graph nodes, collapse identical-input phis only when the selected replacement is a constant node, and fold all-constant expression nodes only after nested `precompute` turns the expression into an actual `Const`.
- Current `graph.h` still keeps the integer relevance filter, initializes relevant params as unknown `Var`s and relevant non-params as zero nodes, models real loop-carried values conservatively by leaving loop-entry `Var`s, and has an explicit unsupported-EH fatal boundary.
- Current `pass.cpp` still registers upstream public CLI spelling `dfo`, not the local descriptive Starshine spelling `dataflow-optimization`.
- The combo lit file remains the visible shipped proof that `dfo` belongs in a flatten-era pipeline (`flatten` / `simplify-locals-nonesting` / `dfo` / later optimization) rather than as a generic tree-IR optimizer.

## Starshine-local observations rechecked

- `src/passes/optimize.mbt:143-153` still keeps `dataflow-optimization` in `pass_registry_removed_names()`.
- `src/passes/optimize.mbt:155-279` still has no active `dataflow-optimization` registry entry.
- `src/passes/optimize.mbt:485-491` still rejects explicit requests for removed passes with the removed-registry error path.
- Workspace file search still found no `src/passes/dataflow_optimization.mbt`, no `src/dataflow/`, and no `src/ir/flat*` substrate.
- `agent-todo.md` still has no dedicated `dataflow-optimization` / `dfo` slice.

## Result

No teaching-relevant current-main drift was found. The useful new wiki work is not a strategy correction; it is a port-readiness bridge that turns the already-correct dossier into a concrete analyzer-first validation ladder for a future Starshine implementation.

## Uncertainties and open choices

- The upstream strategy is clear, but Starshine has not chosen whether a faithful local port should build a flat/DataFlow substrate or implement a narrower HOT/IR2-native approximation.
- Because the official proof surface is a combo lit file rather than a standalone `dfo.wast`, a future Starshine test plan should include reduced local fixtures and Binaryen-oracle combo lanes instead of relying on one isolated upstream fixture name.
- The local public spelling remains `dataflow-optimization`; whether to add upstream alias `dfo` locally is a registry policy decision, not a source ambiguity.
