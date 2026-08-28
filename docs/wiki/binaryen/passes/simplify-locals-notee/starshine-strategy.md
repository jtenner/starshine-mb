---
kind: concept
status: supported
last_reviewed: 2026-08-28
sources:
  - ../simplify-locals/index.md
  - ./index.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/cmd/cmd.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/simplify_locals.mbt
  - ../../../../../src/passes/simplify_locals_test.mbt
  - ../../../../../src/passes/simplify_locals_wbtest.mbt
  - ../../../../../src/passes/pass_manager_wbtest.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./variant-boundaries-and-registry-aliases.md
  - ./wat-shapes.md
  - ../simplify-locals/index.md
  - ../simplify-locals-nostructure/index.md
  - ../simplify-locals-notee-nostructure/index.md
  - ../untee/index.md
---

# Starshine Strategy For `simplify-locals-notee`

> **Binaryen-v131 renewal (2026-07-27):** The released owner contract is unchanged from v130. Current executable evidence is recorded in [`index.md`](./index.md) and the family [fuzzing closeout](../simplify-locals/fuzzing.md); older v129/v130 labels below are retained only as historical provenance, not as the current oracle.


Use this page together with the retained 2026-04-24 research inventory and direct tagged source URLs.
The goal here is not to re-explain upstream Binaryen, but to show the exact current Starshine status, naming policy, shared implementation surface, and remaining closeout work for the no-tee locals-family sibling.

## Honest current status

`simplify-locals-notee` is now implemented as an active Starshine hot pass in the shared `src/passes/simplify_locals.mbt` owner.

| Surface | Name | Current Starshine status |
| --- | --- | --- |
| Binaryen public pass | `simplify-locals-notee` | active canonical hot pass |
| Starshine compatibility spelling | `simplify-locals-no-tee` | active alias of the canonical policy |

The implementation uses one explicit policy object. For this sibling it sets structure on, sink-created tees off, and ordinary nesting on. Existing input tees may still be analyzed and cleaned; the disabled behavior is specifically multi-use sinking by creating a fresh tee.

## Exact local code map today

The fastest read-along path through the current Starshine state is:

- registry and active-request behavior
  - `src/passes/optimize.mbt`
    - both `simplify-locals-notee` and `simplify-locals-no-tee` are active hot entries
    - the alias has been removed from `pass_registry_removed_names()`
    - both descriptors use the same summary and policy implementation
- CLI parse behavior
  - `src/cmd/cmd.mbt`
    - pass-flag parsing accepts active `HotPass` registry entries
    - both the canonical spelling and compatibility alias are therefore executable and visible through the shared registry-backed CLI surface
- shared implementation surface
  - `src/passes/simplify_locals.mbt`
    - `simplify_locals_notee_descriptor()` publishes the canonical pass
    - `SimplifyLocalsPolicy` records structure, sink-tee, and nesting permissions
    - `simplify_locals_notee_run(...)` reuses sinkables, effect conflicts, branch exits, structure lifting, equivalent copies, and final cleanup with sink tees disabled
- active dispatcher and writeback surface
  - `src/passes/pass_manager.mbt`
    - both names dispatch to `simplify_locals_notee_run(...)`
    - shared family classification gives both names the SimplifyLocals lower options, verification, and exact writeback cleanup
    - the no-tee sibling deliberately avoids tee-capable raw fast-path admission until those exact rewrites are policy-aware
- tests and replay surfaces
  - `src/passes/registry_test.mbt`
    - proves both canonical and compatibility no-tee names are active hot passes and checks the canonical descriptor
  - `src/passes/optimize_test.mbt`
    - proves default presets run the active full `simplify-locals`, not the no-tee sibling
  - `src/passes/simplify_locals_test.mbt` and `src/passes/simplify_locals_wbtest.mbt`
    - cover the active full pass and many local traffic shapes, but not a sibling-specific “no newly introduced tee” policy
  - `src/passes/pass_manager_wbtest.mbt`
    - contains raw/writeback lanes and artifact-shaped full-pass coverage keyed to `simplify-locals`
- planning surfaces
  - `agent-todo.md`
    - `[SL-FAMILY]001` tracks full family implementation, dedicated generation, parity, timing, and closeout
  - `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
    - canonical no-DWARF default path uses `simplify-locals-nostructure` early and full `simplify-locals` later, not this sibling

## August 28, 2026 performance architecture

The artifact-scale pathology was in safety proof work, not profitable sinking:

- `simplify_locals_should_skip_large_local_tee_memory_write_hazard(...)` found a tee and then recursively rebuilt complete descendant effect summaries at every shared-DAG parent;
- one unchanged function consumed about 10.067 seconds in that guard while all timed rewrite phases together were below one second;
- `simplify_locals_large_local_tee_memory_write_hazard_scan(...)` now preserves the same local-count/tee/write condition while visiting each reachable node once;
- `simplify_locals_effects_mask_for_subtree_scan(...)` computes the pass's conservative exact effect mask with one visited set rather than recursively allocating a fresh whole-function summary per descendant;
- the dispatcher returns exact large tee/store no-ops before lift only at the canonical SLNT raw fallback, after all earlier exact raw rewrites have run. Moving this bailout before those rewrites was rejected because it changed the canonical artifact from 4,893,604 to 4,899,775 bytes.

White-box tests lock one visit per shared-DAG node for both proofs, and the dispatcher test requires `skip-raw reason=large-local-tee-memory-write-hazard-noop`. Final pass-local timing is `1.152x` Binaryen v131 with exact production output. The remaining `2.321x` command ratio is shared lowering/function-envelope/validation/encoding work, not a pass-body pathology.

## Current implementation boundaries

### 1. Both spellings are active

The upstream spelling is canonical and the older descriptive spelling is a tested alias. No preset currently schedules this sibling.

### 2. No-tee is a sink policy, not a ban on all tees

The pass refuses fresh tees for multi-use sinking. Structure synthesis remains enabled and may use value-carrying branch machinery required by the structured result transform.

### 3. Full `simplify-locals` remains a distinct broader pass

The active full pass is the closest local implementation surface, but it is not equivalent because it may perform tee-enabled rewrite families that upstream `simplify-locals-notee` intentionally disables.

The future local distinction is not whether Starshine can simplify locals at all.
It is whether Starshine can run the same family with a policy that refuses fresh tee creation while still preserving structure formation and late cleanup.

## Remaining closeout work

The pass-local performance blocker is closed near parity. Remaining work is deliberately narrower:

1. reduce the shared command envelope without changing SLNT output;
2. keep the exact no-new-tee, structure-enabled policy and all lifetime/EH barriers;
3. keep the 193 pre-existing random-profile canonical-larger cases visible as parity evidence until their owner families are classified or aligned;
4. preserve both canonical and compatibility spellings and their shared descriptor/dispatcher behavior.

## Do not confuse with neighboring passes

### Full `simplify-locals`

Full `simplify-locals` is active and broader.
It may introduce tees; the no-tee sibling may not.

### `simplify-locals-nostructure`

The no-structure sibling disables structured result formation but can still allow tee-enabled sinking.
This is the opposite axis from no-tee.

### `simplify-locals-notee-nostructure`

The no-tee/no-structure sibling disables both surfaces.
It is stricter than this pass.

### `untee`

`untee` desugars existing tees into set/get shapes.
It is not a general local-sinking pass and should not be treated as an implementation substitute for `simplify-locals-notee`.

## Current docs action

This follow-up intentionally keeps the pass as a docs/planning bridge, not as an implementation claim:

- the raw primary-source manifest closes the provenance gap
- this page closes the Starshine status gap
- the implementation/test-map page makes the upstream proof surfaces explicit
- the index/tracker/log updates should prevent future threads from rediscovering the old “working dossier with direct URLs only” gap as still open
