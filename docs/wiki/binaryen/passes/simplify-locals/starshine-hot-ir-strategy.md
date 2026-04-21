---
kind: concept
status: working
last_reviewed: 2026-04-21
sources:
  - ../../../raw/binaryen/2026-04-21-simplify-locals-primary-sources.md
  - ../../../raw/research/0148-2026-04-21-simplify-locals-binaryen-research.md
  - ../../../raw/research/0241-2026-04-21-simplify-locals-primary-sources-and-structure-followup.md
  - ../../../raw/research/0076-2026-04-01-simplify-locals-binaryen-research-plan.md
  - ../../../../../src/passes/simplify_locals.mbt
  - ../../../../../src/passes/simplify_locals_test.mbt
  - ../../../../../src/passes/pass_manager.mbt
related:
  - ./index.md
  - ./wat-shapes.md
  - ./binaryen-strategy.md
  - ./structure-result-lifting-and-carrier-cleanup.md
  - ./implementation-map.md
  - ./effect-ordering-and-barriers.md
  - ./raw-lane-and-writeback.md
  - ./validation-and-signoff.md
  - ./performance-and-artifact-frontiers.md
  - ../../../ir2/architecture-rules.md
  - ../../../ir2/local-ssa-policy.md
---

# `simplify-locals` Starshine Strategy

## Core Design Rule

- `simplify-locals` must stay inside the repo's existing `HotFunc` contract.
- We do not want a second owned optimizer IR just to mimic Binaryen's AST walker.
- The Starshine strategy is therefore not "copy Binaryen's implementation." It is:
  - preserve Binaryen's transform categories and safety rules
  - map them onto `HotFunc`, `HotRegionRef`, node ids, and exact writeback
  - keep artifact-only no-op families out of hot lift whenever a narrow raw-lane proof is good enough

## The Three-Layer Port

- In practice the pass is already split across three layers, and that split is intentional:
  1. the lifted HOT-IR pass in [`../../../../../src/passes/simplify_locals.mbt`](../../../../../src/passes/simplify_locals.mbt)
  2. the raw exact-instruction fast path and raw-skip path in [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
  3. exact-body cleanup that runs after lower, and now also on selected raw-skip results
- A lot of confusion disappears once this is stated explicitly:
  - the HOT pass is where semantic parity lives
  - the raw lane is where artifact-scale no-op families are bypassed or cheaply rewritten
  - the exact writeback cleanup is where narrow lowered-temp cleanup happens without pretending lowered exact wasm is the same as HOT IR

## Why The Repo Went No-Structure First

- The worktree strategy is deliberately no-structure first.
- The reasons are practical, not aesthetic:
  - sink and tee parity closes many more Binaryen diffs per unit of implementation risk
  - effect-ordering mistakes in the no-structure path are easier to reduce and fuzz
  - structure lifting depends on the no-structure cleanup being trustworthy first
  - the artifact frontier repeatedly surfaced local-flow bugs before it surfaced genuinely-new structure families
- This is why many of the currently-documented wins are about:
  - sibling-argument ordering
  - loop-carried initializer safety
  - tee-backed copied locals
  - validator raw-skip temp cleanup
  and not only about blocks or `if` results.

## How Binaryen's Phases Map Onto HOT IR

### 1. Count Uses And Build Sinkable State

- HOT IR already gives Starshine stable local ids and node ids.
- The lifted pass mirrors Binaryen's need for future-use knowledge by computing local get counts up front.
- The in-tree functions for this layer include:
  - `simplify_locals_count_local_gets`
  - `simplify_locals_record_local_set`
  - `simplify_locals_new_sinkables`
- The sinkable state is more detailed than a simple map of local to node:
  - it carries aggregated effect masks
  - sparse local read/write footprints
  - scratch-stamp state used to avoid large whole-array clears on artifact-scale functions

### 2. Scan Linear Regions And Consume Later Gets

- The closest HOT-IR analogue to Binaryen's linear walk is region scanning.
- The pass uses region order and root order to approximate the same "pending candidate on the active linear trace" model Binaryen has.
- The main region and node walk lives in:
  - `simplify_locals_scan_region`
  - `simplify_locals_scan_node`
  - `simplify_locals_try_consume_following_local_get`
  - `simplify_locals_try_inline_following_local_get`
  - `simplify_locals_try_inline_leading_local_get_child`
- This is the core place where the repo now handles:
  - direct single-use sink
  - multi-use sink through `local.tee`
  - pure later-call-argument inlining
  - loop-carried safety
  - sibling-argument ordering guards

### 3. Encode Effect Ordering Locally To The Pass

- HOT IR has effect information, but the pass still needs its own directional policy layer to mimic Binaryen.
- The relevant helpers in the current implementation include:
  - `simplify_locals_collect_region_local_effects`
  - `simplify_locals_collect_subtree_local_effects`
  - `simplify_locals_effects_for_pending_local_set`
  - `simplify_locals_effects_ordered_before`
  - `simplify_locals_invalidate_sinkables`
- This is where Starshine learned several non-obvious lessons from artifact reductions:
  - local-only traffic can sometimes commute and should not always kill a call-backed pending value
  - read-only trapping values can commute past later read-only traps in some narrow cases
  - memory writes still kill those trap-commuting candidates
  - loop bodies need a fresh sinkable set instead of inheriting outer pending values
  - region bodies under `if` / `try` / `try_table` must contribute local read/write information or sibling-argument moves become wrong

### 4. Rewrite Structure By Region Surgery, Not AST Pointer Tricks

- The most important beginner-facing bridge here is the structure-result carrier family:
  - block-result carriers
  - `if` / `else` result carriers
  - one-armed `if` defaultable-local lifting
  - narrow loop-tail carriers
  - local wrapper-forwarder cleanup around real artifact shapes
- Keep the compact cross-map for that family in [`./structure-result-lifting-and-carrier-cleanup.md`](./structure-result-lifting-and-carrier-cleanup.md).
  This page keeps the larger HOT/raw/writeback story; the bridge page is where future threads should start when the question is shape-to-helper ownership.

- Binaryen sometimes stages structure rewrites with trailing `nop` growth because its walker stores `Expression**` pointers.
- HOT IR does not need that exact trick because Starshine can operate on region references and node ids directly.
- The structure-rewrite layer lives in:
  - `simplify_locals_try_rewrite_block_return`
  - `simplify_locals_try_rewrite_if_return`
  - `simplify_locals_try_rewrite_loop_return`
  - `simplify_locals_try_rewrite_nested_one_armed_if_child`
  - `simplify_locals_build_one_armed_if_then_body`
- The important HOT-IR-specific choice is that the pass rebuilds the new region body explicitly:
  - preserve live then-arm roots
  - preserve Binaryen-style `nop` sentinels when the shape depends on them
  - replace only the tail local write, not the entire arm
- That is a deliberate deviation from the incidental Binaryen retry pattern while preserving the same semantic result.

### 5. Run Equivalent-Copy Cleanup As Its Own HOT Phase

- The repo's lifted pass carries a dedicated equivalent-local phase instead of trying to smuggle equivalent cleanup into the main scan.
- The main helpers are:
  - `simplify_locals_new_equivalences`
  - `simplify_locals_add_equivalence`
  - `simplify_locals_pick_best_equivalent_local`
  - `simplify_locals_run_equivalent_cleanup`
- This phase is where several subtle parity fixes landed:
  - preserve tee-backed copied locals for later branch or call uses
  - protect tee-defined locals only when the current use is a direct call child
  - allow same-arm non-call aliases to collapse back to the source local
- That behavior is not accidental cleanup polish. It is required to match Binaryen's exact preference ordering on copied locals.

### 6. Keep Dead Cleanup Separate From Equivalent Cleanup

- The repo pass ends with a dedicated dead cleanup phase, mirroring the fact that Binaryen also separates "equivalent locals" from "dead writes."
- The in-tree cleanup helpers live in:
  - `simplify_locals_run_dead_cleanup`
  - `simplify_locals_delete_detached_nodes`
- This separation matters because:
  - some dead writes are pure and can vanish
  - some must become `drop(value)`
  - some detached nodes are already known dead and should not pay whole-function scans again

## Why There Is Still A Raw Lane

- The raw lane exists for two reasons:
  - some large debug-artifact functions are extremely expensive to lift but turn out to be Binaryen-equal no-ops
  - some narrow exact-instruction rewrites are easy to prove safe and cheap without lifting the whole function
- The raw lane is *not* a shadow optimizer that should gradually replace HOT IR.
- It is a pressure-relief valve for:
  - giant builder initializers
  - validator-heavy structured helpers
  - dense structured call-heavy no-op families
  - a few narrow exact rewrites that are parity-safe and easy to trace
- The detailed rules live in [`./raw-lane-and-writeback.md`](./raw-lane-and-writeback.md), but the architectural rule is simple:
  - if a rewrite needs structural understanding, rich effect ordering, or result retagging, prefer HOT IR
  - if a no-op family can be proven cheap and stable from exact instruction shape alone, prefer the raw lane

## Why Exact Writeback Cleanup Lives Beside The Raw Lane

- Lowered exact wasm is not HOT IR, but it still exposes obvious temporary scaffolding that Binaryen also tends to remove.
- The repo now uses a fail-closed exact writeback cleanup for very narrow families:
  - dead copied `local.tee`
  - dead adjacent `local.set` / `local.get`
- Crucially, the broader "strip lowered nops" experiment was rejected because it diverged almost immediately on the pass-fuzz lane.
- So the Starshine rule is:
  - exact writeback cleanup is allowed only when the family is narrow, reduced, and oracle-backed
  - preserving Binaryen's lowered `nop` scaffolding is part of parity, not an optional prettifier

## HOT IR Boundaries That Must Stay True

- The pass must preserve the repo's IR2 contract:
  - mutate only through public region and node helpers
  - keep node identity and live/dead status coherent
  - keep control result types explicit
  - respect lower-time invariants instead of assuming a tree printer will repair them later
- This is why some potential Binaryen-like moves remain intentionally rejected in Starshine:
  - broad selectification of lifted `if` results
  - broad lowered-`nop` stripping
  - broad structured barrier rewrites without a reduced Binaryen-backed proof

## Current In-Tree Shape

- The exact lifted pass in [`../../../../../src/passes/simplify_locals.mbt`](../../../../../src/passes/simplify_locals.mbt) carries:
  - sinkable-state tracking
  - effect-ordering and local-effect collection
  - structure rewrites
  - equivalent cleanup
  - dead cleanup
- The raw lane in [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt) carries:
  - narrow exact rewrites such as structured pure-call-tail and validator-heavy temp cleanup
  - no-op raw-skip gates for artifact-scale helper families
  - post-lower exact cleanup reused on selected raw-skip results
- Focused regressions live in:
  - [`../../../../../src/passes/simplify_locals_test.mbt`](../../../../../src/passes/simplify_locals_test.mbt)
  - [`../../../../../src/passes/pass_manager_wbtest.mbt`](../../../../../src/passes/pass_manager_wbtest.mbt)
  - [`../../../../../src/passes/perf_test.mbt`](../../../../../src/passes/perf_test.mbt)

## Open Maintenance Rule

- Keep this page as the live explanation of how `simplify-locals` is being ported onto HOT IR.
- File future structure-lifting decisions, raw-lane retirement rules, and Binaryen parity boundaries here or in sibling simplify-locals pages instead of generic optimizer notes.
- If a future change only updates artifact frontiers or evidence, prefer updating [`./parity.md`](./parity.md) instead of growing this page with transient chronology.

## Sources

- Raw primary-source manifest: [`../../../raw/binaryen/2026-04-21-simplify-locals-primary-sources.md`](../../../raw/binaryen/2026-04-21-simplify-locals-primary-sources.md)
- Follow-up note: [`../../../raw/research/0241-2026-04-21-simplify-locals-primary-sources-and-structure-followup.md`](../../../raw/research/0241-2026-04-21-simplify-locals-primary-sources-and-structure-followup.md)
- Archived research note: [`../../../raw/research/0076-2026-04-01-simplify-locals-binaryen-research-plan.md`](../../../raw/research/0076-2026-04-01-simplify-locals-binaryen-research-plan.md)
- Implementation: [`../../../../../src/passes/simplify_locals.mbt`](../../../../../src/passes/simplify_locals.mbt)
- Focused tests: [`../../../../../src/passes/simplify_locals_test.mbt`](../../../../../src/passes/simplify_locals_test.mbt)
- Raw lane: [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- IR2 rules: [`../../../ir2/architecture-rules.md`](../../../ir2/architecture-rules.md) and [`../../../ir2/local-ssa-policy.md`](../../../ir2/local-ssa-policy.md)
