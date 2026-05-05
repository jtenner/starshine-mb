---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-04-25-coalesce-locals-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-22-coalesce-locals-primary-sources.md
  - ../../../raw/research/0352-2026-04-25-coalesce-locals-current-main-and-test-map.md
  - ../../../raw/research/0264-2026-04-22-coalesce-locals-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0372-2026-04-25-coalesce-locals-port-readiness-health-check.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../../../../src/passes/reorder_locals.mbt
  - ../../../../../src/passes/reorder_locals_test.mbt
  - ../../../../../src/passes/simplify_locals.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../local-subtyping/index.md
  - ../local-cse/index.md
  - ../reorder-locals/index.md
  - ../simplify-locals/index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./interference-and-ordering.md
  - ./wat-shapes.md
  - ./starshine-port-readiness-and-validation.md
  - ../local-subtyping/index.md
  - ../local-cse/index.md
  - ../reorder-locals/index.md
  - ../simplify-locals/index.md
---

# Starshine Strategy For `coalesce-locals`

Use this page together with the tagged raw primary-source manifest in [`../../../raw/binaryen/2026-04-22-coalesce-locals-primary-sources.md`](../../../raw/binaryen/2026-04-22-coalesce-locals-primary-sources.md), the current-`main` recheck in [`../../../raw/binaryen/2026-04-25-coalesce-locals-current-main-recheck.md`](../../../raw/binaryen/2026-04-25-coalesce-locals-current-main-recheck.md), and the source/test map in [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md).
The goal here is not to re-explain upstream Binaryen, but to show the exact current Starshine status, the local code and doc surfaces that track the pass, and the remaining validation/placement constraints.

## The honest current status

`coalesce-locals` is now an active Starshine module pass with owner file [`../../../../../src/passes/coalesce_locals.mbt`](../../../../../src/passes/coalesce_locals.mbt).

The current local strategy is direct-pass parity first:

- keep the upstream pass spelling active in the registry and CLI surfaces
- keep the pass in the canonical no-DWARF parity and backlog documents
- leave public preset placement honest until surrounding locals-neighborhood ordering is replayed
- keep direct Binaryen parity evidence grounded in fuzz-generated inputs and compatible Binaryen 128 self-opt artifact lanes

See [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md) for the condensed readiness matrix and validation ladder.

## Exact local code map today

The fastest read-along path through the current Starshine status is:

- active pass owner
  - `src/passes/coalesce_locals.mbt`
    - value-aware local action scan, liveness/interference analysis, greedy slot coloring, local-index rewrite, redundant-copy cleanup, dead-set cleanup, and local-name-section invalidation
- active pass-name status
  - `src/passes/optimize.mbt`
    - `coalesce-locals` is an active module pass, not a removed-name entry
- dispatch and CLI surfaces
  - `src/passes/pass_manager.mbt`
    - explicit `coalesce-locals` module-pass dispatch
  - `src/cmd/cmd_wbtest.mbt`
    - CLI adapter coverage for `--coalesce-locals`
- backlog and delivery evidence
  - `agent-todo.md`
    - `#### CL - Coalesce Locals`
    - `[CL]001 - Compatibility and Lifetime Analysis`
    - `[CL]002 - Dual-Slot Rewrite, Reorder Interaction, and Artifact Parity`
- canonical scheduler context
  - `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
    - the two top-level no-DWARF slots where `coalesce-locals` belongs:
      - `local-subtyping -> coalesce-locals -> local-cse -> simplify-locals`
      - `reorder-locals -> coalesce-locals -> reorder-locals`
- exact neighboring local implementation files already worth reading
  - `src/passes/reorder_locals.mbt:2`
    - `reorder_locals_summary()`
  - `src/passes/reorder_locals.mbt:118`
    - `rl_scan_instruction(...)`
  - `src/passes/reorder_locals.mbt:183`
    - `rl_rewrite_instrs_in_place(...)`
  - `src/passes/reorder_locals.mbt:544`
    - `reorder_locals_run_module_pass(...)`
  - `src/passes/reorder_locals_test.mbt`
    - `test "reorder-locals rewrites local names for changed defined functions and clears raw payload"`
  - `src/passes/simplify_locals.mbt:15`
    - `simplify_locals_summary()`
  - `src/passes/simplify_locals.mbt:2`
    - `simplify_locals_descriptor()`
  - `src/passes/simplify_locals.mbt:70`
    - `simplify_locals_new_sinkables(...)`
- exact neighboring living dossiers that define the future slot and local landing zone
  - [`../local-subtyping/index.md`](../local-subtyping/index.md)
  - [`../local-cse/index.md`](../local-cse/index.md)
  - [`../reorder-locals/index.md`](../reorder-locals/index.md)
  - [`../simplify-locals/index.md`](../simplify-locals/index.md)

That code-and-doc map is the practical read-along path: readers can jump directly from the upstream algorithm and source/test map to the exact local status and the future landing zone.

## Freshness note

The 2026-04-25 current-`main` recheck found no teaching-relevant drift in Binaryen's checked owner, scheduler, helper, and dedicated-test surfaces. The 2026-05-05 Starshine port should therefore be treated as a direct-pass implementation against that documented Binaryen contract, with ordered-pipeline placement still reserved for a separate neighborhood replay.

## What Starshine currently does for this pass name

Today Starshine's behavior for `coalesce-locals` is an active explicit-pass implementation.

### 1. The name is active, not merely tracked

`src/passes/optimize.mbt` keeps the upstream spelling `coalesce-locals` in the active module-pass registry, and `src/passes/pass_manager.mbt` dispatches it to `coalesce_locals_run_module_pass`.
That means:

- the project treats `coalesce-locals` as a real runnable pass
- the spelling is preserved in the registry-level compatibility surface
- the pass is covered by direct registry, dispatcher, CLI, and pass-fuzz harness tests

That is the right current behavior for a direct-pass implementation whose public preset placement still needs ordered-neighborhood replay.

### 2. The work is tracked as a landed parity slice, not an orphan idea

`agent-todo.md` already gives `coalesce-locals` a real backlog slice under `CL`.
The landed deliverables now cover:

- compatibility and lifetime analysis
- exact type-compatibility rules
- value-aware interference for overlapping same-value locals
- local-index rewrite, declaration compaction, redundant-copy cleanup, and ineffective-set cleanup
- explicit registry, dispatcher, CLI, and harness wiring

The current docs should keep that slice connected to the exact Binaryen contract:

- exact-type-only coalescing, not subtype merging
- value-aware interference, not plain lifetime overlap
- parameter freezing and zero-init entry rules as correctness facts
- copy-removal profitability, not only local-count reduction
- repeated scheduler placement, not a one-shot standalone pass

### 3. The scheduler slot is already documented, and the missing neighbors matter

`docs/wiki/binaryen/no-dwarf-default-optimize-path.md` already places `coalesce-locals` in two deliberate late cleanup slots.
That matters because `coalesce-locals` is not meant to run in isolation.
Upstream Binaryen expects other passes to expose the right shapes first:

- `local-subtyping` should narrow declarations before exact-type-only coalescing freezes the slot choices
- `local-cse` and full `simplify-locals` profit from the simpler post-coalescing local traffic
- the later `reorder-locals -> coalesce-locals -> reorder-locals` cluster shows that declaration compaction and slot sharing are meant to interact, not compete

Current Starshine already has the declaration/index rewrite neighbor (`reorder-locals`), the direct `coalesce-locals` pass, and the later cleanup consumer (`simplify-locals`), but it does **not** yet have the missing `local-subtyping` and `local-cse` transforms.
That is why current preset placement should stay honest.

## The right future Starshine implementation shape

For a checklist-style implementation and validation ladder, see [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

The current docs and neighboring code strongly suggest that a future local `coalesce-locals` port should be taught as a **late local-slot sharing pass that composes with existing declaration rewrite and cleanup machinery**, not as an isolated textbook register allocator.

Why:

- Binaryen runs it in deliberate neighbor clusters, not alone
- the upstream pass is centered on exact-type local-slot reuse plus copy deletion
- Starshine already has module-side local index and name-section rewrite machinery in `reorder-locals`
- Starshine already has a later cleanup consumer in `simplify-locals`
- the remaining missing upstream neighbors explain why exact preset-slot parity remains blocked today

So the local strategy should be thought of as:

1. identify a MoonBit-side representation of the real upstream compatibility rules
   - exact type equality
   - value-aware overlap rejection
   - parameter and zero-init entry rules
   - locals that must never be coalesced
2. preserve the same conservative boundaries locally
   - no subtype-based merging inside this pass
   - no fake wins from dead/unreachable traffic
   - copy-removal profitability should stay part of the objective
   - later name/index repair must remain explicit
3. compose it with the surrounding local cleanup ecosystem
   - `local-subtyping -> coalesce-locals -> local-cse -> simplify-locals`
   - `reorder-locals -> coalesce-locals -> reorder-locals`
   - existing local metadata rewrite and later cleanup surfaces already maintained in-tree

In other words, the active direct pass now slots into a cleanup ecosystem that partly exists already; the remaining work is ordered-neighborhood and preset placement proof.

## The most important local dependency map

### Upstream `coalesce-locals` depends on prior local type tightening

See [`../local-subtyping/index.md`](../local-subtyping/index.md).

Why it matters locally:

- Binaryen coalesces only exact-equal local types
- the reviewed upstream scheduler places `local-subtyping` immediately before `coalesce-locals`
- if Starshine later narrows locals in the same way, `coalesce-locals` can inherit those cleaner exact-type opportunities instead of trying to widen its own scope

The active Starshine port should preserve that lesson instead of broadening `coalesce-locals` into a type-changing pass.

### The ordinary late run feeds directly into upstream `local-cse` and full `simplify-locals`

See [`../local-cse/index.md`](../local-cse/index.md) and [`../simplify-locals/index.md`](../simplify-locals/index.md).

Why:

- Binaryen runs `local-cse` after `coalesce-locals`
- full `simplify-locals` then cleans up the resulting local traffic again
- the pass therefore belongs to a late local-traffic simplification cluster, not a disconnected declaration-only phase

So a future Starshine implementation should treat those consumers as real neighbors, not afterthoughts.

### Existing Starshine `reorder-locals` code is the nearest landed local-index and metadata rewrite surface

See [`../reorder-locals/index.md`](../reorder-locals/index.md), `src/passes/reorder_locals.mbt`, and `src/passes/reorder_locals_test.mbt`.

Why:

- a future `coalesce-locals` port will have to rewrite local indices honestly
- `reorder-locals` already owns the module-side scan/rewrite machinery for local users and grouped-local-run rebuilding
- the landed name-section regression proves the repo already has one canonical place that keeps function-local names and `raw_name_sec_payload` stable after local index changes

That does not make `reorder-locals` an implementation of `coalesce-locals`, but it does make it an important local read-along file.

### Existing Starshine `simplify-locals` code is the nearest landed later cleanup consumer

See [`../simplify-locals/index.md`](../simplify-locals/index.md) and `src/passes/simplify_locals.mbt`.

Why:

- the current local `simplify-locals` pass already owns later local-traffic cleanup and structured result lifting in HOT form
- the upstream scheduler expects `coalesce-locals` to hand simpler local traffic into that neighborhood
- the active `coalesce-locals` port should therefore stay bounded to coalescing-specific cleanup instead of absorbing every simplify-locals family itself

## What Starshine does **not** claim yet

A future contributor should be careful not to overread the current local surface.
Starshine now has direct-pass implementation and evidence, but does **not** yet claim:

- public preset placement in both no-DWARF scheduler slots
- ordered-neighborhood parity with missing `local-subtyping` and `local-cse`
- public preset placement or runtime parity on every artifact lane

So the current repo status is best summarized as:

- active direct pass
- backlog tracked with remaining caveats
- scheduler slots documented but not preset-claimed
- neighboring declaration-rewrite and cleanup files implemented
- ordered-neighborhood replay still pending

## Validation plan for preset placement

The existing backlog plus neighboring pass docs imply the remaining validation ladder.
Future preset placement should validate in this order:

1. reduced shape tests for the real upstream families
   - exact-type positives
   - equal-value overlap positives
   - differing-value overlap negatives
   - zero-init and param-entry cases
   - redundant-copy wins and dead-set cleanup cases
2. negative correctness tests
   - subtype-only near misses
   - dead/unreachable traffic not creating fake wins
   - locals that must stay uncoalesced
   - loop-backedge and greedy-order sensitivity cases
3. cluster interaction tests
   - `local-subtyping -> coalesce-locals`
   - `coalesce-locals -> local-cse -> simplify-locals`
   - `reorder-locals -> coalesce-locals -> reorder-locals`
   - local-name and raw-name-section stability checks after rewrites
4. artifact and oracle comparison
   - the `CL` slice in `agent-todo.md`
   - the canonical no-DWARF debug-artifact replay path once a compatible Binaryen oracle can parse the artifact

That is more useful locally than a generic “compare with Binaryen later” note because it points directly at the in-repo workflow and the exact surrounding code surfaces.

## Bottom line

Current Starshine `coalesce-locals` strategy is direct-pass parity plus honest preset restraint:

- the upstream spelling is intentionally active in `src/passes/optimize.mbt`
- the backlog records `CL` as landed with remaining artifact-oracle caveats
- the canonical two-slot no-DWARF story is already documented in the optimizer notes
- the direct pass has focused tests, CLI coverage, full `moon test`, 10k `gen-valid` Binaryen compare evidence, debug/optimized artifact self-opt canonical-function equality, and direct-pass artifact timing at least as fast as Binaryen after the live-count interference guard
- total optimized-artifact wall time is still slightly above Binaryen, but the pass-local runtime issue is retired
- the docs keep one important honesty rule explicit: no public preset slot should be claimed before the surrounding locals-neighborhood replay is validated

So the right mental model today is “active direct pass, preset placement still pending.”
It is:

- **active direct transform**
- **clear tracked status and evidence**
- **clear slot in the pipeline**
- **clear neighboring implementation map for preset follow-up**
- **clear warning not to over-claim preset parity before the prerequisite neighbors and oracle lane are ready**
