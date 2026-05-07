---
kind: concept
status: supported
last_reviewed: 2026-05-08
sources:
  - ../../../raw/research/0552-2026-05-08-simplify-locals-nostructure-ordered-slot-replay.md
  - ../../../raw/research/0543-2026-05-06-slns-direct-revalidation.md
  - ../../../raw/binaryen/2026-05-04-simplify-locals-nostructure-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-25-simplify-locals-nostructure-current-main-and-test-map.md
  - ../../../raw/binaryen/2026-04-22-simplify-locals-nostructure-primary-sources.md
  - ../../../raw/research/0433-2026-05-04-simplify-locals-nostructure-current-main-recheck.md
  - ../../../raw/research/0368-2026-04-25-simplify-locals-nostructure-current-main-and-test-map.md
  - ../../../raw/research/0263-2026-04-22-simplify-locals-nostructure-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../../../../src/passes/simplify_locals.mbt
  - ../../../../../src/passes/reorder_locals.mbt
  - ../../../../../src/passes/pass_manager_wbtest.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tuple-optimization/index.md
  - ../simplify-locals/index.md
  - ../reorder-locals/index.md
  - ../coalesce-locals/index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./starshine-port-readiness-and-validation.md
  - ./variant-surface.md
  - ./wat-shapes.md
  - ../tuple-optimization/index.md
  - ../simplify-locals/index.md
  - ../reorder-locals/index.md
  - ../coalesce-locals/index.md
---

# Starshine Strategy For `simplify-locals-nostructure`

Use this page together with the current source bridge in [`../../../raw/binaryen/2026-05-04-simplify-locals-nostructure-current-main-recheck.md`](../../../raw/binaryen/2026-05-04-simplify-locals-nostructure-current-main-recheck.md), the earlier raw bridge in [`../../../raw/binaryen/2026-04-25-simplify-locals-nostructure-current-main-and-test-map.md`](../../../raw/binaryen/2026-04-25-simplify-locals-nostructure-current-main-and-test-map.md), and the earlier raw primary-source manifest in [`../../../raw/binaryen/2026-04-22-simplify-locals-nostructure-primary-sources.md`](../../../raw/binaryen/2026-04-22-simplify-locals-nostructure-primary-sources.md).
The goal here is not to re-explain upstream Binaryen, but to show the exact current Starshine status, the local code and doc surfaces that already track the pass, and the concrete neighboring implementation areas a future port would have to hook into.

## The honest current status

`simplify-locals-nostructure` is now an active direct hot pass in Starshine.
The implementation lives in `src/passes/simplify_locals.mbt` as a no-structure variant of the landed local-sink/dead-write cleanup core: it runs the main local traffic and dead-cleanup cycles, but deliberately disables block/if/loop structure-result rewrites. The local compatibility spelling `simplify-locals-no-structure` remains accepted as an alias.

Current direct evidence:

- `.tmp/pass-fuzz-simplify-locals-nostructure-20260508`: refreshed 2026-05-08 mixed-generator canonical-spelling run, `6759/10000` comparable cases, `6759` matches, `0` mismatches, `20` Binaryen empty-recursion-group parser/canonicalization command failures.
- `.tmp/pass-fuzz-simplify-locals-no-structure`: refreshed 2026-05-06 mixed-generator alias-spelling run, `6759/10000` comparable cases, `6759` matches, `0` mismatches, `20` Binaryen empty-recursion-group parser/canonicalization command failures.
- `.tmp/pass-fuzz-slns-genvalid-10000-after-raw`: earlier `10000/10000` gen-valid comparisons, `0` mismatches, `0` command failures.
- `.tmp/pass-fuzz-slns-10000-keepgoing-after-raw`: earlier `9975/10000` mixed-generator comparable cases, `9975` matches, `0` mismatches; the `25` command failures are Binaryen-side parser/canonicalization families.
- `.tmp/self-opt-slns-direct-rerun`: debug-artifact direct compare is normalized-WAT and canonical-function equal; Starshine pass time `325.166ms` vs Binaryen pass time `509466.000ms` in that run.
- `.tmp/self-opt-slns-slot-20260508`: exact `tuple-optimization -> simplify-locals-nostructure -> vacuum -> reorder-locals` replay is normalized-WAT and canonical-function equal on the checked-in debug artifact.

Preset placement remains conservative, but the standalone ordered local-neighborhood blocker is now closed: Starshine has exact-slot replay evidence for `tuple-optimization -> simplify-locals-nostructure -> vacuum -> reorder-locals`, while the remaining preset caution belongs to neighboring slices.

See the companion [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md) page for the validation ladder, recommended first slices, and oracle plan.

## Exact local code map today

The fastest read-along path through the current Starshine status is:

- active pass-name status and exact-slot blocker helper
  - `src/passes/optimize.mbt`
    - `pass_registry_entries()` includes active hot entries for `"simplify-locals-nostructure"` and alias `"simplify-locals-no-structure"`
  - `src/passes/optimize.mbt`
    - `tuple_optimization_exact_slot_prereqs_ready()` now sees the no-structure neighbor as active
  - `src/passes/optimize.mbt`
    - optimize/shrink presets deliberately avoid claiming the exact ordered tuple/no-structure slot until the broader neighborhood replay is proven
- direct regressions proving the slot gate sees the pass while presets remain conservative
  - `src/passes/optimize_test.mbt`
    - `test "tuple-optimization exact preset prereqs see no-structure pass but presets stay conservative"`
    - `test "simplify-locals-nostructure exact slot helper exposes the ordered replay lane"`
- exact-slot signoff evidence
  - `docs/wiki/raw/research/0552-2026-05-08-simplify-locals-nostructure-ordered-slot-replay.md`
    - closes the old standalone `SLNS` ordered-slot blocker with current-head direct and artifact replay evidence
- canonical scheduler context
  - `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
    - the early local-cleanup slot where `simplify-locals-nostructure` belongs after `tuple-optimization` and before `vacuum -> reorder-locals`
- exact neighboring implementation files already worth reading
  - `src/passes/pass_manager.mbt`
    - dispatches `simplify-locals-nostructure` / `simplify-locals-no-structure` to the no-structure hot variant and shares the simplify-locals raw artifact gates
  - `src/passes/simplify_locals.mbt`
    - owns both full `simplify-locals` and the no-structure descriptor / alias / runner variants
  - `src/passes/simplify_locals.mbt:70-227`
    - sinkable/effect-conflict data structures a future no-structure port would likely narrow and reuse
  - `src/passes/simplify_locals.mbt:995-1012`, `src/passes/simplify_locals.mbt:2416-2508`, and `src/passes/simplify_locals.mbt:4132-4162`
    - current full-pass conflict invalidation, structured-control boundary handling, and main-cycle setup
  - `src/passes/reorder_locals.mbt`
    - `rl_scan_instruction(...)`, `rl_rewrite_instrs_in_place(...)`, and `reorder_locals_run_module_pass(...)` remain future local-index rewrite context
- exact current regression and replay surfaces worth following
  - `src/passes/pass_manager_wbtest.mbt`
    - `test "raw simplify-locals adjacent local tees preserve writes read inside later if bodies"`
    - `test "raw simplify-locals rewrites dupable copies into the next escaping if condition"`
    - `test "raw simplify-locals pure suffix collapses terminal dupable local wrappers across safe middle statements"`
  - `src/cmd/cmd_wbtest.mbt`
    - `test "run_cmd_with_adapter print-func sees simplify-locals remove debug artifact Func 71 const fanout webs"`
    - the `--dead-code-elimination --vacuum --optimize-instructions --simplify-locals` replay lane
- exact neighboring living dossiers that define the future slot and local landing zone
  - [`../tuple-optimization/index.md`](../tuple-optimization/index.md)
  - [`../simplify-locals/index.md`](../simplify-locals/index.md)
  - [`../reorder-locals/index.md`](../reorder-locals/index.md)
  - [`../coalesce-locals/index.md`](../coalesce-locals/index.md)

That code-and-doc map is refreshed by the direct-pass implementation follow-up: readers can now jump directly from the upstream algorithm to exact local status, dispatcher wiring, and remaining preset-neighborhood work.

## What Starshine currently does for this pass name

Today Starshine's behavior for `simplify-locals-nostructure` is direct and runnable.

### 1. The name is active, with a compatibility alias

`src/passes/optimize.mbt` exposes upstream spelling `simplify-locals-nostructure` as an active hot pass and keeps local spelling `simplify-locals-no-structure` as an active alias.
That means:

- direct CLI and harness requests no longer reject as removed
- the local compatibility spelling is preserved
- both spellings route to the same no-structure implementation

### 2. The pass still guards honest tuple-slot scheduling

The most concrete current Starshine strategy fact lives in `tuple_optimization_exact_slot_prereqs_ready()`.
That helper requires both:

- `code-pushing`
- `simplify-locals-no-structure`

to become active before Starshine will claim the exact Binaryen tuple slot publicly.

`src/passes/optimize_test.mbt` then locks that honesty rule in place with:

- `test "tuple-optimization exact preset prereqs see no-structure pass but presets stay conservative"`

So the repo treats `simplify-locals-nostructure` as implemented for direct execution while still requiring ordered-neighborhood evidence before public preset scheduling.

### 3. The work now has exact-slot signoff, not just a backlog placeholder

The pass no longer depends on a standalone `SLNS` backlog placeholder for its main scheduler claim.
Current in-tree regressions plus the new raw note now prove:

- tuple cleanup can hand values into the no-structure pass in the real slot,
- the no-structure pass still refuses to synthesize structured results there,
- `vacuum` and `reorder-locals` can consume the rewritten output in the same ordered replay,
- and the checked-in debug artifact compares green on normalized WAT plus canonical-function equality for that full neighborhood.

That is a better local framing than a generic “ordered replay still needed” note because it matches the reviewed upstream contract and records that the exact early slot is now proven.

### 4. The scheduler slot is already documented

`docs/wiki/binaryen/no-dwarf-default-optimize-path.md` already places the pass in the canonical no-DWARF function pipeline:

- `tuple-optimization -> simplify-locals-nostructure -> vacuum -> reorder-locals`

That matters because the pass is not meant to run in isolation.
Upstream Binaryen expects:

- tuple cleanup to expose early local carriers first
- no-structure local sinking to trim those carriers without inventing new block / `if` / loop results
- `vacuum` to remove the leftover garbage
- `reorder-locals` to benefit from the cleaner early local set

That cluster story remains the preset-scheduling strategy. The exact `tuple-optimization -> simplify-locals-nostructure -> vacuum -> reorder-locals` suffix is now replay-proven, but broader public preset work still depends on neighboring slices rather than this pass alone.

## Current Starshine implementation shape

The local port is an **early HOT local-traffic cleanup pass without structure synthesis**, not a renamed full `simplify-locals` run.

It reuses the existing `simplify_locals.mbt` machinery for:

- single-use sinks into existing consumers
- later tee creation for multi-use locals
- overwrite cleanup and dead-local cleanup
- directional effect invalidation and local read/write barriers
- raw artifact skip/rewrite gates that avoid paying HOT lift on known no-op or raw-cleanup families

It disables the full-pass structure stage, so it does not synthesize block / `if` / loop result rewrites. Focused tests in `src/passes/simplify_locals_nostructure_test.mbt` cover both the straight-line positive and the “do not create `if I32`” negative.

## Remaining local-neighborhood work

Direct execution is done, and the exact early local neighborhood is now replay-proven.

The remaining preset work is broader than this pass:

- `tuple-optimization` still owns its wider exact-slot and feature-off preset proof
- the earlier `code-pushing -> tuple-optimization` side of the neighborhood still belongs to neighboring slices
- later local-cluster scheduling questions remain with downstream passes, not with a standalone `simplify-locals-nostructure` blocker

That is why the tracker can now treat this pass and its exact early slot as proven while keeping broader preset placement conservative.

## Bottom line

Current Starshine `simplify-locals-nostructure` status:

- active hot pass under upstream spelling `simplify-locals-nostructure`
- active compatibility alias `simplify-locals-no-structure`
- implemented in `src/passes/simplify_locals.mbt`
- dispatcher and harness wiring complete
- focused no-structure tests complete
- refreshed 2026-05-06 direct mixed-generator evidence for both canonical spelling and alias, plus earlier direct 10k gen-valid, mixed-generator comparable, and debug-artifact self-opt oracle evidence recorded
- public preset scheduling still deferred, but no longer because of a standalone `simplify-locals-nostructure` ordered-slot gap
