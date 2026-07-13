# Binaryen `dataflow-optimization` / `dfo` v130/current-main reconciliation

_Capture date:_ 2026-07-11  
_Status:_ immutable primary-source and local-admission bridge for `docs/wiki/binaryen/passes/dataflow-optimization/`

## Scope

This bounded refresh replaces the stale **`version_129` as current baseline** wording in the living `dfo` dossier. It reviews the latest public Binaryen release, `version_130`, and the same current-`main` owner, graph, registration, and combo-test routes. It does not claim a byte-for-byte or whole-repository diff.

## Primary sources reviewed

- Binaryen [`version_130` release](https://github.com/WebAssembly/binaryen/releases/tag/version_130) — marked **Latest** when reviewed; release commit `5d704ad`.
- [`version_130` `DataFlowOpts.cpp`](https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/src/passes/DataFlowOpts.cpp) and [current `main`](https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/DataFlowOpts.cpp).
- [`version_130` `graph.h`](https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/src/dataflow/graph.h) and [current `main`](https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/dataflow/graph.h).
- [`version_130` `node.h`](https://github.com/WebAssembly/binaryen/blob/version_130/src/dataflow/node.h), [`users.h`](https://github.com/WebAssembly/binaryen/blob/version_130/src/dataflow/users.h), [`utils.h`](https://github.com/WebAssembly/binaryen/blob/version_130/src/dataflow/utils.h), and [`flat.h`](https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/flat.h), with the corresponding [current-main tree](https://github.com/WebAssembly/binaryen/tree/main/src/dataflow).
- [`version_130` `pass.cpp`](https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/src/passes/pass.cpp) and [current `main`](https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp).
- [`version_130` combo lit test](https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/test/lit/passes/flatten_simplify-locals-nonesting_dfo_O3.wast) and [current-main counterpart](https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/flatten_simplify-locals-nonesting_dfo_O3.wast).

## Durable upstream findings

- `version_130` is the public release baseline for new Binaryen conclusions. Do not continue to call `version_129` the current release baseline merely because the earlier detailed dossier started there.
- The reviewed `version_130` owner still describes `dfo` as an optimization over **DataFlow SSA IR**, requires `flatten` beforehand, and expects full ordinary optimization afterward to clean flattening scaffolding.
- The `version_130` registration remains public spelling `dfo` with description `optimizes using the DataFlow SSA IR`.
- The reviewed graph layer remains a narrow DataFlow SSA side IR designed with Souper conversion in mind, not a replacement for Binaryen's general expression IR.
- The reviewed `version_130` and current-main combo test retains the concrete pipeline:

  ```text
  wasm-opt --flatten --simplify-locals-nonesting --dfo -O3
  ```

  Its checked shapes include a dedicated `only-dfo` case as well as normal cleanup after flatten-era traffic.
- No behavior-bearing drift was identified in this bounded owner/registration/graph/combo-test reread. The living dossier may therefore retain its flat-input, integer-local-side-graph, conservative-loop, and nested-`precompute` teaching model while relabeling the release baseline as `version_130`.

## Starshine-local admission findings

- [`src/passes/optimize.mbt`](../../../../src/passes/optimize.mbt) retains local compatibility spelling `dataflow-optimization` in `pass_registry_removed_names()`; it is not an active descriptor.
- The same file's current removed-name guard rejects an explicit request rather than silently no-oping.
- [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../scripts/lib/pass-fuzz-compare-task.ts) still has no `dataflow-optimization` / `dfo` entry in `SUPPORTED_PASS_FLAGS`.
- Current workspace searches found no `src/passes/dataflow_optimization.mbt`, `src/dataflow/`, or `src/ir/flat*` local substrate, and `agent-todo.md` has no dedicated active `dfo` slice.

## Maintenance result

Update the living landing, implementation/test map, Flat-IR guide, WAT shape catalog, and Starshine strategy/readiness pages to:

1. use `version_130` as the public release baseline;
2. retain earlier `version_129` captures as historical provenance only where useful;
3. correct the current removed-pass guard anchor; and
4. keep parity fuzzing explicitly planned-only until local registry, implementation, harness mapping, and flat-compatible generator/profile admission all exist.

## Caveat

This is a focused source reconciliation, not a promise that every unreviewed current-main line is identical to the tag. Reopen the dossier if a future source change alters flatness, graph precision, supported rewrite families, registration, or the combo pipeline.
