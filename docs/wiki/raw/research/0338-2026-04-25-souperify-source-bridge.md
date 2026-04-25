# `souperify` source bridge and Starshine status follow-up

_Date:_ 2026-04-25  
_Status:_ filed back into living wiki pages  
_Sources:_ `docs/wiki/raw/binaryen/2026-04-25-souperify-primary-sources.md`, `docs/wiki/binaryen/passes/souperify/`, `src/passes/optimize.mbt`, `src/passes/pass_manager.mbt`, `src/cmd/cmd.mbt`, `src/ir/use_def.mbt`, `src/ir/ssa_local.mbt`, `src/ir/ssa_policy.mbt`, `src/ir/hot_lift.mbt`, `src/lib/types.mbt`, `src/wast/`, `agent-todo.md`

## Question

The `souperify` folder already had useful 2026-04-21 overview, Binaryen strategy, implementation/test-map, mechanics, and shape coverage. It still had two wiki-health gaps:

1. no immutable raw Binaryen primary-source manifest; and
2. no dedicated Starshine status / future-port page mapping the upstream pass family to exact local code locations.

This follow-up closes those gaps while keeping `souperify` separate from the neighboring `flatten`, `simplify-locals-nonesting`, and `dataflow-optimization` dossiers.

## Source-backed Binaryen findings

- Binaryen `version_129` exposes two public pass names: `souperify` and `souperify-single-use`.
- Both names share the `src/passes/Souperify.cpp` owner and are trace-emission passes, not ordinary wasm-body optimizers.
- The first semantic gate is `Flat::verifyFlatness(func)`, so the pass consumes already-flat IR instead of flattening arbitrary ASTs itself.
- The official lit proof surface is a pair of combo files that run `--flatten --simplify-locals-nonesting --souperify...`; no standalone `souperify.wast` exists in the reviewed `version_129` tree.
- The pass builds Binaryen's DataFlow graph, then prints bounded Souper-style traces from `Var`, `Expr`, `Phi`, `Cond`, `Block`, `Zext`, and `Bad` nodes.
- `LocalGraph` provides the value-influence and use-discovery proof for copy chains, external uses, and single-use child exclusion.
- The default trace limits are depth `10` and total nodes `30`, with `BINARYEN_SOUPERIFY_DEPTH_LIMIT` and `BINARYEN_SOUPERIFY_TOTAL_LIMIT` overrides.
- When extraction crosses size, depth, unsupported-value, or single-use-child boundaries, Binaryen summarizes the dependency as a fresh `Var` instead of requiring an exact full slice.
- `souperify-single-use` is child truncation, not root filtering: reused nodes may still be printed as roots, but they are not expanded as children of larger traces.
- Path conditions are `if`-derived on the reviewed implementation, while broader path-condition support remains a source-level TODO.
- Loop-carried values are intentionally cut off rather than modeled as real loop phis.

## Starshine local status

- `src/passes/optimize.mbt` currently has no active, module, boundary-only, removed, or preset registry entry for `souperify` or `souperify-single-use`; explicit requests therefore hit the unknown-pass path in `run_hot_pipeline_expand_passes(...)`.
- `src/passes/pass_manager.mbt` dispatches the current active module passes only; there is no Souper trace-emission case and no non-mutating output-pass lane.
- `src/cmd/cmd.mbt` accepts pass names from CLI/config/env and reports unknown pass flags, but there is no Souper-output option or stdout trace-emission path matching Binaryen's behavior.
- No `src/passes/*souper*` owner file exists.
- `src/ir/use_def.mbt` provides local read/write and node-use surfaces, and `src/ir/ssa_local.mbt` / `src/ir/ssa_policy.mbt` provide HOT local-SSA and phi-placement machinery. Those are prerequisites, not a Binaryen DataFlow trace graph.
- `src/ir/hot_lift.mbt`, `src/lib/types.mbt`, `src/wast/`, binary codec, and validation packages already expose many unary/binary/select/local/control shapes a future extractor would need to parse, lift, print, or validate.
- Starshine does not currently have a Binaryen-style flatness verifier, DataFlow graph, `UseFinder`, bounded `Trace`, Souper printer, `pc` / `blockpc` emitter, or output contract for extraction-only passes.
- `agent-todo.md` has no dedicated `souperify` slice.

## Filed-back pages

- `docs/wiki/binaryen/passes/souperify/index.md`
- `docs/wiki/binaryen/passes/souperify/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/souperify/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/souperify/flat-dataflow-traces-and-single-use-boundaries.md`
- `docs/wiki/binaryen/passes/souperify/wat-shapes.md`
- `docs/wiki/binaryen/passes/souperify/starshine-strategy.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`

## Follow-ups

- If Starshine ever supports `souperify`, decide first whether extraction-only passes belong in the normal pass registry or in a separate analysis/export command surface.
- A faithful local port should not advertise parity until it has a Binaryen-like flatness precondition, DataFlow trace graph, use-discovery semantics, bounded `Var` fallback, path-condition printer, and `souperify-single-use` child-truncation behavior.
- Re-check upstream before expanding the dossier's path-condition or Souper RHS claims; the reviewed sources explicitly leave wider path-condition and RHS integration work as TODOs.
