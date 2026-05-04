---
kind: concept
status: supported
last_reviewed: 2026-05-04
sources:
  - ../../../raw/binaryen/2026-05-04-precompute-propagate-current-main-recheck.md
  - ../../../raw/research/0440-2026-05-04-precompute-propagate-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-25-precompute-propagate-current-main-and-code-map.md
  - ../../../raw/binaryen/2026-04-24-precompute-propagate-primary-sources.md
  - ../../../raw/research/0375-2026-04-25-precompute-propagate-current-main-code-map.md
  - ../../../raw/research/0296-2026-04-24-precompute-propagate-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0167-2026-04-21-precompute-propagate-binaryen-research.md
  - ../../../raw/research/0198-2026-04-21-precompute-propagate-worklist-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/precompute.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../../../../src/passes/precompute_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./local-worklist-fallthrough-and-merge-boundaries.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../precompute/index.md
  - ../dae-optimizing/starshine-strategy.md
  - ../inlining-optimizing/starshine-strategy.md
  - ../simplify-globals-optimizing/starshine-strategy.md
---

# Starshine port-readiness for `precompute-propagate`

This page is the implementation-readiness bridge for upstream Binaryen `precompute-propagate`.

It is intentionally separate from [`./starshine-strategy.md`](./starshine-strategy.md): the strategy page says what the local truth is today, while this page says what a faithful future port would need first.

## Current Starshine status

Starshine does **not** implement Binaryen's `precompute-propagate` sibling yet.

The local status remains a removed-registry marker, not a solved alias:

- `src/passes/optimize.mbt:144-151` keeps `precompute-propagate` in the removed-name table;
- `src/passes/optimize.mbt:211-215` registers plain `precompute`, not the sibling;
- `src/passes/optimize.mbt:463-472` rejects removed-name requests before dispatch;
- `src/passes/pass_manager.mbt:8670-8704` dispatches plain `precompute` but has no `precompute-propagate` arm;
- plain `precompute` in `src/passes/precompute.mbt:2-16` is the nearest landing zone, but it is still only the scalar/control HOT subset.

So the right user-facing summary is:

> Starshine can already execute the plain precompute family, but it has no local get/set propagation sibling yet.

## Why this page exists

The pass is easy to under-teach as “just the more aggressive precompute mode.”
That is too vague for a future port.

A faithful Starshine port has to add a new local-propagation layer, not just a new registry alias.

## Exact local code map

### Registry and request handling

- `src/passes/optimize.mbt:144-151`
  - removed registry currently carries `precompute-propagate`
- `src/passes/optimize.mbt:211-215`
  - active registry currently exposes plain `precompute`
- `src/passes/optimize.mbt:463-472`
  - requests for removed names fail before hot dispatch

### Current landing zone

- `src/passes/precompute.mbt:2-16`
  - public active descriptor for plain `precompute`
- `src/passes/precompute.mbt:20-138`
  - current constant-source model
- `src/passes/precompute.mbt:138-720`
  - scalar/global/conditional rewrite helpers
- `src/passes/precompute.mbt:722-1063`
  - cleanup and writeback hygiene helpers
- `src/passes/precompute.mbt:1095-1166`
  - iterative `precompute_run(...)` fixpoint for the plain pass

### Hot-pass dispatch and scheduler rails

- `src/passes/pass_manager.mbt:8670-8704`
  - dispatches plain `precompute`; there is no sibling dispatch arm yet
- neighboring `run_hot_pipeline_precompute_*` helpers in the same file
  - preserve the artifact-driven writeback safety environment built around plain `precompute`
  - these are lowering / validation guard rails, not evidence of a local-propagation algorithm

## What a future Starshine port must prove

1. **Registry honesty**
   - keep `precompute-propagate` removed until the sibling actually exists
   - add focused request tests once the sibling is introduced
2. **Local-flow proof layer**
   - build or reuse a `LazyLocalGraph`-equivalent get/set influence graph over HOT IR
   - model set-to-get and get-to-set influences conservatively
3. **Fallthrough-value set analysis**
   - preserve the Binaryen rule that candidate set values come from fallthrough values, not arbitrary expression replacement
   - keep the subtype/type-safety filter explicit
4. **All-reaching-sets get consensus**
   - fold a `local.get` only when every reaching source agrees on the same concrete literal tuple
   - preserve differing-constant and unknown-arm bailouts
5. **Entry-value handling**
   - params are not constants
   - defaultable locals may contribute zero/default literals
   - nondefaultable local entry reads must bail out
6. **Second evaluator walk**
   - expose a get-values map to the evaluator
   - run one extra evaluator walk after propagation succeeds
   - avoid silently turning the pass into unbounded SCCP
7. **Nested optimizing scheduler support**
   - implement the `optimizeAfterInlining(...)`-style role before claiming parity for `dae-optimizing` / `inlining-optimizing` cleanup
   - keep the contrast with `simplify-globals-optimizing`, whose upstream nested default-function rerun deliberately lacks the prepended `precompute-propagate`
8. **Shared semantic evaluator breadth**
   - decide whether to broaden plain `precompute` first or build the local-flow layer first
   - in either order, keep the public mode split testable

## Relationship to neighboring pass pages

### Plain `precompute`

[`../precompute/starshine-hot-ir-strategy.md`](../precompute/starshine-hot-ir-strategy.md) is the current active-code map.

Use it for:

- scalar folding behavior that already exists;
- current artifact-retirement proof;
- writeback guard locations;
- active top-level preset slots.

Use this page for:

- the missing sibling-mode status;
- what a future propagation port must add;
- why `precompute-propagate` references in other dossiers are upstream scheduler facts, not local implementation facts.

### `dae-optimizing` and `inlining-optimizing`

Binaryen's optimizing boundary rewrites use a nested cleanup path that prepends `precompute-propagate`.

Current Starshine does not have that nested path yet. Future work on those passes should therefore treat `precompute-propagate` as a scheduler dependency, not as a solved local primitive.

### `simplify-globals-optimizing`

This sibling is the contrast case: Binaryen reruns the default function pipeline after optimizing global simplification, but without prepending `precompute-propagate`.

That difference should stay visible in future Starshine scheduler work.

## Implementation strategy recommendation

When this pass is ported, keep the steps small:

1. add explicit tests showing `precompute-propagate` is still rejected while removed;
2. design the HOT get/set influence graph and its safety boundaries;
3. add a feature-limited propagation prototype behind the exact pass name;
4. prove the dedicated upstream WAT families from [`./wat-shapes.md`](./wat-shapes.md): identical-merge positives, differing-merge bailouts, default-entry positives, tee/fallthrough positives, and tuple-local positives;
5. only then wire nested optimizing reruns.

Avoid two tempting shortcuts:

- do not register `precompute-propagate` as an alias of plain `precompute`; and
- do not replace Binaryen's bounded get/set consensus model with an unsourced generic SCCP story without documenting and testing the semantic difference.

## Bottom line

The Starshine side is now clear enough for future readers:

- upstream `precompute-propagate` has a real primary-source-backed pass contract;
- Starshine currently knows the name only as removed;
- the local `precompute` implementation is the nearest landing zone but lacks the local-propagation phase;
- future scheduler work for optimizing boundary rewrites must not assume the sibling already exists.
