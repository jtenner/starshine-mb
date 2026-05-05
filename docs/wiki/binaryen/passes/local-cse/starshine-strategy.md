---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-local-cse-current-main-recheck.md
  - ../../../raw/research/0453-2026-05-05-local-cse-current-main-recheck.md
  - ../../../raw/research/0464-2026-05-05-local-cse-port-readiness-and-validation.md
  - ../../../raw/binaryen/2026-04-25-local-cse-current-main-code-map.md
  - ../../../raw/binaryen/2026-04-22-local-cse-primary-sources.md
  - ../../../raw/research/0262-2026-04-22-local-cse-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0358-2026-04-25-local-cse-current-main-and-test-map.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../../../../../src/passes/simplify_locals.mbt
  - ../../../../../src/passes/reorder_locals.mbt
  - ../../../../../src/passes/pass_manager_wbtest.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../flatten/index.md
  - ../simplify-locals-notee-nostructure/index.md
  - ../coalesce-locals/index.md
  - ../simplify-locals/index.md
  - ../reorder-locals/index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./basic-block-windows-and-barriers.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-port-readiness-and-validation.md
  - ../flatten/index.md
  - ../simplify-locals-notee-nostructure/index.md
  - ../coalesce-locals/index.md
  - ../simplify-locals/index.md
  - ../reorder-locals/index.md
---

# Starshine Strategy For `local-cse`

Use this page together with the tagged raw primary-source manifest in [`../../../raw/binaryen/2026-04-22-local-cse-primary-sources.md`](../../../raw/binaryen/2026-04-22-local-cse-primary-sources.md), the 2026-05-05 current-main recheck in [`../../../raw/binaryen/2026-05-05-local-cse-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-local-cse-current-main-recheck.md), the source/test map in [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md), and the implementation-readiness bridge in [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).
The goal here is not to re-explain upstream Binaryen, but to show the exact current Starshine status, the local code and doc surfaces that track the pass, and the concrete neighboring implementation areas future preset-slot work will need.

## The honest current status

`local-cse` is now implemented in Starshine with a dedicated owner file, tests, registry entry, dispatcher route, fuzz-harness support, and direct debug-artifact self-optimize evidence.

The active local strategy is still deliberately slot-honest:

- keep the upstream pass spelling active in the registry surface
- keep public `optimize` / `shrink` placement gated until the surrounding missing Binaryen-neighbor slots are representable
- grow the implementation from same-window temp-localizing reuse without recasting it as a whole-function GVN pass
- keep direct `--local-cse` parity evidence separate from later ordered-neighborhood proof

## Exact local code map today

The fastest read-along path through the current Starshine status is:

- active pass implementation and tests
  - `src/passes/local_cse.mbt`
  - `src/passes/local_cse_test.mbt`
- active registry and dispatcher surface
  - `src/passes/optimize.mbt`
    - `local-cse` is registered as an active module pass
  - `src/passes/pass_manager.mbt`
    - routes `local-cse` through `local_cse_run_module_pass(...)`
  - `src/passes/optimize_test.mbt`
    - keeps the aggressive `flatten -> simplify-locals-notee-nostructure -> local-cse` neighborhood gate false while `flatten` remains unavailable
- completed backlog and release note
  - `agent-todo.md`
    - the LCSE implementation slice has been pruned
  - `CHANGELOG.md`
    - records the 2026-05-05 `local-cse` landing
- canonical scheduler context
  - `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
    - the late-cluster slot where `local-cse` belongs after `coalesce-locals` and before full `simplify-locals`
- exact neighboring local implementation files already worth reading
  - `src/passes/simplify_locals.mbt:70`, `src/passes/simplify_locals.mbt:176`, `src/passes/simplify_locals.mbt:4132`
    - sinkable-local state, sinkable/effect conflict checks, and the active full `simplify-locals` entry point
  - `src/passes/reorder_locals.mbt:118`, `src/passes/reorder_locals.mbt:183`, `src/passes/reorder_locals.mbt:544`
    - local-use scanning, in-place local-index rewriting, and module-pass entry logic
- exact current regression and replay surfaces worth following
  - `src/passes/optimize_test.mbt`
    - proves the `flatten -> simplify-locals-notee-nostructure -> local-cse` neighborhood gate stays false while `flatten` remains removed
  - `src/passes/pass_manager_wbtest.mbt`
    - `test "raw simplify-locals adjacent local tees preserve writes read inside later if bodies"`
    - `test "raw simplify-locals rewrites dupable copies into the next escaping if condition"`
    - `test "raw simplify-locals pure suffix collapses terminal dupable local wrappers across safe middle statements"`
  - `src/cmd/cmd_wbtest.mbt`
    - `test "run_cmd_with_adapter print-func sees simplify-locals remove debug artifact Func 71 const fanout webs"`
    - the `--dead-code-elimination --vacuum --optimize-instructions --simplify-locals` artifact replay lane
- exact neighboring living dossiers that define the future slot and local landing zone
  - [`../flatten/index.md`](../flatten/index.md)
  - [`../simplify-locals-notee-nostructure/index.md`](../simplify-locals-notee-nostructure/index.md)
  - [`../coalesce-locals/index.md`](../coalesce-locals/index.md)
  - [`../simplify-locals/index.md`](../simplify-locals/index.md)
  - [`../reorder-locals/index.md`](../reorder-locals/index.md)

That code-and-doc map is the main practical addition in this dossier: readers can now jump directly from the upstream algorithm to the exact local status, proof-surface map, and future landing zone.

## What Starshine currently does for this pass name

Today Starshine's behavior for `local-cse` is active but deliberately scoped.

### 1. The name is active, not merely tracked

`src/passes/optimize.mbt` registers the upstream spelling `local-cse` as an active module pass, and `src/passes/pass_manager.mbt` dispatches it through `local_cse_run_module_pass(...)`.
That means:

- direct `--local-cse` requests execute instead of rejecting as removed
- the pass remains separate from public presets until neighbor-slot proof is ready
- the completed LCSE backlog slice has moved to `CHANGELOG.md`

### 2. The landed work is a direct parity slice

The implementation covers same-window temp-localizing reuse for repeated local arithmetic trees, preserves barrier resets for local writes/calls in the raw path, and is protected by direct pass tests plus fuzz/self-optimize evidence.
The docs should keep that slice connected to the exact Binaryen contract:

- repeated **whole-tree** reuse, not arbitrary subtree extraction
- limited linear windows, not whole-function GVN
- temp-local materialization, not silent value merging
- explicit slot dependence on neighboring passes

### 3. The scheduler slot is already documented, and the missing neighbors matter

`docs/wiki/binaryen/no-dwarf-default-optimize-path.md` already places `local-cse` in the ordinary late local-cleanup cluster.
The upstream source also places it in the aggressive `flatten -> simplify-locals-notee-nostructure -> local-cse` prelude.

That matters because `local-cse` is not meant to run in isolation.
Upstream Binaryen expects other passes to expose the right shapes first:

- `flatten` turns nested near-miss trees into local-fed whole-tree candidates
- `simplify-locals-notee-nostructure` removes some flatten-introduced noise before the early aggressive `local-cse` run
- `coalesce-locals` simplifies later local traffic before the ordinary late run
- full `simplify-locals` cleans up the temp-local traffic `local-cse` leaves behind

Current Starshine already has the late consumer (`simplify-locals`) and a local-index rewrite neighbor (`reorder-locals`), but it does **not** yet have the missing early and late prerequisite neighbors.
That is why current preset placement should stay honest.

## The right future Starshine implementation shape

The current implementation should continue to be taught as a **late local-tree reuse pass with temp locals**, not as an isolated generic optimizer.

Why:

- Binaryen runs it in deliberate neighbor clusters, not alone
- the upstream pass is centered on whole-tree equality plus small linear windows
- Starshine already has nearby local-traffic and effect-conflict machinery in `simplify-locals`
- Starshine already has a module-side local-index rewrite pass in `reorder-locals`
- the missing early and late neighbors explain why exact slot parity remains blocked today

So the local strategy should be thought of as:

1. identify a HOT-level representation of the real upstream families
   - repeated arithmetic and load trees
   - local-fed whole-tree repeats after cleanup
   - controlled temp-local insertion points for originals and repeats
2. preserve the same conservative boundaries locally
   - whole-tree-only matching
   - first-occurrence originals
   - parent-over-child request cancellation
   - linear-window resets around non-linear control
   - effect and generativity invalidation
   - profitability thresholds
3. compose it with the surrounding local cleanup ecosystem
   - early `flatten -> simplify-locals-notee-nostructure -> local-cse` once those neighbors exist
   - ordinary `coalesce-locals -> local-cse -> simplify-locals`
   - local-index and CLI proof surfaces already maintained in-tree

In other words, the direct pass should keep growing inside a cleanup ecosystem that partly exists already.

## The most important local dependency map

### Upstream `local-cse` depends on early shape exposure

See [`../flatten/index.md`](../flatten/index.md) and [`../simplify-locals-notee-nostructure/index.md`](../simplify-locals-notee-nostructure/index.md).

Why it matters locally:

- Binaryen's aggressive slot is not just `flatten -> local-cse`
- the small `simplify-locals-notee-nostructure` cleanup in between is part of the real contract because flatten introduces local traffic that would otherwise obscure repeated whole trees

A future Starshine port should preserve that lesson instead of treating flatten as optional decoration.

### The ordinary late run depends on prior local-slot cleanup

See [`../coalesce-locals/index.md`](../coalesce-locals/index.md).

Why:

- Binaryen runs `local-cse` after `coalesce-locals`
- simpler local-slot usage can make repeated local-fed trees easier to recognize and cheaper to materialize

So a future Starshine implementation should treat `coalesce-locals` as a real feeder, not an unrelated neighbor.

### Existing Starshine `simplify-locals` code is the nearest landed local reasoning surface

See [`../simplify-locals/index.md`](../simplify-locals/index.md), `src/passes/simplify_locals.mbt`, and `src/passes/pass_manager_wbtest.mbt`.

Why:

- `simplify_locals_new_sinkables(...)` and `simplify_locals_sinkables_may_conflict(...)` already encode a real local effect/conflict story in HOT form
- the current raw simplify-locals tests already exercise local traffic, overwrite barriers, and condition-boundary cases that are close to the kinds of safety questions a future `local-cse` port will face
- full `simplify-locals` is also the immediate cleanup consumer after the ordinary late `local-cse` slot

So the current local implementation map for `local-cse` continues to include these neighboring cleanup files alongside the dedicated owner file.

### Existing Starshine `reorder-locals` code is the nearest landed local-index rewrite surface

See [`../reorder-locals/index.md`](../reorder-locals/index.md) and `src/passes/reorder_locals.mbt`.

Why:

- a future `local-cse` port will have to materialize temp locals honestly
- Starshine already has a module pass that scans local users and rewrites local indices in one canonical place
- `rl_scan_instruction(...)`, `rl_rewrite_instrs_in_place(...)`, and `reorder_locals_run_module_pass(...)` give future contributors an in-repo model for local-index rewrites and local metadata stability work

That does not make `reorder-locals` an implementation of `local-cse`, but it does make it an important local read-along file.

## What Starshine does **not** have yet

A future contributor should be careful not to overread the current local surface.
Starshine does **not** currently have:

- a MoonBit implementation file for `local-cse`
- a dispatcher entry for `local-cse` in `src/passes/pass_manager.mbt`
- HOT candidate collection for repeated whole trees
- a local expression hasher/equality engine for this pass
- temp-local insertion and repeat-rewrite machinery specifically for this pass
- pass-specific tests or CLI execution coverage beyond the tracked registry/backlog surfaces and neighboring simplify-locals replay lanes

So the current repo status is best summarized as:

- name tracked
- backlog tracked
- scheduler slot documented
- neighboring local cleanup and rewrite files implemented
- public preset scheduling for the exact upstream neighborhoods

## Validation plan for the eventual port

The existing backlog plus neighboring pass docs imply the right validation ladder.
A future real implementation should validate in this order:

1. reduced shape tests for the real upstream families
   - same-block repeated arithmetic trees
   - repeated load positives
   - before-`if` / `then` positives
   - parent-over-child cancellation cases
2. negative correctness tests
   - after-`if` window resets
   - local-write invalidation
   - nested call and generative GC negative roots
   - tiny-root profitability no-op cases
3. cluster interaction tests
   - `flatten -> simplify-locals-notee-nostructure -> local-cse`
   - `coalesce-locals -> local-cse -> simplify-locals`
   - local-temp introduction plus later local-index stability checks
4. artifact and oracle comparison
   - the `LCSE` slice in `agent-todo.md`
   - the canonical no-DWARF debug-artifact replay path once the exact slot becomes locally representable

That is more useful locally than a generic “compare with Binaryen later” note because it points directly at the in-repo workflow and the exact surrounding code surfaces.

## Bottom line

Current Starshine `local-cse` strategy is honest boundary tracking plus port planning:

- the upstream spelling is intentionally preserved in `src/passes/optimize.mbt`
- the backlog already treats `local-cse` as a real missing parity slice under `LCSE`
- the canonical early and late slots are already documented in the no-DWARF optimizer notes
- the surrounding implementation files already exist and define the practical landing zone for future neighborhood work, especially `simplify_locals.mbt`, `reorder_locals.mbt`, `pass_manager_wbtest.mbt`, and `cmd_wbtest.mbt`
- the docs now keep one important honesty rule explicit: no exact Starshine slot should be claimed before the missing upstream-neighbor equivalents land locally

So the right mental model today is not “nothing exists locally.”
It is:

- **no transform yet**
- **clear tracked status**
- **clear slot in the pipeline**
- **clear neighboring implementation map for the eventual port**
- **clear warning not to over-claim preset parity before the prerequisite neighbors exist**
