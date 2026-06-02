---
kind: concept
status: supported
last_reviewed: 2026-05-04
sources:
  - ../../../raw/binaryen/2026-05-04-precompute-propagate-current-main-recheck.md
  - ../../../raw/research/0440-2026-05-04-precompute-propagate-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-25-precompute-propagate-current-main-and-code-map.md
  - ../../../raw/research/0375-2026-04-25-precompute-propagate-current-main-code-map.md
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
  - ../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md
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
  - ./starshine-port-readiness-and-validation.md
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

For the concrete first-slice plan and validation ladder, see [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

## Exact local code map

### 1. Public registry status

The registry source of truth is [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).

Read these locations first:

- `src/passes/optimize.mbt:144-151`
  - `pass_registry_removed_names()` includes `"precompute-propagate"`
  - this is the current user-visible implementation status
- `src/passes/optimize.mbt:211-215`
  - `pass_registry_entries()` registers active plain `"precompute"` through `precompute_descriptor()`
  - it does **not** register a `precompute-propagate` hot descriptor
- `src/passes/optimize.mbt:250-269`
  - the modeled `optimize` / `shrink` preset entries replay plain `"precompute"` in the PC slots
  - they do not schedule `"precompute-propagate"`
- `src/passes/optimize.mbt:463-472`
  - removed-name and boundary-only requests fail before dispatch
  - an explicit `--pass precompute-propagate` request therefore reports removal rather than reaching `hot_pass_run(...)`

This is the strongest local status fact: the sibling name exists, but only in the removed-name table.

### 2. Active plain-`precompute` landing zone

The active local implementation is [`src/passes/precompute.mbt`](../../../../../src/passes/precompute.mbt).

Useful read-along line ranges:

- `src/passes/precompute.mbt:2-16`
  - `precompute_descriptor()` declares only the active pass name `"precompute"`
  - `precompute_summary()` intentionally describes a narrower scalar top-level slot pass
- `src/passes/precompute.mbt:20-138`
  - `precompute_global_const(...)`, `precompute_i32_exact_const(...)`, and `precompute_i64_exact_const(...)` define the current local constant-source model
- `src/passes/precompute.mbt:138-655`
  - `precompute_try_fold_global_get(...)`, `precompute_try_fold_unary(...)`, and `precompute_try_fold_binary(...)` own the current scalar/global fold surface
- `src/passes/precompute.mbt:656-720`
  - `precompute_try_fold_constant_if(...)` owns current constant-`if` arm picking
- `src/passes/precompute.mbt:722-1063`
  - dead-drop and root/region cleanup helpers preserve current HOT/writeback hygiene
- `src/passes/precompute.mbt:1095-1166`
  - `precompute_run(...)` runs an iterative local HOT fixpoint over the above helpers

Those helpers are real future infrastructure, but they are not enough to call the sibling implemented. They do not model Binaryen's `propagateLocals(...)` get/set worklist.

### 3. Hot-pass dispatch and writeback guard rails

The active dispatcher is [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt).

Important locations:

- `src/passes/pass_manager.mbt:8670-8704`
  - `hot_pass_run(...)` dispatches `"precompute" => precompute_run(ctx, func)`
  - there is no `"precompute-propagate"` arm
- neighboring `run_hot_pipeline_precompute_*` helpers in the same file
  - preserve the artifact-driven writeback safety environment built around plain `precompute`
  - these are lowering / validation guard rails, not evidence of a local-propagation algorithm

That writeback work is important for a future sibling port, but it should not be misread as evidence that the Binaryen `precompute-propagate` algorithm is already present.

### 4. Tests that prove the local status

#### Registry tests

[`src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt) proves the active and unavailable surfaces:

- `src/passes/registry_test.mbt:105-122`
  - `batch 1 descriptors expose the active first hot ports` checks `precompute_descriptor().name == "precompute"`
- `src/passes/registry_test.mbt:146-160`
  - `preset expansion stays on implemented active pass names` checks the current modeled `optimize` / `shrink` expansion uses active names only and includes plain `precompute`
- the same file's removed-name request coverage proves the generic removed-name path rejects unavailable passes

The test currently uses `de-nan` as the explicit removed-name example, not `precompute-propagate`; the registry list in `optimize.mbt` is the exact source for this pass's removed status.

#### Preset-slot tests

[`src/passes/optimize_test.mbt`](../../../../../src/passes/optimize_test.mbt) locks the local scheduler story:

- `src/passes/optimize_test.mbt:290-313` proves `optimize` replays plain `precompute` in both PC slots
- `src/passes/optimize_test.mbt:315-335` proves `shrink` replays plain `precompute` in both PC slots

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
