---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-precompute-propagate-primary-sources.md
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
  - ../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../../../../agent-todo.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./local-worklist-fallthrough-and-merge-boundaries.md
  - ./wat-shapes.md
  - ../precompute/index.md
  - ../precompute/starshine-hot-ir-strategy.md
  - ../dae-optimizing/starshine-strategy.md
  - ../inlining-optimizing/starshine-strategy.md
  - ../simplify-globals-optimizing/starshine-strategy.md
---

# Starshine `precompute-propagate` strategy today

This page describes the **current in-tree Starshine status** for upstream Binaryen `precompute-propagate`.

It is intentionally separate from [`../precompute/starshine-hot-ir-strategy.md`](../precompute/starshine-hot-ir-strategy.md): Starshine implements plain `precompute` today, but it does **not** implement the sibling local-propagation mode yet.

## Short version

Current Starshine status:

- `precompute-propagate` is a known **removed** registry name.
- There is no `precompute-propagate` owner file.
- There is no `precompute-propagate` hot-pass descriptor.
- There is no active nested-rerun scheduler that prepends it after `dae-optimizing` / `inlining-optimizing`-style boundary rewrites.
- The reusable local landing zone is the active [`src/passes/precompute.mbt`](../../../../../src/passes/precompute.mbt) plain-`precompute` implementation, but that file currently implements scalar HOT folding and cleanup rather than Binaryen's `LazyLocalGraph` propagation sibling.

So the honest current strategy is:

- **preserve the public pass name as an unavailable compatibility / planning marker, keep the docs explicit about the upstream sibling contract, and treat a future local port as a new propagation layer on top of the plain `precompute` infrastructure rather than as a registry alias.**

## Exact local code map

### 1. Public registry status

The registry source of truth is [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).

Read these locations first:

- `pass_registry_removed_names()`
  - includes `"precompute-propagate"`
  - this is the current user-visible implementation status
- `pass_registry_entries()`
  - registers active plain `"precompute"` through `precompute_descriptor()`
  - does **not** register a `precompute-propagate` hot descriptor
- `optimize_preset_passes(...)`
- `shrink_preset_passes(...)`
  - replay plain `"precompute"` in the modeled top-level PC slots
  - do not schedule `"precompute-propagate"`

This is the strongest local status fact: the sibling name exists, but only in the removed-name table.

### 2. Active plain-`precompute` landing zone

The active local implementation is [`src/passes/precompute.mbt`](../../../../../src/passes/precompute.mbt).

Useful read-along functions:

- `precompute_descriptor()`
  - declares only the active pass name `"precompute"`
- `precompute_summary()`
  - intentionally describes a narrower scalar top-level slot pass
- `precompute_global_const(...)`
- `precompute_i32_exact_const(...)`
- `precompute_i64_exact_const(...)`
  - define the current local constant-source model
- `precompute_try_fold_global_get(...)`
- `precompute_try_fold_unary(...)`
- `precompute_try_fold_binary(...)`
  - own current scalar/global folds
- `precompute_try_fold_constant_if(...)`
  - owns current constant-`if` arm picking
- `precompute_is_discardable_value(...)`
- `precompute_try_eliminate_dead_drop(...)`
- `precompute_simplify_region_roots(...)`
- `precompute_trim_region_nops(...)`
- `precompute_coalesce_all_root_nops(...)`
- `precompute_trim_root_nops_before_trailing_const(...)`
  - own local HOT/writeback hygiene cleanup
- `precompute_run(...)`
  - runs an iterative local HOT fixpoint over the above helpers

Those helpers are real future infrastructure, but they are not enough to call the sibling implemented. They do not model Binaryen's `propagateLocals(...)` get/set worklist.

### 3. Hot-pass dispatch and writeback guard rails

The active dispatcher is [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt).

Important locations:

- `hot_pass_run(...)`
  - dispatches `"precompute" => precompute_run(ctx, func)`
  - has no `"precompute-propagate"` arm
- `run_hot_pipeline_precompute_writeback_validation_error(...)`
- `run_hot_pipeline_precompute_lowered_func_has_invalid_escape_carrier(...)`
- neighboring `run_hot_pipeline_precompute_*` helpers
  - preserve the artifact-driven writeback safety environment built around plain `precompute`

That writeback work is important for a future sibling port, but it should not be misread as evidence that the Binaryen `precompute-propagate` algorithm is already present.

### 4. Tests that prove the local status

#### Registry tests

[`src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt) proves the active and unavailable surfaces:

- `batch 1 descriptors expose the active first hot ports`
  - checks `precompute_descriptor().name == "precompute"`
- `preset expansion stays on implemented active pass names`
  - checks the current modeled `optimize` / `shrink` expansion uses active names only and includes plain `precompute`
- `run_hot_pipeline rejects removed registry names`
  - proves the generic removed-name request path rejects unavailable passes

The test currently uses `de-nan` as the explicit removed-name example, not `precompute-propagate`; the registry list in `optimize.mbt` is the exact source for this pass's removed status.

#### Preset-slot tests

[`src/passes/optimize_test.mbt`](../../../../../src/passes/optimize_test.mbt) locks the local scheduler story:

- `optimize preset replays precompute in both PC slots`
- `shrink preset replays precompute in both PC slots`

Those tests deliberately prove two plain-`precompute` top-level slots, not the Binaryen aggressive sibling.

#### Plain precompute behavior and artifact tests

[`src/passes/precompute_test.mbt`](../../../../../src/passes/precompute_test.mbt) proves the current scalar/control rewrite subset.
[`src/cmd/cmd_wbtest.mbt`](../../../../../src/cmd/cmd_wbtest.mbt) proves command-line replay lanes for plain `--precompute` on generated and debug artifacts.

Those tests are useful future regression scaffolding, but they are not sibling-pass proof.

## What is missing for Binaryen parity

A real local `precompute-propagate` port would need all of the following, in addition to the current scalar/plain infrastructure:

1. **A public pass entry**
   - move `precompute-propagate` out of removed-name handling only when the implementation exists
   - add focused registry / request tests for the exact pass name
2. **A local-flow proof layer**
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
