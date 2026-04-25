# 0330 - `optimize-added-constants-propagate` source bridge and Starshine follow-up

## Status

- Date: 2026-04-25
- Type: Upstream-pass provenance refresh / Starshine status bridge / wiki health follow-up
- Pass chosen: `optimize-added-constants-propagate`
- Local registry status: `removed`
- Supersedes: `0165-2026-04-21-optimize-added-constants-propagate-binaryen-research.md` for raw-source provenance and local Starshine status. The older note remains useful for the original teaching correction that the family is about memory-address offsets rather than generic constant folding.

## Why this pass was selected

The main pass tracker no longer had an obvious missing no-DWARF or saved-`-O4z` dossier target, so I looked for an already-documented pass whose coverage was still incomplete.
`optimize-added-constants-propagate` was a good target because:

1. the folder had a landing page, Binaryen strategy, implementation/test map, and WAT-shape catalog,
2. the sibling plain pass already had a 2026-04-24 raw source manifest and Starshine page,
3. the propagate sibling still lacked its own raw provenance manifest and Starshine status/port-strategy page,
4. several pages still cited only the older `0165` research note in frontmatter, and
5. the pass is easy to mis-teach as generic constant propagation when the real contract is load/store-address offset propagation across safe local `set/get` pairs.

## Primary sources consulted

The sibling-specific raw manifest is:

- `docs/wiki/raw/binaryen/2026-04-25-optimize-added-constants-propagate-primary-sources.md`

Primary online sources consulted through the official Binaryen GitHub repository:

- Binaryen `version_129` release page: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
- `src/passes/OptimizeAddedConstants.cpp` at `version_129` and `main`
- `src/passes/pass.cpp` at `version_129` and `main`
- `src/pass.h` at `version_129` and `main`
- `src/ir/local-graph.h`, `src/ir/properties.h`, `src/ir/effects.h`, and `src/wasm-builder.h`
- `test/passes/optimize-added-constants-propagate_low-memory-unused.{wast,txt}`
- shared baseline tests `test/passes/optimize-added-constants_low-memory-unused.{wast,txt}`
- shared lit checks `test/lit/passes/optimize-added-constants-memory64.wast` and `test/lit/passes/optimize-added-constants-nomemory.wast`

The 2026-04-25 current-`main` review was narrow. It checked that the owner, registration, option, helper, and direct test surfaces had not visibly changed in a way that should alter the living teaching contract. It is not an exhaustive trunk-drift proof.

## Durable Binaryen findings

- `optimize-added-constants-propagate` is a real public pass name, registered separately from `optimize-added-constants`.
- Both variants share `src/passes/OptimizeAddedConstants.cpp` and the direct load/store pointer-to-offset rewrite contract.
- The propagate variant enables the extra local propagation path: it builds `LazyLocalGraph`, chases safe local address carriers, can remove now-dead address `local.set`s, can insert helper locals to preserve the old base, and repeats because one cleanup can unlock another propagation.
- The hard safety gate remains `--low-memory-unused`, with `PassOptions::LowMemoryBound = 1024` as the reviewed upstream cutoff.
- The propagate output oracle intentionally contains `nop` remnants and helper locals; those are part of the visible behavior a local port should test rather than accidentally normalize away without understanding why.

## Durable Starshine findings

- `src/passes/optimize.mbt` keeps `optimize-added-constants-propagate` in `pass_registry_removed_names()` next to the plain sibling.
- `expand_passes(...)` rejects removed names with the explicit removed-pass error.
- The current `optimize` and `shrink` presets do not schedule the pass.
- No `src/passes/optimize_added_constants_propagate.mbt` owner file, dispatcher case, or active `agent-todo.md` implementation slice was found.
- Reusable prerequisites exist but are not an implementation:
  - `src/cli/cli.mbt` parses `--low-memory-unused`, `--no-low-memory-unused`, and `--low-memory-bound`.
  - `src/cmd/cmd.mbt` carries `low_memory_unused` and `low_memory_bound` into `OptimizeOptions` and post-encode repro text.
  - `src/lib/types.mbt` defines `MemArg` and scalar/atomic memory instruction payloads.
  - `src/ir/hot_core.mbt`, `src/ir/hot_side_tables.mbt`, `src/ir/hot_builders.mbt`, `src/ir/hot_lift.mbt`, and `src/ir/hot_lower.mbt` model HOT load/store memory args.
  - `src/passes/remove_unused_names.mbt` demonstrates a pass requesting `HotAnalysis::use_def()`, which is the closest current Starshine analysis surface to the local-pair proof a future port would need.
  - `src/binary/decode.mbt`, `src/binary/encode.mbt`, `src/wast/lexer.mbt`, `src/wast/keywords.mbt`, and `src/validate/typecheck.mbt` are the supporting codec/text/validation surfaces for visible memory offsets.

## Wiki changes made

- Added `docs/wiki/raw/binaryen/2026-04-25-optimize-added-constants-propagate-primary-sources.md`.
- Added `docs/wiki/binaryen/passes/optimize-added-constants-propagate/starshine-strategy.md`.
- Refreshed the `optimize-added-constants-propagate` overview, Binaryen strategy, implementation/test-map, and WAT-shape pages so they cite the sibling-specific raw manifest and Starshine page.
- Updated `docs/wiki/index.md`, `docs/wiki/binaryen/passes/index.md`, and `docs/wiki/binaryen/passes/tracker.md` so the folder is no longer described as only a working dossier without a Starshine bridge.
- Marked the older `0165` research note superseded for provenance and local status.

## Open design questions

- A faithful future port must decide whether Binaryen-parity mode should ignore Starshine's configurable `low_memory_bound` option and hard-match Binaryen's `1024`, or whether Starshine should intentionally expose a configurable extension.
- A future port should likely implement the plain direct pass first, then add the propagate sibling only after a conservative local-pair proof and helper-local insertion strategy are tested.
- It remains open whether HOT use-def analysis is enough for exact `LazyLocalGraph` parity or whether Starshine should build a dedicated address-carrier graph for this pass family.
