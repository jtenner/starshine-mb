---
kind: concept
status: supported
last_reviewed: 2026-07-04
sources:
  - ../../../raw/research/1443-2026-07-04-coalesce-locals-o4z-neighborhood-structured-tee.md
  - ../../../raw/research/1442-2026-07-04-coalesce-locals-direct-refresh-loop-unused-locals.md
  - ../../../raw/research/0550-2026-05-08-coalesce-locals-ordered-slot-replay.md
  - ../../../raw/binaryen/2026-05-05-coalesce-locals-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-25-coalesce-locals-current-main-recheck.md
  - ../../../raw/research/0473-2026-05-05-coalesce-locals-current-main-recheck.md
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

Use this page together with the [`coalesce-locals` landing page](./index.md)'s tagged source list, the current-`main` recheck in [`../../../raw/binaryen/2026-05-05-coalesce-locals-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-coalesce-locals-current-main-recheck.md), and the source/test map in [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md).
The goal here is not to re-explain upstream Binaryen, but to show the exact current Starshine status, the local code and doc surfaces that track the pass, and the remaining validation/placement constraints.

## The honest current status

`coalesce-locals` is now an active Starshine module pass with owner file [`../../../../../src/passes/coalesce_locals.mbt`](../../../../../src/passes/coalesce_locals.mbt).

The current local strategy is direct-pass parity plus exact-slot proof:

- keep the upstream pass spelling active in the registry and CLI surfaces
- keep direct Binaryen parity evidence grounded in fuzz-generated inputs and compatible Binaryen 128 self-opt artifact lanes
- keep the public `local-subtyping -> coalesce-locals -> local-cse -> simplify-locals` slot explicit and regression-covered
- keep the focused `reorder-locals -> coalesce-locals -> reorder-locals` replay proven without over-claiming broader public `reorder-locals` scheduling

See [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md) for the condensed readiness matrix and validation ladder.

## Exact local code map today

The fastest read-along path through the current Starshine status is:

- active pass owner
  - `src/passes/coalesce_locals.mbt`
    - value-aware local action scan, liveness/interference analysis, greedy slot coloring, effective-copy weighting and copy-connected-first coloring order, bounded structured copy-chain forwarding, derived branch-carrier consume-forwarding with destination-read-after-source-write rejection, source-write/destination-read interference restoration after copy/consume relaxation, path-disjoint branch-result slot reuse with same-path clobber-read guards, branch-aware structured effective-write marking for cleanup, local-index rewrite, redundant-copy cleanup, structured ineffective-write cleanup, immediate `nop; drop` debris cleanup after ineffective tee rewriting, dead-set cleanup, loop unread/write-only scratch coalescing, loop adjacent and non-adjacent single-use copy-through coalescing, a 4096-flattened-local guard around dense non-loop coloring matrices, local-name-section invalidation, and the `[AUDIT006-D]` TypeIdx/RecIdx invariant comment
- pass-specific generator profile
  - `src/validate/gen_valid.mbt`
    - `coalesce-locals-all` aggregate plus straight-line, structured, and loop-copy-through leaves for dedicated closeout fuzzing
  - `src/validate/gen_valid_tests.mbt`
    - profile-name/alias and emitted-trigger coverage
- active pass-name status
  - `src/passes/optimize.mbt:277`
    - `coalesce-locals` is an active module pass, not a removed-name entry
- direct-pass tests
  - `src/passes/coalesce_locals_test.mbt`
    - registration, non-overlap merge, different-value overlap, later reread liveness, structured param reuse, loop unused-local, unread-local scratch, adjacent copy-chain coalescing, and non-adjacent copy-through coalescing, non-loop structured `local.tee` coalescing, structured self-copy cleanup, bounded structured branch copy-chain forwarding, derived branch-carrier consume-forwarding, branch-aware side-carrier effective writes, effective-copy/copy-connected side-carrier coloring, destination-read-after-source-write guarding, source-write/destination-read interference restoration, path-disjoint branch-result param-slot reuse, structured ineffective copy-set cleanup, ineffective tee debris before immediate drop, the 4097-local dense-coloring boundary, redundant-copy cleanup, ineffective-write cleanup, the exact `local-subtyping -> coalesce-locals -> local-cse -> simplify-locals` neighborhood, and the exact `reorder-locals -> coalesce-locals -> reorder-locals` neighborhood
- dispatch and CLI surfaces
  - `src/passes/pass_manager.mbt:8936`
    - explicit `coalesce-locals` module-pass dispatch
  - `src/cmd/cmd_wbtest.mbt:4376-4407`
    - CLI adapter coverage for `--coalesce-locals`
- ordered-slot delivery evidence
  - `docs/wiki/raw/research/0550-2026-05-08-coalesce-locals-ordered-slot-replay.md`
    - new exact-neighborhood regressions
    - refreshed 10k direct parity lane
    - debug-artifact reorder-sandwich replay
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

The 2026-05-05 current-`main` recheck found no teaching-relevant drift in Binaryen's checked owner, scheduler, helper, and dedicated-test surfaces. The Starshine port should therefore be treated as a direct-pass implementation against that documented Binaryen contract, with ordered-pipeline placement still reserved for a separate neighborhood replay.

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

The landed deliverables now cover:

- compatibility and lifetime analysis
- exact type-compatibility rules
- value-aware interference for overlapping same-value locals
- local-index rewrite, declaration compaction, redundant-copy cleanup, structured self-copy cleanup, structured `local.tee` coalescing under the non-loop conservative overlay, bounded structured copy-chain forwarding and derived branch-carrier consume-forwarding into dead slots with destination-read-after-source-write rejection, source-write/destination-read interference restoration after copy/consume relaxation, path-disjoint branch-result slot reuse with same-path clobber-read guards, branch-aware structured effective-write marking for cleanup, effective-copy weighting/copy-connected coloring order, loop unread-local scratch coalescing, loop adjacent/non-adjacent copy-through coalescing, structured ineffective-write cleanup, ineffective-set cleanup, and a finite dense-coloring boundary for huge non-loop functions
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

Current Starshine now has the declaration/index rewrite neighbor (`reorder-locals`), the type-tightening neighbor (`local-subtyping`), the downstream cleanup neighbors (`local-cse` and `simplify-locals`), and older focused proof for both exact `coalesce-locals` neighborhoods.
The refreshed startup-map GC/local prefix replay no longer shows a size-losing CL-owned local-slot drift after the structured `local.tee` cleanup, branch-aware effective-write hardening, effective-copy/copy-connected coloring, loop unread-local scratch, loop adjacent/non-adjacent copy-through improvements, narrow concrete-ref direct-struct-get packing, preferred-first GC-ref ordering, and structured-scalar slot-order preference. The checked drift is now a Starshine raw/code-body size win (`-20` raw bytes at `+ coalesce-locals`, `-18` at `+ local-cse`); per-function splitting still shows first textual diff `defined=3` as locally Starshine-smaller and loop-heavy function 18 as a smaller local residual (`+20` code-body bytes). Direct pass closeout is now green across regular GenValid 100k, dedicated `coalesce-locals-all` 10k, random all-profiles 10k, and cleanup-normalized wasm-smith 10k. Broader preset widening still needs a dedicated preset-scheduling slice with exact ordering tests and artifact evidence, but no active direct CL random-all mismatch family remains: immediate tee/drop debris, nested nonlocal block-escape live-write handling, sampled label-aware `return` / branch-to-block-continuation liveness, sampled top-level tail param reuse after ineffective dead writes, and structured-scalar slot-order drift are fixed for the sampled `ssa-nomerge-smoke` family, and the sampled `heap2local-struct` subfamily is replay-green.

## The right future Starshine implementation shape

For a checklist-style implementation and validation ladder, see [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

The current docs and neighboring code strongly suggest that a future local `coalesce-locals` port should be taught as a **late local-slot sharing pass that composes with existing declaration rewrite and cleanup machinery**, not as an isolated textbook register allocator.

Why:

- Binaryen runs it in deliberate neighbor clusters, not alone
- the upstream pass is centered on exact-type local-slot reuse plus copy deletion
- Starshine already has module-side local index and name-section rewrite machinery in `reorder-locals`
- Starshine already has a later cleanup consumer in `simplify-locals`
- the remaining broader optimize-path work now lives outside direct `coalesce-locals` parity itself

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

In other words, the active direct pass now slots into a cleanup ecosystem that exists in-tree and has exact-neighborhood proof; the remaining work is broader preset and neighboring-pass policy, not direct `coalesce-locals` uncertainty.

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
Starshine now has direct-pass implementation and evidence, and it now **does** claim exact-neighborhood proof for:

- `local-subtyping -> coalesce-locals -> local-cse -> simplify-locals`
- `reorder-locals -> coalesce-locals -> reorder-locals`

What it still does **not** claim is that every broader neighboring-pass or public preset policy question is closed. The current repo status is best summarized as:

- active direct pass
- direct 10k parity refreshed on 2026-07-04 after fixing structured param-slot reuse, loop unused-local coalescing, and branch-aware structured effective-write marking
- both exact scheduler neighborhoods replayed
- first public slot kept explicit, second slot still focused because public `reorder-locals` scheduling is tracked elsewhere

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
   - the canonical no-DWARF debug-artifact replay path for the exact neighborhoods that own `coalesce-locals`
   - any broader preset or neighboring-pass artifact lane once the surrounding slices explicitly call for it

That is more useful locally than a generic “compare with Binaryen later” note because it points directly at the in-repo workflow and the exact surrounding code surfaces.

## Bottom line

Current Starshine `coalesce-locals` strategy is direct-pass parity plus exact-slot proof:

- the upstream spelling is intentionally active in `src/passes/optimize.mbt`
- the canonical two-slot no-DWARF story is now regression-covered and backed by a current-head reorder-sandwich artifact replay
- the direct pass has focused tests, CLI coverage, full `moon test`, refreshed 2026-07-04 10k regular GenValid parity evidence, older 10k mixed-generator parity evidence, debug/optimized artifact self-opt canonical-function equality for the direct pass, and a green debug-artifact reorder-sandwich compare on normalized WAT plus canonical functions
- total optimized-artifact wall time for the direct pass is still slightly above Binaryen, but the pass-local runtime issue is retired
- the docs keep one important honesty rule explicit: proving `coalesce-locals` itself does not automatically settle every broader `reorder-locals` or preset scheduling question

So the right mental model today is “active direct pass, exact slots proven, broader neighbor policy still explicit.”
It is:

- **active direct transform**
- **current-head direct parity refreshed after the 2026-07-04 structured/loop unused-local and branch-aware structured effective-write fixes**
- **both exact scheduler neighborhoods replayed**
- **clear neighboring implementation map for broader preset follow-up**
- **clear warning not to over-claim unrelated neighboring-pass policy as part of direct `coalesce-locals` signoff**
