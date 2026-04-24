# `optimize-added-constants` primary sources and Starshine follow-up

_Date:_ 2026-04-24  
_Status:_ absorbed into living wiki pages; keep as run-level provenance and decision history

## Question

The `optimize-added-constants` folder already had a corrected strategy, shape catalog, implementation/test map, and focused low-memory safety page, but it still lacked:

- an immutable raw primary-source manifest under `docs/wiki/raw/binaryen/`,
- a dedicated Starshine status / port-strategy page,
- and refreshed catalog entries that tell readers where to follow the local code.

This follow-up asked whether the existing dossier still matched the official Binaryen source and what exact Starshine surfaces a future port would need.

## Local overlap scan

Before writing new pages, the run re-read:

- `AGENTS.md`
- `docs/README.md`
- `docs/wiki/`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/raw/research/`
- `docs/wiki/binaryen/passes/optimize-added-constants/`
- `docs/wiki/binaryen/passes/optimize-added-constants-propagate/`

The existing plain folder was the right durable home. No near-duplicate page was needed for the overview, Binaryen strategy, low-memory safety matrix, implementation/test map, or transformed-shape catalog.

## Primary sources captured

The raw manifest added in this run is:

- `docs/wiki/raw/binaryen/2026-04-24-optimize-added-constants-primary-sources.md`

It captures official Binaryen URLs for:

- `src/passes/OptimizeAddedConstants.cpp`
- `src/passes/pass.cpp`
- `src/pass.h`
- `src/ir/local-graph.h`
- `src/ir/properties.h`
- `src/ir/effects.h`
- `src/wasm-builder.h`
- the plain low-memory test pair
- the propagate low-memory test pair
- the memory64 lit test
- the no-memory lit test
- the official `version_129` release page and releases index

## Source-backed findings

- Binaryen `version_129` exposes both `optimize-added-constants` and `optimize-added-constants-propagate` as public pass names.
- The implementation is in the shared `OptimizeAddedConstants.cpp` file.
- The pass family is about memory address canonicalization for `Load` and `Store` expressions, not general arithmetic reassociation.
- The hard safety gate is `--low-memory-unused`.
- The default Binaryen low-memory threshold remains `PassOptions::LowMemoryBound = 1024`.
- Official tests make the strict cutoff visible: `1023` can fold while `1024` stays out of policy.
- Plain mode owns direct address folds, commuted direct folds, existing-offset accumulation, and overflow-checked constant-pointer normalization.
- Propagate mode adds `LazyLocalGraph` local-pair propagation, helper-local salvage, set cleanup, and iteration.
- No-memory modules are valid no-op inputs.
- Memory64 constant-pointer normalization must check unsigned overflow in the correct pointer width.

## Starshine local status

Current Starshine has no implementation owner file for either public Binaryen spelling.

Exact current local status:

- `src/passes/optimize.mbt` keeps `optimize-added-constants` and `optimize-added-constants-propagate` in `pass_registry_removed_names()`.
- `src/passes/optimize.mbt` rejects removed registry names in `expand_passes(...)` with the removed-name error path.
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md` still lists both names as removed Batch 1 pass-port candidates.
- `agent-todo.md` has no active dedicated `OAC` or `optimize-added-constants` backlog slice today.
- `src/cmd/cmd.mbt` and `src/cli/cli.mbt` already carry `low_memory_unused` and `low_memory_bound` CLI / options plumbing, defaulting to false and `1024`, respectively.

## Future local implementation surfaces

A faithful future Starshine port would likely need to inspect or extend:

- `src/passes/optimize.mbt` for registry category changes and request acceptance.
- `src/cmd/cmd.mbt` for `OptimizeOptions.low_memory_unused` / `low_memory_bound` handoff.
- `src/cli/cli.mbt` for public flag parsing.
- `src/lib/types.mbt` for `MemArg`, scalar/SIMD load/store op payloads, and memory op instruction constructors.
- `src/ir/hot_core.mbt` for `HotOp::Load` / `HotOp::Store` shape identity.
- `src/ir/hot_side_tables.mbt` for `MemArgTable` ownership on HOT load/store nodes.
- `src/ir/hot_builders.mbt` for HOT load/store construction.
- `src/ir/hot_lift.mbt` and `src/ir/hot_lower.mbt` for roundtripping rewritten memory ops.
- `src/ir/use_def.mbt`, `src/ir/ssa_local.mbt`, and neighboring locals passes only if the propagate sibling is ported after the direct plain variant.
- `src/binary/decode.mbt` and `src/binary/encode.mbt` for binary `MemArg` preservation.
- `src/wast/lexer.mbt`, `src/wast/keywords.mbt`, and lowering tests for WAT `align=` / `offset=` surface coverage.
- `src/validate/typecheck.mbt` and memory validation fixtures for preserving trap and memory typing behavior after offset rewrites.

## Uncertainty and design choice

The only new local design tension found in this run is the low-memory bound source of truth:

- Binaryen teaches a fixed `PassOptions::LowMemoryBound = 1024` contract in `version_129`.
- Starshine already exposes `low_memory_bound` as a configurable option.

The dossier now records this as a future parity-mode choice. Current Starshine still has no pass implementation, so there is no local behavior contradiction yet.

## Living wiki updates

This research fed:

- `docs/wiki/binaryen/passes/optimize-added-constants/starshine-strategy.md`
- `docs/wiki/binaryen/passes/optimize-added-constants/index.md`
- `docs/wiki/binaryen/passes/optimize-added-constants/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/optimize-added-constants/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/optimize-added-constants/low-memory-threshold-overflow-and-offset-merge-rules.md`
- `docs/wiki/binaryen/passes/optimize-added-constants/wat-shapes.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`

## Health check notes

The touched folder's main stale-reference risk was that support pages still cited only the older numbered research notes. The refreshed pages now cite the immutable raw primary-source manifest and the new Starshine status page, keeping the folder internally navigable from overview -> transformed shapes -> Binaryen strategy -> Starshine status.
