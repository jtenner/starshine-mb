# Binaryen `dataflow-optimization` / `dfo` current-main recheck

_Capture date:_ 2026-05-05  
_Status:_ immutable current-main source bridge for `docs/wiki/binaryen/passes/dataflow-optimization/`

## Scope

This file captures the official online sources rechecked after the 2026-04-27 `dfo` port-readiness capture. The goal was not to rewrite the dossier from scratch, but to verify whether Binaryen current `main` had drifted in a way that changes the teaching contract for Starshine developers.

Use this file together with:

- `docs/wiki/binaryen/passes/dataflow-optimization/index.md`
- `docs/wiki/binaryen/passes/dataflow-optimization/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/dataflow-optimization/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/dataflow-optimization/flat-ir-dataflow-ir-and-boundaries.md`
- `docs/wiki/binaryen/passes/dataflow-optimization/wat-shapes.md`
- `docs/wiki/binaryen/passes/dataflow-optimization/starshine-strategy.md`

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

### Flat IR and pass registration

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

## Durable observations from the captured sources

- The reviewed official release surface still anchors cleanly on Binaryen `version_129` for this pass, with the current `main` code and lit surface keeping the same teaching contract.
- `DataFlowOpts.cpp` still presents the pass as `Optimize using the DataFlow SSA IR`, still says `flatten` must run before it, still suggests `--flatten --dfo -Os`, and still implements a function-parallel pass.
- The current implementation still begins function work with `Flat::verifyFlatness(func)`, builds `graph`, builds `nodeUsers`, seeds `workLeft` with graph nodes, and updates underlying flattened wasm `local.set` values only when graph nodes were optimized.
- The rewrite surface remains the same small pair as the earlier dossier: identical-input phi collapse when the replacement is constant, and all-constant `Expr` folding through nested `precompute`.
- `graph.h` still defines DataFlow IR as an SSA representation designed to be convertible to Souper IR, still uses the integer-only `isRelevantType(type) { return type.isInteger(); }` filter, still models EH as unsupported, and still deliberately avoids ordinary loop phis by installing unknown loop-entry `Var`s when real loop variation is observed.
- `pass.cpp` still registers the public upstream pass spelling `dfo` with the description `optimizes using the DataFlow SSA IR`.
- The reviewed combo lit file remains the canonical visible usage surface for the pass family: `flatten` + `simplify-locals-nonesting` + `dfo` + normal optimization cleanup.

## Starshine-local observations rechecked

- `src/passes/optimize.mbt:143-146` still keeps the local compatibility spelling `dataflow-optimization` in the removed-pass registry.
- `src/passes/optimize.mbt:522-524` still rejects explicit requests for removed passes with the removed-registry error path.
- `src/passes/optimize.mbt:155-279` still contains no active `dataflow-optimization` descriptor entry.
- Workspace file search still found no `src/passes/dataflow_optimization.mbt`, no `src/dataflow/`, and no `src/ir/flat*` substrate. That absence remains a local-port planning fact, not an upstream Binaryen claim.
- `agent-todo.md` still has no dedicated `dataflow-optimization` / `dfo` slice.

## Result

No teaching-relevant current-main drift was found. The living pages should keep teaching `dfo` as a flat-input, integer-local, DataFlow-side-graph constant simplifier with nested `precompute` validation, not as a generic optimizer or hidden Starshine implementation.

The local hygiene issue found during this recheck was stale line anchors in the Starshine status page for the removed-pass request guard; the living page should now point at `src/passes/optimize.mbt:522-524`.
