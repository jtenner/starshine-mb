---
kind: concept
status: supported
last_reviewed: 2026-05-04
sources:
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

- `.tmp/pass-fuzz-slns-genvalid-10000-after-raw`: `10000/10000` gen-valid comparisons, `0` mismatches, `0` command failures.
- `.tmp/pass-fuzz-slns-10000-keepgoing-after-raw`: `9975/10000` mixed-generator comparable cases, `9975` matches, `0` mismatches; the `25` command failures are Binaryen-side parser/canonicalization families.
- `.tmp/self-opt-slns-direct-rerun`: debug-artifact direct compare is normalized-WAT and canonical-function equal; Starshine pass time `325.166ms` vs Binaryen pass time `509466.000ms` in that run.

Preset placement remains conservative: the direct pass is runnable and oracle-checked, but the public `optimize` / `shrink` presets still avoid claiming the full ordered local-neighborhood slot until neighboring ordered replay is refreshed.

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
- direct regression proving the slot gate sees the pass while presets remain conservative
  - `src/passes/optimize_test.mbt`
    - `test "tuple-optimization exact preset prereqs see no-structure pass but presets stay conservative"`
- backlog and delivery plan
  - `agent-todo.md`
    - `#### SLNS - Simplify Locals No-Structure`
    - `[SLNS]001 - Early Local Simplification Core`
    - `[SLNS]002 - Early-Slot Regression and Artifact Proof`
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

### 3. The work is planned as a parity slice, not an orphan idea

`agent-todo.md` already gives the pass a real backlog slice under `SLNS`.
The current deliverables point in the right direction:

- simplify sets, gets, and dead locals without creating new structured returns
- preserve later coalescing opportunities
- add regressions for tee-like traffic and tuple scratch locals
- replay parity on the debug artifact in the intended early slot

That is a useful local framing because it matches the reviewed upstream contract much better than a vague “port simplify-locals earlier” description.

### 4. The scheduler slot is already documented

`docs/wiki/binaryen/no-dwarf-default-optimize-path.md` already places the pass in the canonical no-DWARF function pipeline:

- `tuple-optimization -> simplify-locals-nostructure -> vacuum -> reorder-locals`

That matters because the pass is not meant to run in isolation.
Upstream Binaryen expects:

- tuple cleanup to expose early local carriers first
- no-structure local sinking to trim those carriers without inventing new block / `if` / loop results
- `vacuum` to remove the leftover garbage
- `reorder-locals` to benefit from the cleaner early local set

That cluster story remains the preset-scheduling strategy: the direct pass is implemented, but broader ordered-neighborhood replay must still prove the exact public preset slot.

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

Direct execution is done; preset integration is still intentionally conservative.

Before adding this pass to public `optimize` / `shrink` ordering, refresh the ordered neighborhood evidence around:

- `tuple-optimization -> simplify-locals-nostructure`
- `simplify-locals-nostructure -> vacuum`
- `vacuum -> reorder-locals`
- later `coalesce-locals` / `local-cse` once those passes land

That is why the tracker now treats the pass as implemented while still recording preset placement as follow-up.

## Bottom line

Current Starshine `simplify-locals-nostructure` status:

- active hot pass under upstream spelling `simplify-locals-nostructure`
- active compatibility alias `simplify-locals-no-structure`
- implemented in `src/passes/simplify_locals.mbt`
- dispatcher and harness wiring complete
- focused no-structure tests complete
- direct 10k gen-valid, mixed-generator comparable, and debug-artifact self-opt oracle evidence recorded
- public preset scheduling still deferred until ordered-neighborhood replay is proven
