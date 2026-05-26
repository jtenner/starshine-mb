---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-04-23-simplify-globals-primary-sources.md
  - ../../../raw/research/0275-2026-04-23-simplify-globals-primary-sources-and-starshine-followup.md
  - ../../../raw/binaryen/2026-05-05-simplify-globals-current-main-recheck.md
  - ../../../raw/research/0461-2026-05-05-simplify-globals-current-main-recheck.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../no-dwarf-default-optimize-path.md
  - ../../../../../agent-todo.md
  - ../simplify-globals-optimizing/index.md
  - ../propagate-globals-globally/index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./plain-vs-optimizing-and-safety.md
  - ./wat-shapes.md
  - ./starshine-port-readiness-and-validation.md
  - ../simplify-globals-optimizing/index.md
  - ../propagate-globals-globally/index.md
---

# Starshine Strategy For `simplify-globals`

Use this page together with the raw primary-source manifest in [`../../../raw/binaryen/2026-04-23-simplify-globals-primary-sources.md`](../../../raw/binaryen/2026-04-23-simplify-globals-primary-sources.md) and the 2026-05-05 current-main bridge in [`../../../raw/binaryen/2026-05-05-simplify-globals-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-simplify-globals-current-main-recheck.md).
The goal here is not to re-explain upstream Binaryen, but to show the exact current Starshine status, the local code and doc surfaces that already track the pass, and the concrete neighboring implementation areas a future port would have to hook into.
The new port-readiness page, [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md), carries the first-slice validation ladder.

## The honest current status

`simplify-globals` is now **active** in Starshine as the plain shared-core sibling of `simplify-globals-optimizing`.
There is still no separate `src/passes/simplify_globals.mbt` owner file; the implementation intentionally lives in `src/passes/simplify_globals_optimizing.mbt` so the plain, optimizing, and startup-only public names share one core with distinct wrappers.

The current local strategy is:

- keep the pass spelling as an active module-pass registry entry
- dispatch explicit requests to the shared SGO core without the optimizing nested cleanup rerun
- keep the shared-engine relation to `simplify-globals-optimizing` and `propagate-globals-globally` explicit
- preserve direct fuzz evidence for the plain sibling before broadening behavior
- keep future sibling-specific gaps evidence-driven rather than implying full Binaryen breadth beyond the accepted shared core

This active status landed in [`0699`](../../../raw/research/0699-2026-05-26-sgo-shared-family-exposure.md).

## Exact local code map today

The fastest read-along path through the current Starshine status is:

- active module-pass status
  - [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
    - `pass_registry_entries()` includes `"simplify-globals"` as a module pass
- active module-pass dispatch
  - [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
    - `run_hot_pipeline_apply_module_pass(...)` routes `"simplify-globals"` to the shared SGO core and returns without nested cleanup
- shared owner
  - [`src/passes/simplify_globals_optimizing.mbt`](../../../../../src/passes/simplify_globals_optimizing.mbt)
    - `sgo_run_core(...)` owns the plain shared-core behavior
- scheduler context for the shared optimizing sibling
  - [`../../no-dwarf-default-optimize-path.md#L35-L41`](../../no-dwarf-default-optimize-path.md#L35-L41)
    - the canonical no-DWARF late path uses `simplify-globals-optimizing`, not plain `simplify-globals`, and the optimizing sibling owns the extra nested default-function rerun
- current backlog reality
  - [`../../../../../agent-todo.md#L535-L547`](../../../../../agent-todo.md#L535-L547)
    - the repo has an `SGO` slice for `simplify-globals-optimizing`, but no separate plain-`simplify-globals` slice today
- neighboring living dossiers a future port must line up with
  - [`../simplify-globals-optimizing/index.md`](../simplify-globals-optimizing/index.md)
  - [`../propagate-globals-globally/index.md`](../propagate-globals-globally/index.md)

That code-and-doc map is the practical addition in this follow-up: readers can now jump directly from the upstream algorithm to the exact local status and future landing zone.

## What Starshine currently does for this pass name

Today Starshine's behavior for `simplify-globals` is deliberately limited.

### 1. The name is active as a module pass

`src/passes/optimize.mbt` keeps `simplify-globals` in `pass_registry_entries()` as a module pass. Explicit requests no longer reject as boundary-only.

### 2. The active pipeline runs the shared core without optimizing cleanup

`src/passes/pass_manager.mbt` dispatches the name to `sgo_run_core(...)` and returns the rewritten module directly. That means plain `simplify-globals` gets the shared global fact collection, startup propagation, code substitutions, dead/same-init write repair, and read-only-to-write behavior from the accepted SGO core, but it does **not** run `simplify-globals-optimizing`'s touched-function nested default cleanup lane.

The focused 0699 tests prove this with a function-body rewrite that still contains cleanup residue (`i32.add`) under the plain pass but is cleaned by the optimizing sibling.

### 3. The current local planning story is intentionally thinner than the optimizing sibling's

The honest status is:

- active module-pass name tracked
- shared-core dispatch tracked
- sibling relation tracked
- direct plain-pass fuzz evidence tracked in `0699`

Future work should still avoid assuming full Binaryen breadth beyond the accepted shared-core behavior.

## The active Starshine implementation shape

The local `simplify-globals` pass is a **boundary/module pass**, not a HOT peephole and not the optimizing scheduler wrapper.

The local strategy is:

1. reuse the whole-module SGO fact summaries;
2. reuse startup folding and offset propagation;
3. reuse runtime cheap-trace substitution in function bodies with conservative barriers;
4. preserve `drop(value)` when erasing dead or same-as-init writes;
5. keep the `read-only-to-write` legality and actual-node matching rules from the shared core; and
6. stop there, without inheriting the optimizing sibling's nested default-function rerun.

## The most important local dependency map

### Plain `simplify-globals` is the shared-engine sibling of `simplify-globals-optimizing`, but the public contract is smaller

See:

- [`../simplify-globals-optimizing/index.md`](../simplify-globals-optimizing/index.md)

Why it matters locally:

- both public passes come from the same upstream `SimplifyGlobals.cpp` engine
- Starshine shares low-level global-analysis and rewrite machinery between the siblings
- the most important semantic difference to preserve is the stop point: plain `simplify-globals` stops after global rewrites and type repair, while `simplify-globals-optimizing` continues into the nested default-function rerun
- future broadening should keep both direct pass fuzz lanes current

### `propagate-globals-globally` is the startup-only sibling, not a random helper

See:

- [`../propagate-globals-globally/index.md`](../propagate-globals-globally/index.md)

Why it matters locally:

- plain `simplify-globals` includes the startup-only propagation surface but also owns more than that
- `propagate-globals-globally` is now the active startup-only decomposition: startup propagation is a real sub-algorithm with a meaningful stop point
- the split keeps the startup-only subset from pretending to cover the full plain pass

### Late-global neighbors define the eventual boundary landing zone

The eventual local pass will need to compose with the same late-global neighborhood already documented elsewhere:

- [`../duplicate-import-elimination/index.md`](../duplicate-import-elimination/index.md)
- [`../remove-unused-module-elements/index.md`](../remove-unused-module-elements/index.md)
- [`../string-gathering/index.md`](../string-gathering/index.md)
- [`../reorder-globals/index.md`](../reorder-globals/index.md)
- [`../directize/index.md`](../directize/index.md)

Why it matters locally:

- this is another reason the port belongs in boundary/module scheduling rather than the HOT-only pipeline
- these passes consume and reshape the same late-boundary surfaces
- validation should eventually check both isolated `--simplify-globals` behavior and its surrounding late-tail neighborhood

## What Starshine does **not** have yet

A future contributor should be careful not to overread the current local surface.
Starshine does **not** currently have:

- a separate MoonBit owner file for `simplify-globals`;
- a claim that plain `simplify-globals` covers more than the accepted shared SGO core;
- self-optimize artifact evidence specific to the plain sibling; or
- a reason to add the plain sibling to `optimize` / `shrink` presets.

So the current repo status is best summarized as:

- active shared-core module pass;
- no optimizing nested cleanup;
- focused sibling-boundary tests; and
- direct 10k fuzz with zero mismatches under the configured command-failure stop.

## Validation plan for future broadening

Keep this validation ladder for future behavior changes:

1. reduced rewrite tests for any newly broadened plain-pass family;
2. sibling-boundary tests proving plain `simplify-globals` still stops without the optimizing nested default-function rerun;
3. direct `--simplify-globals` fuzz against Binaryen; and
4. late-neighborhood checks only if the public scheduler changes.

## Bottom line

Current Starshine `simplify-globals` strategy is active shared-core module-pass exposure:

- preserve the active registry classification;
- keep the shared-engine split from `simplify-globals-optimizing` and `propagate-globals-globally` explicit;
- keep direct plain-pass fuzz evidence current for behavior changes; and
- do not add optimizing cleanup or public preset scheduling by accident.

That is the clearest source-backed local story the repo can truthfully teach today.
