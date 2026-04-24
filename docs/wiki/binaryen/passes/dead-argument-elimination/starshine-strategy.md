---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-dead-argument-elimination-primary-sources.md
  - ../../../raw/research/0293-2026-04-24-dead-argument-elimination-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/cmd/fuzz_harness_wbtest.mbt
  - ../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../no-dwarf-default-optimize-path.md
  - ../dae-optimizing/starshine-strategy.md
  - ../../../../../agent-todo.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ../dae-optimizing/starshine-strategy.md
  - ../dae2/index.md
  - ../signature-pruning/index.md
---

# Starshine `dead-argument-elimination` strategy and status

## Current status

Starshine does **not** currently implement Binaryen plain `dead-argument-elimination` / upstream `dae`.

The important local naming split is:

- upstream Binaryen exposes the short public pass name `dae`;
- Starshine's current boundary-only registry list in [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) contains the descriptive name `dead-argument-elimination`;
- Starshine also lists the optimizing sibling as `dead-argument-elimination-optimizing`, while Binaryen and the no-DWARF path use `dae-optimizing`.

Because [`run_hot_pipeline_expand_passes(...)`](../../../../../src/passes/optimize.mbt) does exact lookup before category rejection, current behavior is:

- `dead-argument-elimination` is known but rejected as boundary-only;
- `dae` is not a local alias today unless one is added later;
- plain DAE is not expanded by the `optimize` or `shrink` presets.

That is a status fact, not an implementation partial.
There is no current Starshine owner file for the pass.

## Exact local code map

## Registry and request behavior

- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
  - `pass_registry_boundary_only_names()` lists `dead-argument-elimination` and `dead-argument-elimination-optimizing`.
  - `pass_registry_entries()` appends boundary-only names as `HotPassRegistryCategory::BoundaryOnly` entries.
  - `run_hot_pipeline_expand_passes(...)` rejects boundary-only entries with the error text `pass flag {name} is boundary-only and is not implemented in the hot pipeline`.
  - `optimize_preset_passes(...)` and `shrink_preset_passes(...)` list currently implemented hot/module passes only; they do not include plain DAE today.

- [`src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt)
  - The registry tests prove the category machinery for active, boundary-only, removed, and preset names.
  - They do not yet contain a focused assertion for `dead-argument-elimination` or for any upstream shorthand alias.
  - If future work adds `dae` as an alias, add a dedicated test so exact-upstream spelling cannot drift silently.

- [`src/cmd/fuzz_harness_wbtest.mbt`](../../../../../src/cmd/fuzz_harness_wbtest.mbt)
  - The fuzz harness has a generic boundary-only rejection test using `global-struct-inference-desc-cast`.
  - That test proves the user-visible error lane but not plain DAE specifically.

## Planning and backlog context

- [`docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`](../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md)
  - Lists `dead-argument-elimination` and `dead-argument-elimination-optimizing` in the boundary-only name family.
  - This is the older registry-map proof that both descriptive local names are intentionally known.

- [`docs/wiki/binaryen/no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
  - Names only `dae-optimizing` in the canonical no-DWARF post-pass phase.
  - This means plain DAE is a registry/API coverage pass, not the current parity-blocking default-path slot.

- [`agent-todo.md`](../../../../../agent-todo.md)
  - Keeps the active `DAE` backlog family under **Dead Argument Elimination Optimizing**.
  - `[DAE]001` covers call-graph pruning, safe parameter removal, call localization, and touched-function tracking.
  - `[DAE]002` covers the nested post-inlining cleanup replay and artifact comparison.
  - There is no dedicated plain-DAE backlog slice today.

## Strategy implication for a future Starshine port

A future Starshine implementation should avoid two extremes:

- do not port plain DAE as an isolated local peephole that only deletes trivially unused parameters;
- do not accidentally give plain DAE the optimizing sibling's nested cleanup behavior.

The practical design should be a shared module-boundary core plus a scheduling flag, mirroring Binaryen's source split:

1. **Call-boundary ownership analysis**
   - collect direct calls by callee;
   - record dropped direct calls;
   - record tail-call relationships;
   - treat exports, imports, `ref.func`, and indirect/call-ref unknowns as signature-rewrite boundaries.

2. **Boundary rewrite core**
   - remove parameters whose incoming values are never used;
   - materialize all-equal constant actuals inside the callee before deleting the param;
   - refine live GC reference params from direct-call operand least-upper-bound evidence;
   - refine result types from returned-value evidence;
   - remove dropped results only when all known direct calls drop them and tail-call constraints allow it.

3. **Callsite and body repair**
   - rewrite every affected direct call when a signature changes;
   - preserve evaluation order for removed operands;
   - localize hard operands into temporaries before retrying if Binaryen would need localization;
   - preserve unreachable / uninhabited-result behavior when call results disappear.

4. **Plain-vs-optimizing split**
   - expose plain `dead-argument-elimination` as the shared core with no nested cleanup rerun;
   - expose optimizing DAE as the same core plus the nested `optimizeAfterInlining(...)`-style cleanup scheduler documented in [`../dae-optimizing/starshine-strategy.md`](../dae-optimizing/starshine-strategy.md).

5. **Name compatibility decision**
   - decide whether to add exact upstream aliases `dae` and `dae-optimizing`, keep only descriptive local names, or support both;
   - update registry tests and pass catalogs with the decision.

## Validation plan when the port starts

Use the existing Binaryen dossier as the behavior checklist:

- [`./binaryen-strategy.md`](./binaryen-strategy.md) for phase order, data ownership, and plain-vs-optimizing split.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md) for the upstream owner-file and proof-surface map.
- [`./wat-shapes.md`](./wat-shapes.md) for beginner-friendly positive and negative cases to convert into tests.
- [`../dae-optimizing/starshine-strategy.md`](../dae-optimizing/starshine-strategy.md) for the optimizing-only scheduler delta.

Concrete future tests should cover at least:

- known-boundary dead-param removal;
- recursive direct-call cycles whose incoming param is never otherwise used;
- all-callers-same-constant materialization;
- GC parameter and result refinement;
- export / import / `ref.func` bailouts;
- hard operand localization and retry;
- dropped-return removal and tail-call bailouts;
- exact local spelling behavior for `dead-argument-elimination` and any future `dae` alias.

## Current non-goals

- Do not claim Starshine has Binaryen `dae` parity; it does not.
- Do not treat `dae2` as a test bucket for plain DAE; it is a separate upstream pass.
- Do not merge this page into the optimizing sibling: the whole point is to keep the shared boundary core and the optimizing-only nested rerun split readable.
