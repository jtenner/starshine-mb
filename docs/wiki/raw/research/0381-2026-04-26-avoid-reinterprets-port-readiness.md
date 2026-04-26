---
kind: research
status: supported
last_reviewed: 2026-04-26
sources:
  - ../binaryen/2026-04-26-avoid-reinterprets-port-readiness-primary-sources.md
  - ../binaryen/2026-04-24-avoid-reinterprets-primary-sources.md
  - ./0281-2026-04-24-avoid-reinterprets-primary-sources-and-starshine-followup.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/ir/hot_builders.mbt
  - ../../../../src/ir/hot_mutate.mbt
  - ../../../../src/ir/use_def.mbt
  - ../../../../src/ir/ssa_local.mbt
related:
  - ../../binaryen/passes/avoid-reinterprets/index.md
  - ../../binaryen/passes/avoid-reinterprets/starshine-port-readiness-and-validation.md
---

# `avoid-reinterprets` port-readiness follow-up

## Question

The `avoid-reinterprets` dossier already had correct upstream strategy, transformed-shape, and current Starshine status coverage.
The remaining wiki-health question was whether a future implementer could start a Starshine port without rediscovering the first safe slice, local-code surfaces, and validation ladder from scratch.

## Why this pass was selected

The tracker now has no obvious still-`none` pass target.
`avoid-reinterprets` was a useful major-gap fallback because it was still marked only `dossier`, is a real local removed-registry pass, and has a small Binaryen contract whose first Starshine slice can be defined precisely:

1. direct full-width `reinterpret(load)` load-type flip,
2. later indirect `reinterpret(local.get)` helper-local rewrite after a documented single-load provenance helper exists.

This work does not claim the pass is active.
It makes the future implementation seam explicit while preserving the removed-registry status.

## Primary-source recheck

The focused source manifest is `docs/wiki/raw/binaryen/2026-04-26-avoid-reinterprets-port-readiness-primary-sources.md`.
It rechecked the official Binaryen `version_129` and current-main surfaces for:

- `src/passes/AvoidReinterprets.cpp`
- `src/passes/pass.cpp`
- `test/lit/passes/avoid-reinterprets.wast`
- `test/lit/passes/avoid-reinterprets64.wast`

No teaching-relevant drift was found.
The pass remains a narrow provenance-checked extra-load rewrite:

- full-width reachable source loads only,
- direct reinterpret/load flip where possible,
- indirect local-get users only through a unique source-load proof,
- helper locals for pointer and alternate typed value,
- memory64 pointer helper typed from the memory address type,
- conservative no-ops for partial loads, params/default-entry values, merges, non-fallthrough wrappers, and unreachable/cyclic unsupported origins.

## Starshine code-map findings

The current local implementation state is unchanged:

- `src/passes/optimize.mbt:144-150` keeps `avoid-reinterprets` in `pass_registry_removed_names()`.
- `src/passes/optimize.mbt:274-276` emits removed registry entries.
- `src/passes/optimize.mbt:469-471` rejects active removed-pass requests.
- `src/passes/registry_test.mbt:160-168` proves the removed-name behavior generically, using `de-nan` rather than a pass-specific `avoid-reinterprets` fixture.

The future port prerequisites are now clearer:

- `src/ir/hot_builders.mbt:296-333` covers local get/set/tee builders.
- `src/ir/hot_builders.mbt:533-546` covers load builders.
- `src/ir/hot_builders.mbt:608-618` covers unary builders.
- `src/ir/hot_mutate.mbt:196-201` appends fresh body locals.
- `src/ir/use_def.mbt:29-31`, `82-94`, and `390-395` expose local read/write collection, but not reaching-set equivalence.
- `src/ir/ssa_local.mbt:96-118`, `291-301`, `329-352`, and `388-393` expose value IDs, entry defs, local-write defs, and value uses, but the wiki should not call this a Binaryen `LocalGraph` substitute until the merge/default/fallthrough/unreachable behavior is specified.
- `src/lib/types.mbt`, `src/wast/lower_to_lib.mbt`, `src/binary/encode.mbt`, `src/validate/typecheck.mbt`, and `src/ir/hot_lift.mbt` already cover the four reinterpret opcodes, so missing opcode representation is not the blocker.

## First-slice recommendation

The safest first Starshine slice should avoid the local-chain proof entirely:

1. keep the pass removed while adding failing reduced fixtures in a future implementation branch;
2. implement only direct `reinterpret(load)` where the load is full-width and reachable;
3. rewrite by preserving the `MemArg` and address child and changing only the load result type/opcode family;
4. prove partial loads and non-load operands remain unchanged;
5. compare the focused fixtures against `wasm-opt --avoid-reinterprets`.

That slice is useful because it validates opcode recognition, load-width checks, type rewrites, HOT lowering, and Binaryen oracle comparison without requiring a new LocalGraph-equivalent proof.

## Second-slice recommendation

Only after the direct slice is green should Starshine add the indirect helper-local family:

- classify `reinterpret(local.get)` as `Known(source-load)`, `Unknown`, or unsupported rather than silently guessing;
- use a documented single-load provenance helper with explicit decisions for entry/default values, merges, copies, cycles, and wrapper fallthrough;
- allocate one pointer helper local with the memory address type and one alternate typed helper local per eligible source load;
- rewrite source-load sites to compute the alternate typed load while preserving the original load result;
- rewrite all proven reinterpret users to the shared alternate helper local.

## Validation ladder filed back to the wiki

The new living page `docs/wiki/binaryen/passes/avoid-reinterprets/starshine-port-readiness-and-validation.md` records a beginner-to-advanced ladder:

1. registry honesty,
2. direct load flips,
3. indirect single-user helper locals,
4. helper sharing and mixed-use preservation,
5. copy-chain positives,
6. partial/param/merge/wrapper/cycle bailouts,
7. memory64 pointer-temp typing,
8. Binaryen oracle comparison,
9. pass-targeted fuzzing after reduced fixtures are green.

## Uncertainties preserved

- Starshine still lacks a documented `LocalGraph`-equivalent helper for this pass.
- HOT local SSA may become the right substrate, but today it does not document the exact Binaryen `getSingleLoad(...)` behavior around params/default-entry values, merges, fallthrough wrappers, or unreachable cycles.
- The first implementation should decide whether the pass belongs as a HOT pass beside local/memory peepholes or as a helper shared with broader locals-family ports.

## Outcome

The dossier is now deep enough for future implementation planning:

- the Binaryen strategy remains source-backed;
- the transformed-shape catalog remains beginner-friendly;
- exact current Starshine code locations are updated;
- the first safe local slice and validation ladder are no longer implicit;
- the pass remains explicitly removed and outside the current no-DWARF / saved-`-O4z` parity queues.
