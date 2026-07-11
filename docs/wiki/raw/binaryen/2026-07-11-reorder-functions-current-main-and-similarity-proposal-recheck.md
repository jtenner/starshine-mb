# Binaryen `reorder-functions` current-main and similarity-proposal recheck

_Capture date:_ 2026-07-11  
_Status:_ immutable primary-source freshness manifest for `docs/wiki/binaryen/passes/reorder-functions/`

## Scope

This capture supersedes the **freshness claim** in the 2026-05-05 `reorder-functions` recheck. It does not replace the older immutable captures: `2026-04-24-reorder-functions-primary-sources.md` remains the tagged-release provenance, and the May captures remain dated historical evidence.

The review deliberately separates two things that are easy to conflate:

1. what Binaryen `main` implements and registers today; and
2. an open upstream proposal for a distinct similarity-based function orderer.

## Primary sources reread

### Current Binaryen `main`

- Owner: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/ReorderFunctions.cpp>
- Registration: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- Shipped focused oracle: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/reorder-functions-by-name.wast>

### Open upstream proposal, not current `main`

- Pull request #8696, _Add compression-oriented function reordering pass_: <https://github.com/WebAssembly/binaryen/pull/8696>
- Proposed owner and test diff: <https://github.com/WebAssembly/binaryen/pull/8696/files>

### Current Starshine evidence

- Boundary-only registry: `src/passes/optimize.mbt`
- Module-pass dispatch: `src/passes/pass_manager.mbt`
- Existing function-index-remap reference implementation: `src/passes/duplicate_function_elimination.mbt`
- Compare-pass public allowlist: `scripts/lib/pass-fuzz-compare-task.ts`

## Current-main result

No behavior-bearing drift was found on the reviewed current-main surface for the two shipped passes:

- `reorder-functions` still counts direct `call` targets plus start, function-export, and element-segment references; it still leaves `ref.func` and declaration-section mentions as explicit TODOs; it still sorts by descending count and then descending name.
- `reorder-functions-by-name` still sorts declarations by ascending name and reports no non-nullable-local fixup requirement.
- `pass.cpp` still registers only those two `reorder-functions*` spellings in this family. It does **not** register `reorder-functions-by-similarity`.
- The shipped focused lit oracle remains `reorder-functions-by-name.wast`. The review did not find a shipped current-main similarity-pass fixture because the proposed pass has not landed.

This is a narrow source review, not an exhaustive audit of every Binaryen option, test, or historical revision.

## Open similarity proposal boundary

As checked on 2026-07-11, Binaryen PR #8696 is still **open**. It proposes a separate public pass named `reorder-functions-by-similarity`, not a change to the shipped frequency-based `reorder-functions` contract.

The proposal's implementation sketch:

- preserves imported functions at the beginning of the module;
- analyzes defined function bodies in parallel;
- forms a lexicographic key from the function signature, local-variable types, a bounded post-order structural opcode sequence, and original defined-function order;
- sorts defined functions by that key to place structurally similar emitted code near each other;
- adds help-text and a dedicated lit fixture.

The author reports compressed-size measurements for selected real-world inputs, including gzip, Brotli, and zstd. Those measurements are proposal evidence only: they are not a release promise, not a universal size guarantee, and not Starshine evidence.

The review discussion records material unresolved design questions:

- the key intentionally favors common prefixes/prologues; a reviewer noted that substring matching could be more robust but likely slower;
- a maintainer suggested reusing or adapting richer `Outlining.cpp` hashing/stringification machinery, while the author deferred that larger/slower experiment;
- the exact set of instruction immediates included in the structural key is heuristic-sensitive.

Therefore this proposal must remain a **watch item**, not an upstream-supported pass or a local implementation target. Do not add it to Binaryen-current pass inventories, Starshine registries, presets, or compare-pass allowlists unless it lands and local behavior is separately designed and tested.

## Consumability rule

Use this capture for:

- current-main freshness of the shipped `reorder-functions` family;
- the precise distinction between the shipped frequency/name passes and the open similarity proposal;
- the current local status that Starshine has only the two existing names as boundary-only and no runnable compare-pass lane.

Use the 2026-04-24 capture for tagged `version_129` provenance. If PR #8696 lands, is closed, or materially changes, create a new dated capture rather than editing this immutable file.
