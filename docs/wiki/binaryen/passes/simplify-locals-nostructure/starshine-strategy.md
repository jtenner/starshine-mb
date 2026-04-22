---
kind: concept
status: supported
last_reviewed: 2026-04-22
sources:
  - ../../../raw/binaryen/2026-04-22-simplify-locals-nostructure-primary-sources.md
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
  - ./variant-surface.md
  - ./wat-shapes.md
  - ../tuple-optimization/index.md
  - ../simplify-locals/index.md
  - ../reorder-locals/index.md
  - ../coalesce-locals/index.md
---

# Starshine Strategy For `simplify-locals-nostructure`

Use this page together with the raw primary-source manifest in [`../../../raw/binaryen/2026-04-22-simplify-locals-nostructure-primary-sources.md`](../../../raw/binaryen/2026-04-22-simplify-locals-nostructure-primary-sources.md).
The goal here is not to re-explain upstream Binaryen, but to show the exact current Starshine status, the local code and doc surfaces that already track the pass, and the concrete neighboring implementation areas a future port would have to hook into.

## The honest current status

`simplify-locals-nostructure` is still **unimplemented** in Starshine.
There is no `src/passes/simplify_locals_nostructure.mbt` owner file today.

That does **not** mean there is no Starshine strategy surface.
The current local strategy is registry, slot-blocker, and port planning:

- keep the local removed-name spelling tracked in the registry surface
- keep the tuple exact-slot blocker explicit in code and tests
- keep the canonical no-DWARF slot documented
- keep the backlog slice focused on early local cleanup without structural return rewrites
- teach the surrounding local cleanup files a future port would need to compose with

So this page is intentionally a **status-and-port-map** page rather than a fake implementation page.

## Exact local code map today

The fastest read-along path through the current Starshine status is:

- tracked but removed pass-name status and exact-slot blocker helper
  - `src/passes/optimize.mbt`
    - `pass_registry_removed_names()` includes `"simplify-locals-no-structure"`
    - `tuple_optimization_exact_slot_prereqs_ready()` stays false until both `code-pushing` and `simplify-locals-no-structure` stop being removed placeholders
- direct regression proving the slot is still blocked
  - `src/passes/optimize_test.mbt`
    - `test "tuple-optimization exact preset slot remains unavailable while its neighbors are removed"`
- backlog and delivery plan
  - `agent-todo.md`
    - `#### SLNS - Simplify Locals No-Structure`
    - `[SLNS]001 - Early Local Simplification Core`
    - `[SLNS]002 - Early-Slot Regression and Artifact Proof`
- canonical scheduler context
  - `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
    - the early local-cleanup slot where `simplify-locals-nostructure` belongs after `tuple-optimization` and before `vacuum -> reorder-locals`
- exact neighboring implementation files already worth reading
  - `src/passes/simplify_locals.mbt`
    - `simplify_locals_descriptor()`
    - `simplify_locals_new_sinkables(...)`
    - `simplify_locals_sinkables_may_conflict(...)`
  - `src/passes/reorder_locals.mbt`
    - `rl_scan_instruction(...)`
    - `rl_rewrite_instrs_in_place(...)`
    - `reorder_locals_run_module_pass(...)`
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

That code-and-doc map is the main practical addition in this follow-up: readers can now jump directly from the upstream algorithm to the exact local status and the future landing zone.

## What Starshine currently does for this pass name

Today Starshine's behavior for `simplify-locals-nostructure` is deliberately limited.

### 1. The name is tracked, not forgotten

`src/passes/optimize.mbt` keeps the local spelling `simplify-locals-no-structure` in `pass_registry_removed_names()`.
That means:

- the project still treats the upstream pass as a real known missing pass
- the local compatibility spelling is preserved in the registry surface
- the pass remains visible in tracker and backlog work instead of silently falling out of planning

That is the right current behavior for an unimplemented parity pass.

### 2. The pass already blocks one honest tuple slot

The most concrete current Starshine strategy fact lives in `tuple_optimization_exact_slot_prereqs_ready()`.
That helper requires both:

- `code-pushing`
- `simplify-locals-no-structure`

to become active before Starshine will claim the exact Binaryen tuple slot publicly.

`src/passes/optimize_test.mbt` then locks that honesty rule in place with:

- `test "tuple-optimization exact preset slot remains unavailable while its neighbors are removed"`

So the repo already treats `simplify-locals-nostructure` as a real scheduling blocker, not just as a name on a wish list.

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

That cluster story is part of the local strategy even before a MoonBit implementation exists.

## The right future Starshine implementation shape

The current docs and neighboring code strongly suggest that a future local `simplify-locals-nostructure` port should be taught as an **early HOT local-traffic cleanup pass without structure synthesis**, not as a renamed copy of full `simplify-locals`.

Why:

- Binaryen runs it in an earlier slot than full `simplify-locals`
- the exact upstream contract is still tee-enabled and nesting-enabled, but structure-disabled
- Starshine already has nearby sinkability and conflict machinery in `simplify_locals.mbt`
- Starshine already has a later local-index rewrite neighbor in `reorder_locals.mbt`
- the explicit tuple-slot gate proves the pass matters to honest scheduler placement today

So the local strategy should be thought of as:

1. identify a HOT-level representation of the real upstream families
   - single-use sinks into existing consumers
   - later tee creation for multi-use locals
   - overwrite cleanup and dead-local cleanup
   - no block / `if` / loop return synthesis
2. preserve the same correctness boundaries locally
   - first-cycle single-use-only rule
   - later tee-enabled sinking
   - directional effect invalidation
   - explicit `try` / `try_table` throwing-value barriers
   - late equivalent-get cleanup
3. keep the scheduler story honest
   - land the real pass after `tuple-optimization`
   - keep it before `vacuum -> reorder-locals`
   - do not claim the public tuple slot until both missing neighbors really exist
4. preserve the handoff to later cleanup neighbors
   - let `vacuum`, `reorder-locals`, and later `coalesce-locals` / full `simplify-locals` consume the earlier cleanup work instead of trying to subsume them all here

In other words, the future port should slot into a local cleanup ecosystem that partly exists already.

## The most important local dependency map

### Upstream `simplify-locals-nostructure` is the missing right neighbor for `tuple-optimization`

See [`../tuple-optimization/index.md`](../tuple-optimization/index.md).

Why it matters locally:

- the current tuple-slot gate in `src/passes/optimize.mbt` already treats `simplify-locals-no-structure` as the missing right neighbor
- a future Starshine port should therefore validate not only the pass in isolation, but also the real `tuple-optimization -> simplify-locals-nostructure` neighborhood
- that is the most concrete current reason this pass matters even before it has an owner file

### Existing Starshine `simplify-locals` code is the nearest landed local reasoning surface

See [`../simplify-locals/index.md`](../simplify-locals/index.md), `src/passes/simplify_locals.mbt`, and `src/passes/pass_manager_wbtest.mbt`.

Why:

- `simplify_locals_new_sinkables(...)` already models local sink candidates in HOT form
- `simplify_locals_sinkables_may_conflict(...)` already expresses a local conflict story that future early no-structure work will need to preserve in narrower form
- the current raw simplify-locals tests already exercise local traffic, overwrite barriers, and condition-boundary cases that are close to the kinds of safety questions a future early port will face

So the current local implementation map for `simplify-locals-nostructure` begins here, even before a dedicated owner file exists.

### Existing Starshine `reorder-locals` code is the nearest landed local-index rewrite surface

See [`../reorder-locals/index.md`](../reorder-locals/index.md) and `src/passes/reorder_locals.mbt`.

Why:

- an eventual `simplify-locals-nostructure` port will reduce and reshape local traffic before the first reorder pass
- Starshine already has a module pass that scans local users and rewrites local indices in one canonical place
- `rl_scan_instruction(...)`, `rl_rewrite_instrs_in_place(...)`, and `reorder_locals_run_module_pass(...)` give future contributors an in-repo model for local-index rewrites and local metadata stability work

That does not make `reorder-locals` an implementation of this pass, but it does make it an important local read-along file.

### Later local cleanup still matters

See [`../coalesce-locals/index.md`](../coalesce-locals/index.md).

Why:

- Binaryen uses this pass early, before later local-slot compaction and later full local cleanup
- future Starshine work should therefore avoid broadening `simplify-locals-nostructure` until it silently subsumes later cleanup families
- the pass should leave later local-slot and full-structure cleanup opportunities intact, just like the backlog wording already says

## What Starshine does **not** have yet

A future contributor should be careful not to overread the current local surface.
Starshine does **not** currently have:

- a MoonBit implementation file for `simplify-locals-nostructure`
- pass-specific candidate collection for the early no-structure variant
- pass-specific tee/no-structure regression tests
- pass-specific CLI execution coverage beyond the tracked registry, tuple-slot gate, backlog, and neighboring simplify-locals replay surfaces

So the current repo status is best summarized as:

- name tracked
- slot blocker tracked
- backlog tracked
- scheduler slot documented
- neighboring local cleanup and rewrite files implemented
- transform itself not yet landed

## Validation plan for the eventual port

The existing backlog plus neighboring pass docs imply the right validation ladder.
A future real implementation should validate in this order:

1. reduced shape tests for the real upstream families
   - single-use sinks into existing consumers
   - later tee positives for multi-use locals
   - overwrite cleanup and dead-local cleanup
   - preserved block / `if` / loop result structure
2. negative correctness tests
   - effect barriers
   - `try` / `try_table` throwing-value barriers
   - no accidental block / `if` / loop result synthesis
   - tuple scratch-local cases that still need no-structure cleanup without broadening into full `simplify-locals`
3. cluster interaction tests
   - `tuple-optimization -> simplify-locals-nostructure`
   - `simplify-locals-nostructure -> vacuum`
   - `vacuum -> reorder-locals`
4. artifact and oracle comparison
   - the `SLNS` slice in `agent-todo.md`
   - the canonical no-DWARF debug-artifact replay path once the exact slot becomes locally representable

That is more useful locally than a generic “compare with Binaryen later” note because it points directly at the in-repo workflow and the exact neighboring code surfaces.

## Bottom line

Current Starshine `simplify-locals-nostructure` strategy is honest registry and slot-blocker planning:

- the pass is intentionally preserved in `src/passes/optimize.mbt` under the local removed-name spelling `simplify-locals-no-structure`
- the tuple-slot gate and optimize-test regression already treat it as a real missing prerequisite for honest preset placement
- the backlog already treats it as a real early local-cleanup parity slice under `SLNS`
- the canonical slot is already documented in the no-DWARF optimizer notes
- the surrounding `simplify-locals`, `reorder-locals`, and `coalesce-locals` dossiers plus the current MoonBit files already define the practical landing zone for a future port

So the right mental model today is not “nothing exists locally.”
It is:

- **no transform yet**
- **clear tracked status**
- **clear slot-blocker role for tuple parity**
- **clear slot in the early cleanup cluster**
- **clear neighboring implementation map for the eventual port**
