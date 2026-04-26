---
kind: concept
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-ssa-port-readiness-primary-sources.md
  - ../../../raw/research/0402-2026-04-26-ssa-port-readiness.md
  - ../../../raw/binaryen/2026-04-24-ssa-primary-sources.md
  - ../../../raw/research/0321-2026-04-24-ssa-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/ssa_nomerge.mbt
  - ../../../../../src/passes/ssa_nomerge_test.mbt
  - ../../../../../src/ir/ssa_policy.mbt
  - ../../../../../src/ir/ssa_local.mbt
  - ../../../../../src/ir/ssa_destroy.mbt
  - ../../../../../src/passes/pass_common.mbt
  - ../../../../../src/ir/analysis_cache.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./merge-locals-entry-prepends-and-default-values.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../ssa-nomerge/index.md
  - ../ssa-nomerge/starshine-hot-ir-strategy.md
  - ../tracker.md
---

# Starshine port readiness and validation for full `ssa`

This page is the implementation-readiness bridge for upstream Binaryen's public full `ssa` pass.

It does **not** say Starshine should prioritize full `ssa` now. It says that if Starshine ever adds the public sibling, the implementation must preserve the specific Binaryen merge-local contract rather than becoming an alias for the already implemented [`ssa-nomerge`](../ssa-nomerge/index.md).

## Current status in one paragraph

Starshine currently has an active hot pass named `ssa-nomerge` and no known local pass named `ssa`. The local SSA infrastructure is real: it builds a HOT-local SSA overlay, represents phi-like values, chooses concrete locals, and inserts predecessor copies while destroying the overlay. But Binaryen full `ssa` encodes merges differently: it creates fresh merge locals, wraps explicit incoming definitions with `local.tee`, and prepends parameter-entry copies. Those are user-visible rewrite shapes under `wasm-opt --ssa`, so a faithful local full-`ssa` port needs a sibling path with dedicated tests.

## Why full `ssa` is not just `ssa-nomerge` plus more cleanup

Binaryen's shared `SSAify.cpp` engine has one decisive policy flag:

- `ssa-nomerge`: do not materialize merge locals;
- `ssa`: materialize merge locals for multi-source gets.

For full `ssa`, a read with more than one reaching source becomes a fresh merge-local read. Each explicit incoming set feeds the merge local at the original definition point by wrapping the set value in `local.tee mergeLocal ...`. Parameter-entry incoming sources get function-entry `local.set mergeLocal (local.get param)` prepends. Ordinary defaultable local-entry sources do **not** need prepends because a fresh local already starts at the same default value.

Starshine's `ssa_destroy_into_hot(...)` has a different encoding goal: lower overlay phis through predecessor `local.set` copies and concrete local assignment. That is a valid local sibling strategy for `ssa-nomerge`, but it is not Binaryen full `ssa`'s public shape contract.

## First safe Starshine slice

A safe future port should be staged in small, reviewable slices.

### Slice 0: registry honesty

Before rewriting anything, make the public request behavior explicit:

- either keep `ssa` unknown and document that choice, or
- add a known boundary/removed/active status with tests.

Do **not** silently treat `--pass ssa` as `ssa-nomerge`. That would teach the wrong upstream contract and make Binaryen-oracle diffs confusing.

Relevant local surface:

- `src/passes/optimize.mbt` owns active hot passes, module passes, boundary-only names, removed names, and presets.
- Today `ssa-nomerge` is active and appears in both `optimize` and `shrink` presets.
- Today `ssa` is absent from every registry category.

### Slice 1: analyzer / no-rewrite classifier

Add a no-rewrite analyzer that can classify each `local.get` by reaching sources in the Binaryen-relevant categories:

| Source class | Needed full-`ssa` behavior |
| --- | --- |
| one explicit write | retarget get to that write's fresh local |
| one parameter entry | keep parameter slot for the single-source case |
| one ordinary default entry | materialize default value when sound |
| multiple explicit writes | create merge local and tee each explicit incoming value |
| explicit write + parameter entry | create merge local, tee explicit write, prepend parameter copy |
| explicit write + ordinary default entry | create merge local, tee explicit write, no default prepend |
| nondefaultable entry where no default can be materialized | leave the unsafe case untouched |

Local infrastructure already has useful raw material:

- `src/ir/ssa_policy.mbt` has value-origin vocabulary for entry params, entry defaults, local-set defs, local-tee defs, and phis.
- `src/ir/ssa_local.mbt` seeds entry params/defaults and places block phis.
- `src/passes/pass_common.mbt` and `src/ir/analysis_cache.mbt` can cache the HOT SSA overlay.

The open design choice is whether to reuse `HotLocalSsa` directly or build a Binaryen-shaped adapter over it. The validation requirement is the same either way: the classifier must distinguish parameter entry from ordinary default entry.

### Slice 2: direct lit-compatible families

Start with shapes directly backed by Binaryen's `test/lit/passes/ssa.wast`:

- repeated parameter overwrites split into one-assignment locals;
- default ref/null replacement with validation after parent-type sharpening;
- tuple default replacement.

These tests prove the non-merge half of the pass before the new merge-local behavior lands.

### Slice 3: merge-local materialization

Add source-derived tests for the behavior the small official lit file does not isolate:

1. two explicit predecessor writes feeding one read;
2. one-arm parameter overwrite feeding a later read;
3. one-arm ordinary defaultable local overwrite feeding a later read;
4. mixed explicit/default cases with nondefaultable local types left untouched when no valid default exists.

The expected Binaryen-compatible shapes are:

- fresh merge local per merged read;
- `local.tee` around explicit incoming set values;
- parameter-entry prepend only for parameter entries;
- no synthetic zero/null prepend for ordinary defaultable locals.

### Slice 4: sibling stability

After every full-`ssa` slice, keep [`ssa-nomerge`](../ssa-nomerge/index.md) stable:

- existing branch-join predecessor-copy tests in `src/passes/ssa_nomerge_test.mbt` should keep passing;
- `optimize` / `shrink` presets should still name `ssa-nomerge`, not full `ssa`, unless a separate parity decision changes the default pipeline;
- docs should continue to present the two public contracts as siblings, not phases of one local pass.

## Validation ladder

Use this order for a future implementation:

1. Unit tests for registry/request behavior.
2. Focused local tests for direct `ssa.wast` families.
3. Focused local tests for source-derived merge-local families.
4. Sibling regression tests for `ssa-nomerge` predecessor-copy lowering.
5. `moon test` for local correctness.
6. Pass-targeted Binaryen oracle comparison with `wasm-opt --ssa` once the harness supports the spelling.
7. A small generated corpus before any preset scheduling is considered.

Do not add full `ssa` to presets as part of the first implementation. Binaryen's no-DWARF path documented for this repo uses `ssa-nomerge`, and Starshine should keep that scheduler story stable unless a later pipeline audit says otherwise.

## Code locations to read before implementing

- `src/passes/optimize.mbt`
  - registry categories, active `ssa-nomerge` entry, and preset expansion.
- `src/passes/ssa_nomerge.mbt`
  - current sibling runner: requires CFG + SSA and delegates to `ssa_destroy_into_hot(...)`.
- `src/ir/ssa_policy.mbt`
  - SSA value-origin, phi, input, and excluded-feature vocabulary.
- `src/ir/ssa_local.mbt`
  - entry-definition seeding, phi placement, use recording, and phi-input sorting.
- `src/ir/ssa_destroy.mbt`
  - concrete-local assignment, local-use rewrites, predecessor-copy insertion, dead-def cleanup, and the current `ssa_destroy_into_hot(...)` lowering.
- `src/passes/pass_common.mbt`
  - `pass_require_ssa(...)` cache access for hot passes.
- `src/ir/analysis_cache.mbt`
  - storage for `HotLocalSsa`.
- `src/passes/ssa_nomerge_test.mbt`
  - sibling regression cases that must stay stable.

## Non-goals

A first faithful port should not:

- alias `ssa` to `ssa-nomerge`;
- add full `ssa` to `optimize` or `shrink` presets;
- rewrite arbitrary value flow outside locals;
- invent defaults for nondefaultable locals;
- replace Binaryen's merge-local / incoming-tee shape with predecessor copies if the goal is oracle parity for `--ssa`.

## Uncertainty

The main unresolved design question is internal representation, not semantics: should the implementation adapt the existing `HotLocalSsa` overlay, or should it build a smaller LocalGraph-like reaching-set view for this pass? Both are plausible. The required public contract remains the Binaryen shape mapping above.
