---
kind: concept
status: working
last_reviewed: 2026-04-10
sources:
  - ../../../../0073-2026-04-02-code-pushing-binaryen-plan.md
  - ../../../../../src/passes/code_pushing.mbt
  - ../../../../../src/passes/code_pushing_test.mbt
  - ../../../../../src/ir/hot_lower_live_repro_test.mbt
related:
  - ./index.md
  - ./wat-shapes.md
  - ./binaryen-strategy.md
  - ./artifact-frontiers.md
  - ./validation-and-fuzzing.md
---

# Starshine HOT-IR Strategy For `code-pushing`

## Why This Page Exists

- Binaryen implements `code-pushing` on its own expression tree.
- Starshine implements the pass on lifted [`HotFunc`](../../../../../src/ir/README.md)
  regions and then has to lower the result back to Wasm.
- That means there are two distinct questions:
  - what motion is semantically intended
  - what HOT mutation sequence preserves valid region and branch-result structure
- This page documents the second question.

## HOT Representation Mapping

- A candidate move starts as a root-level `HotOp::LocalSet` in some HOT region.
- A Binaryen push point becomes one of:
  - `HotOp::If`
  - `HotOp::BrIf`
  - `HotOp::BrOnNull`
  - `HotOp::BrOnNonNull`
  - `HotOp::BrOnCast`
  - `HotOp::BrOnCastFail`
  - or a `HotOp::Drop` whose child is one of those
- Result-carrying WAT shapes often lift into block regions where the printed
  source form is no longer obvious. That is why the pass has several owner-aware
  helpers for blocks, dropped owners, and inner carrier payloads.

## Top-Level Driver

- The entrypoint is `code_pushing_run(ctx, func)` in
  [`src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt).
- The current loop is:
  - bail out immediately if the function has no locals or no cheap candidate
    shape
  - build a static scan used for cheap traversal gating
  - iterate until one rewrite round finds nothing else to do
  - recompute local eligibility after every successful mutation
- This mirrors Binaryen's "repeat local discovery after mutation" behavior
  closely enough for direct-pass work, while still staying local to one lifted
  function.

## Phase 1: Eligibility Analysis

- `cp_analyze_locals(func)` performs the pass-local SFA scan.
- It computes, per local:
  - whether the local is a parameter
  - how many sets it has
  - how many gets it has
  - how many gets have already been seen when visiting each block in postorder
  - whether the final result satisfies the pass's SFA rule
- This intentionally does not reuse the SSA overlay. The pass is trying to mimic
  Binaryen's weaker candidate rule, not to invent a stronger Starshine-only one.
- `local.tee` counts as a set in this analysis, matching the Binaryen-style
  surface that the focused tests pin explicitly.

## Phase 2: Cheap Traversal Gating

- `cp_func_has_candidate_shape`, `cp_prepare_func_static_scan`, and
  `cp_new_traversal_gate_scan` exist to keep the pass from walking every nested
  region expensively when no real candidate can succeed.
- The cheap scan only asks broad questions:
  - does this subtree touch any SFA local at all
  - does this subtree contain a potential push point
  - does this subtree obviously contain unremovable value effects
- If the answer is "no useful candidate shape exists," the pass skips building
  the richer summary cache entirely.

## Phase 3: Richer Pass-Local Summaries

- Binaryen gets the information it needs from its own effect analysis plus local
  counters.
- Starshine layers a pass-local cache on top of the existing coarse HOT effect
  mask instead of widening [`src/ir/effects.mbt`](../../../../../src/ir/effects.mbt)
  globally.
- The core types are:
  - `CpEffectSummary`
  - `CpBarrierSummary`
  - `CpSummaryCache`
- Each summary tracks:
  - local reads
  - local writes
  - global reads
  - global writes
  - the coarse HOT effect mask
- The cache is then used to answer the two questions that matter for movement:
  - is the value subtree itself removable
  - does this candidate conflict with the barrier created by the crossed gap and
    the push point

## Phase 4: Root Motion Inside One Region

- `cp_root_pushpoint_id` and `cp_root_if_pushpoint_id` recognize the exact root
  kinds that count as push points.
- `cp_try_push_to_pushpoint` is the HOT analogue of Binaryen's segment rewrite.
- The implementation keeps Binaryen's core semantics:
  - backward scan from just before the push point
  - accumulate a barrier as the scan moves left
  - preserve the order of all moved roots
  - let a failed movable root contribute to the barrier for earlier roots
- `cp_summary_conflicts_with_barrier` and
  `cp_summary_conflicts_with_dead_move_gap` are the key safety checks. They make
  the pass precise enough to move dead or alias-only locals across local-only
  gaps that Binaryen also accepts, without reopening broader invalid cases.

## Phase 5: One-Arm `if` Sinking

- `cp_try_sink_into_if` handles the more specific "move into one arm" case.
- The implementation starts the barrier with the `if` condition's effects, just
  like Binaryen's logic requires.
- It only sinks when:
  - one arm reads the local
  - the opposite arm does not
  - later reads are either absent or only reachable through the target arm
  - the move does not conflict with the condition or accumulated barrier
- On success the old slot becomes `nop` and the set is prepended to the chosen
  arm with direct region mutation.
- The current Starshine implementation is stricter than Binaryen in one
  important way: it refuses to sink into result-producing `if` arms. That fence
  is there because Starshine's lifted result carriers have already shown real
  lowering failures in adjacent non-void territory.

## Phase 6: Explicit-Exit And Non-Void Guards

- Binaryen can ignore control-transfer effects in its barrier set because the
  local is dead on the exited path.
- Starshine still needs extra owner-aware guards to keep lifted result carriers
  valid when lowering back to Wasm.
- The current helper family here includes:
  - `cp_node_has_explicit_exit`
  - `cp_root_is_unconditional_terminal_explicit_exit`
  - `cp_root_is_simple_explicit_exit_local_set`
  - `cp_if_root_has_only_safe_explicit_exits`
  - `cp_local_set_value_has_only_safe_explicit_exits`
  - `cp_nonvoid_prefix_has_explicit_exit_guard`
- These helpers let the pass admit several families that used to be blocked too
  broadly:
  - earlier explicit-exit `if` roots
  - earlier explicit-exit `local.set` carriers
  - self-contained or terminal owner-only block prefixes
  - dropped-owner predecessor chains
- At the same time they keep the truly dangerous parent-result carrier families
  fenced off. That tradeoff is the central correctness story of the current pass.

## Phase 7: Dropped-Carrier Extraction

- The largest Starshine-specific addition beyond the basic Binaryen algorithm is
  `cp_try_extract_local_set_from_dropped_carrier`.
- This exists because HOT lift can strand a would-be movable set inside a dropped
  result carrier where plain same-region reordering cannot reach it honestly.
- The current kept extraction families are deliberately narrow:
  - direct alias `local.set(local.get ...)`
  - single-result `i32` call-fed `local.set(call ...)`, rewritten as
    `local.tee temp (call ...)` plus a later alias set
  - the same call-fed slice after a safe explicit-exit prefix
  - the same call-fed slice one wrapper deeper under a carrier-local `Block` or
    `Drop(Block)`
- The extraction logic also requires:
  - the local is still SFA
  - the carrier body does not read the local again after the extracted set
  - the target `if` does not itself read or write that local
  - there is still a later read after the target `if`
- This is the most HOT-specific part of the current pass because it compensates
  for a mismatch between Binaryen's AST placement opportunities and Starshine's
  lifted carrier structure.

## Phase 8: Recursive Region Traversal

- `cp_try_rewrite_nested_regions` and `cp_try_rewrite_region` walk the nested HOT
  region tree.
- The traversal is intentionally shape-aware rather than purely recursive over all
  nodes. It knows to descend into:
  - `if` arms
  - block bodies
  - catch bodies
  - other structured nested regions
  - dropped wrappers that hide a relevant nested carrier
- This matters because several real artifact reducers only became reachable after
  Starshine learned to look through `Drop`-wrapped owners when searching for
  nested candidate regions.

## Lowering-Validity Boundary

- Every time the pass grows into a new carrier family, the repo pairs the pass
  test with a focused HOT-lowering proof in
  [`src/ir/hot_lower_live_repro_test.mbt`](../../../../../src/ir/hot_lower_live_repro_test.mbt).
- Those repros are not optional decoration. They are the only honest way to show
  that a HOT rewrite is semantically fine and still lowers to valid Wasm.
- The current global blocker proves why this matters:
  - if a parent escape block is rewritten to become result-producing after a
    carried payload extraction and inner carried-`if` demotion, a branch can be
    retargeted around the payload site
  - HOT verification then sees `InvalidBranchArity(_, _, 0, 1)`
  - the native artifact later surfaces that same class as a final `stack
    underflow` in `Func 1977`

## Current Deliberate Divergences From Binaryen

- Starshine is narrower than Binaryen around non-void carrier rewrites because the
  current lowering pipeline cannot yet represent every Binaryen-safe result
  adjustment honestly.
- Starshine is broader than Binaryen in one limited practical sense: it performs
  explicit dropped-carrier extraction so the lifted HOT form can recover the final
  placement Binaryen reaches in its own AST.
- Starshine currently models default semantics only:
  - no `--ignore-implicit-traps`
  - no `-tnh`
  - no GC non-nullable-local repair slice

## Practical Strategy For Next Work

- Keep reducing the real `Func 1977` invalid family before widening any more
  local-only extraction or terminal-owner rules.
- Prefer new rules that can be stated in terms of:
  - owner identity
  - payload-site preservation
  - branch-result arity
- Do not reopen broad "non-void regions are probably fine" relaxations. The pass
  has already shown that those broad relaxations can look safe in small reducers
  and still fail on the real artifact.
