---
kind: concept
status: supported
last_reviewed: 2026-07-18
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

The parameterized HOT locals-family mode is now landed. Remaining work must preserve these source-backed semantics:

1. keep the pass function-local / HOT-level
   - this is not a whole-module declaration pass
2. reuse as much active full-`simplify-locals` machinery as possible
   - sinkable tracking
   - effect invalidation
   - branch-exit and structured-result handling
   - equivalent-copy cleanup
   - final dead-set cleanup
3. add one explicit no-tee policy boundary
   - direct single-use sinking remains legal
   - structure formation remains legal
   - existing tees may still be analyzed as ordinary input syntax
   - new `local.tee` materialization for multi-use sinking must be disabled
4. keep descriptor and dispatcher naming honest
   - decide whether canonical Starshine pass spelling is upstream `simplify-locals-notee`, local `simplify-locals-no-tee`, or both
   - wire the chosen name through `src/passes/optimize.mbt`, `src/passes/pass_manager.mbt`, and CLI help only when the behavior really exists
5. add sibling-specific tests
   - a positive single-use sink
   - a positive structured `if` / block result rewrite
   - a negative multi-use case that full `simplify-locals` might solve with a tee but no-tee mode must preserve
   - an effect/EH barrier inherited from the full family

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
