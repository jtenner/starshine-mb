---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-dae-optimizing-primary-sources.md
  - ../../../raw/research/0285-2026-04-24-dae-optimizing-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../no-dwarf-default-optimize-path.md
  - ../../../raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md
  - ../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json
  - ../../../../../agent-todo.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./signature-updates-and-nested-reruns.md
  - ./wat-shapes.md
  - ../dead-argument-elimination/index.md
  - ../inlining-optimizing/starshine-strategy.md
  - ../precompute-propagate/index.md
  - ../local-cse/index.md
  - ../code-folding/index.md
---

# Starshine `dae-optimizing` strategy and status

## Current status

Starshine does **not** currently implement Binaryen `dae-optimizing`.

The important local distinction is naming:

- upstream Binaryen exposes the public pass name `dae-optimizing`;
- Starshine's current boundary-only registry list in [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) contains the descriptive local name `dead-argument-elimination-optimizing`;
- the saved generated-artifact audit and Binaryen path docs still use the canonical upstream spelling `dae-optimizing`.

Because [`run_hot_pipeline_expand_passes(...)`](../../../../../src/passes/optimize.mbt) does exact lookup before category rejection, current behavior is:

- `dead-argument-elimination-optimizing` is known but rejected as boundary-only;
- `dae-optimizing` is the upstream/audit/backlog spelling, but not currently a local registry entry unless an alias is added later.

That mismatch is a documentation and planning caveat for future work, not evidence that the pass is already partially implemented.

## Exact local code map

## Registry and request behavior

- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
  - `pass_registry_boundary_only_names()` lists `dead-argument-elimination` and `dead-argument-elimination-optimizing`.
  - `pass_registry_entries()` appends all boundary-only names as `HotPassRegistryCategory::BoundaryOnly` entries.
  - `run_hot_pipeline_expand_passes(...)` rejects boundary-only entries with the error text `pass flag {name} is boundary-only and is not implemented in the hot pipeline`.
  - `optimize_preset_passes(...)` and `shrink_preset_passes(...)` list only currently implemented hot/module passes; they do not include `dae-optimizing` or `dead-argument-elimination-optimizing` today.

- [`src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt)
  - The registry tests prove the active/boundary/removed classification mechanism, but they do not yet have a dedicated assertion for either DAE optimizing spelling.
  - If a future alias is added, add a focused test so the upstream spelling cannot silently drift again.

## Scheduler and parity context

- [`docs/wiki/binaryen/no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
  - Names `dae-optimizing` as the first late post-pass Binaryen slot.
  - Records the nested rerun rule: `dae-optimizing` and `inlining-optimizing` both call the post-inlining cleanup helper on changed functions.

- [`docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md`](../../../raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md)
  - Records the original DAE backlog contract: remove provably dead call parameters, then rerun the nested post-inlining cleanup pipeline on touched functions.

- [`.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json`](../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json)
  - Records saved generated-artifact skipped slot `48` as `dae-optimizing`.

- [`agent-todo.md`](../../../../../agent-todo.md)
  - Keeps the active DAE backlog slice family.
  - `[DAE]001` covers call-graph pruning, safe parameter removal, call localization, and touched-function tracking.
  - `[DAE]002` covers nested `optimizeAfterInlining` replay plus artifact comparison.

## Strategy implication for a future Starshine port

A Starshine port should be designed as a module-boundary and scheduler feature, not as a HOT expression peephole.

Minimum required pieces:

1. **Boundary ownership analysis**
   - collect direct calls by callee;
   - treat exports and `ref.func` escapes as unseen calls;
   - skip imports and externally visible signatures.

2. **Signature rewrite engine**
   - remove dead params from callee declarations and every direct callsite;
   - refine GC reference params using direct-call operand LUBs;
   - refine result types from actual returned values;
   - remove dropped results only when tail-call and dropped-call facts allow it.

3. **Callsite repair**
   - preserve evaluation order for removed call operands;
   - localize hard call operands before parameter removal when needed;
   - preserve uninhabitable-result behavior with `call; unreachable`-style repair.

4. **Nested cleanup scheduler**
   - track every function whose body or boundary changed;
   - prepend the `precompute-propagate` sibling before the default function cleanup pipeline, matching Binaryen's `OptUtils::optimizeAfterInlining(...)` contract;
   - keep this nested lane separate from `simplify-globals-optimizing`, whose nested cleanup contract is intentionally different.

5. **Name compatibility decision**
   - decide whether to add a `dae-optimizing` alias, rename `dead-argument-elimination-optimizing`, or keep both documented as distinct upstream-vs-local spellings;
   - add registry tests for the chosen behavior.

## Validation plan when the port starts

Use the Binaryen dossier as the behavior checklist:

- [`./binaryen-strategy.md`](./binaryen-strategy.md) for phase order, data ownership, and nested cleanup behavior.
- [`./signature-updates-and-nested-reruns.md`](./signature-updates-and-nested-reruns.md) for boundary safety, localization, result removal, and rerun caveats.
- [`./wat-shapes.md`](./wat-shapes.md) for beginner-friendly positive and negative shapes to convert into focused tests.
- [`../dead-argument-elimination/implementation-structure-and-tests.md`](../dead-argument-elimination/implementation-structure-and-tests.md) for the shared upstream owner-file and proof-surface map.

Concrete future tests should cover at least:

- known-boundary dead-param removal;
- every-caller-same-constant materialization;
- GC parameter and result refinement;
- exported / `ref.func` / import bailouts;
- hard call-operand localization;
- dropped-return removal and uninhabitable-result repair;
- nested cleanup replay on touched functions;
- registry behavior for whichever local spelling decision is chosen.

## Current non-goals

- Do not claim current Starshine matches Binaryen `dae-optimizing` parity; it does not.
- Do not fold this work into plain `dead-argument-elimination` without preserving the optimizing-only nested rerun split.
- Do not describe `dae-optimizing` as already present in the local registry under the exact upstream spelling until `src/passes/optimize.mbt` actually adds that alias.
