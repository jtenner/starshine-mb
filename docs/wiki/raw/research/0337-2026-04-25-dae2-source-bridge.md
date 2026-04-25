# `dae2` source bridge and Starshine status follow-up

_Date:_ 2026-04-25  
_Status:_ filed back into living wiki pages  
_Sources:_ `docs/wiki/raw/binaryen/2026-04-25-dae2-primary-sources.md`, `docs/wiki/binaryen/passes/dae2/`, `src/passes/optimize.mbt`, `src/passes/pass_manager.mbt`, `src/cmd/cmd.mbt`, `src/lib/types.mbt`, `src/validate/typecheck.mbt`, `src/validate/validate.mbt`, `src/wast/`

## Question

The `dae2` folder already had useful 2026-04-21 strategy, implementation-map, mechanics, and WAT-shape coverage, but it still had two wiki-health gaps:

1. no immutable raw Binaryen primary-source manifest; and
2. no dedicated Starshine status / future-port page mapping the upstream pass to exact local code locations.

This follow-up closes those gaps without collapsing `dae2` into the neighboring plain `dead-argument-elimination` or `dae-optimizing` dossiers.

## Source-backed Binaryen findings

- Binaryen `version_129` exposes `dae2` as a public pass in `pass.cpp` next to `dae` and `dae-optimizing`.
- The upstream owner is `src/passes/DeadArgumentElimination2.cpp`, not the older `DeadArgumentElimination.cpp` engine.
- The pass is still explicitly experimental and still does not do result optimization, forward constant propagation, or forward type propagation.
- The real algorithm is a smallest fixed-point backward analysis over used parameters and parameters that are only forwarded through:
  - direct calls,
  - `call_ref`, and
  - `call_indirect` grouped by root function-type tree.
- The source-backed correctness boundaries are `LazyLocalGraph` incoming-value reasoning, branch-condition use, effectful-parent blockers, public/root type blockers, continuations/tags, `call.without.effects`, JS-called functions, and replacement types for unreferenced siblings before global referenced-type rewrite.
- `dae2.wast` is the canonical official lit surface for this pass, not evidence for plain DAE.

## Starshine local status

- `src/passes/optimize.mbt` currently has no active, boundary-only, or removed registry entry for `dae2`; explicit requests therefore hit the unknown-pass path in `run_hot_pipeline_expand_passes(...)` rather than the boundary-only or removed diagnostics used for tracked names.
- `src/passes/pass_manager.mbt` dispatches only the current active module passes (`duplicate-function-elimination`, `remove-unused-module-elements`, `memory-packing`, `once-reduction`, `global-refining`, `global-struct-inference`, and `reorder-locals`); there is no module dispatcher case for a signature/type-tree DAE2 transform.
- `src/cmd/cmd.mbt` does provide `--closed-world` option plumbing and reports unknown pass flags, but that option is only a prerequisite for a future DAE2 referenced-function mode.
- `src/lib/types.mbt` already models `FuncType`, `Call`, `CallIndirect`, `CallRef`, `ReturnCall*`, and `RefFunc` instruction surfaces a future port would need.
- `src/validate/typecheck.mbt` and `src/validate/validate.mbt` already validate call, `call_ref`, `call_indirect`, and declared-`ref.func` shapes, but they are validation surfaces rather than a callgraph/type-tree rewrite engine.
- `src/wast/` already parses and lowers typed `ref.func` / element-segment surfaces useful for fixtures.
- No `src/passes/*argument*` or `src/passes/dead_argument_elimination2.mbt` owner file exists, and `agent-todo.md` still has no `dae2` slice.

## Filed-back pages

- `docs/wiki/binaryen/passes/dae2/index.md`
- `docs/wiki/binaryen/passes/dae2/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/dae2/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/dae2/fixed-point-forwarding-type-trees-and-expression-removal.md`
- `docs/wiki/binaryen/passes/dae2/wat-shapes.md`
- `docs/wiki/binaryen/passes/dae2/starshine-strategy.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`

## Follow-ups

- If Starshine decides to expose `dae2`, decide first whether the local public name should remain upstream-exact `dae2` or whether it should be a descriptive alias under the DAE family.
- A faithful port needs closed-world module/type-graph infrastructure before it can claim parity on referenced functions; a direct-call-only subset would need to be documented as such.
- Re-check upstream if `dae2` grows result, constant, or type propagation; the current dossier intentionally records those as non-goals rather than assuming they match plain DAE.
