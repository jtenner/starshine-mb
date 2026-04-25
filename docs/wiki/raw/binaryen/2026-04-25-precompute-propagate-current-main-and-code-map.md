# Binaryen `precompute-propagate` current-main/code-map recheck

_Capture date:_ 2026-04-25  
_Status:_ immutable source manifest for the 2026-04-25 `docs/wiki/binaryen/passes/precompute-propagate/` refresh

## Scope

This file captures the primary online sources rechecked for the `precompute-propagate` wiki refresh. It complements, rather than replaces, the 2026-04-24 tagged-source manifest:

- `docs/wiki/raw/binaryen/2026-04-24-precompute-propagate-primary-sources.md`

The durable teaching target for this recheck is narrow: keep the existing Binaryen strategy stable, add a fresher current-`main` provenance anchor, and sharpen the Starshine follow-along code map with exact local line ranges.

## Primary online sources consulted

### Official Binaryen current-`main` sources

- `src/passes/Precompute.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/Precompute.cpp>
  - Relevant symbols / regions: `doWalkFunction`, `propagateLocals`, `precomputeValue`, `getValues`, `LazyLocalGraph`, `Properties::getFallthrough`.
- `src/passes/pass.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - Relevant regions: public `registerPass("precompute")`, public `registerPass("precompute-propagate")`, early propagation slot, late propagation slot.
- `src/passes/opt-utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/opt-utils.h>
  - Relevant symbols / regions: `addUsefulPassesAfterInlining`, `optimizeAfterInlining`, nested `FilteredPassRunner`.
- `src/ir/local-graph.h`
  - <https://github.com/WebAssembly/binaryen/blob/main/src/ir/local-graph.h>
  - Relevant role: get/set influence graph used by `propagateLocals`.
- `src/ir/properties.h`
  - <https://github.com/WebAssembly/binaryen/blob/main/src/ir/properties.h>
  - Relevant role: `Properties::getFallthrough(...)` helper used to evaluate candidate set fallthrough values.
- `src/wasm-interpreter.h`
  - <https://github.com/WebAssembly/binaryen/blob/main/src/wasm-interpreter.h>
  - Relevant role: shared `ConstantExpressionRunner` / `Flow` semantic-evaluation substrate.

### Official Binaryen `version_129` comparison anchors

- `src/passes/Precompute.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Precompute.cpp>
- `src/passes/pass.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `src/passes/opt-utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- `src/ir/local-graph.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h>
- `src/ir/properties.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
- `src/wasm-interpreter.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-interpreter.h>

### Official dedicated lit-test anchors

- `test/lit/passes/precompute-propagate-partial.wast`
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/precompute-propagate-partial.wast>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/precompute-propagate-partial.wast>
- `test/lit/passes/precompute-propagate_all-features.wast`
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/precompute-propagate_all-features.wast>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/precompute-propagate_all-features.wast>

## Durable observations from the current-main recheck

- Current `main` still exposes `precompute-propagate` as a real public pass name in `pass.cpp`, adjacent to plain `precompute`, with the same high-level description that the variant computes compile-time evaluatable expressions and propagates them through locals.
- Current `main` still uses the same visible strategy in `Precompute.cpp`: ordinary semantic precompute first, optional `propagateLocals(func)`, and one extra ordinary walk when propagation adds `getValues` facts. The comments still deliberately leave deeper cycles to later pass runs or `--converge` rather than rebuilding `LocalGraph` repeatedly.
- Current `main` still grounds the propagation phase in `LazyLocalGraph`, not in a broad whole-program or SSA-like SCCP engine.
- Current `main` still evaluates candidate local-set values through `Properties::getFallthrough(...)`, then requires concrete values whose type is a valid subtype of the original set value expression type.
- Current `main` still requires all reaching local-set sources for a `local.get` to agree on the same concrete literal tuple. Entry reads keep the important split: params are unknown, defaultable body locals can contribute zero/default values, and suspicious nondefaultable entry reads bail out.
- Current `main` still wires `precompute-propagate` into `opt-utils.h` as the cleanup prefix for `optimizeAfterInlining(...)`, before the filtered nested default-function pipeline.
- Current `main` still schedules `precompute-propagate` in the higher-aggression early and late propagation slots, while lower top-level settings use plain `precompute`.
- No teaching-relevant current-main drift was found against the existing `version_129` dossier contract during this focused recheck.

## Starshine code-map anchors rechecked locally

These local paths are not upstream Binaryen sources, but they are the exact in-repo surfaces used to refresh the Starshine strategy page:

- `src/passes/optimize.mbt:144-151` keeps `"precompute-propagate"` in `pass_registry_removed_names()`.
- `src/passes/optimize.mbt:211-215` registers active plain `"precompute"` through `precompute_descriptor()` and does not register a sibling descriptor.
- `src/passes/optimize.mbt:250-269` lists the modeled `optimize` / `shrink` preset expansion with plain `"precompute"` slots only.
- `src/passes/optimize.mbt:463-472` is the public request guard that reports boundary-only and removed-name errors before dispatch.
- `src/passes/precompute.mbt:2-16` defines the active plain descriptor and summary.
- `src/passes/precompute.mbt:20-656` owns current scalar/global constant-source and integer/control fold helpers.
- `src/passes/precompute.mbt:762-1063` owns current dead-drop and root/region cleanup helpers.
- `src/passes/precompute.mbt:1095-1166` runs the iterative plain HOT precompute loop.
- `src/passes/pass_manager.mbt:8670-8704` dispatches active HOT passes and has only a `"precompute"` arm.
- `src/passes/registry_test.mbt:105-122` proves the active descriptor surface includes plain `precompute`.
- `src/passes/registry_test.mbt:146-160` proves preset expansion stays on active pass names and includes plain `precompute` slots.
- `src/passes/optimize_test.mbt:290-335` proves the modeled `optimize` and `shrink` presets replay plain `precompute` in both PC slots.
- `src/passes/precompute_test.mbt` and `src/cmd/cmd_wbtest.mbt` remain plain-`precompute` behavior and artifact-replay proof, not evidence for the sibling propagation mode.

## Uncertainties and caveats

- This was a focused source/navigation recheck, not an exhaustive semantic diff of all `Precompute.cpp` helper internals. The existing `version_129` pages remain the tagged-oracle contract.
- GitHub HTML line output is not treated as stable source-line provenance in the living pages. The wiki cites file paths plus symbols/regions and exact local MoonBit line ranges instead.
- The local Starshine conclusion is intentionally negative: exact local code proves the sibling is still unavailable, not that the active plain `precompute` pass has grown a hidden propagation mode.

## Consumability rule

Use this file as the provenance anchor for the 2026-04-25 refresh. Use the living pages in `docs/wiki/binaryen/passes/precompute-propagate/` for explanations, shape guides, and port planning.
