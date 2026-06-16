---
kind: concept
status: working
last_reviewed: 2026-06-16
sources:
  - ../../../raw/research/0528-2026-05-06-dead-code-elimination-direct-revalidation.md
  - ../../../raw/binaryen/2026-05-05-dead-code-elimination-current-main-recheck.md
  - ../../../raw/research/0449-2026-05-05-dead-code-elimination-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-22-dead-code-elimination-primary-sources.md
  - ../../../raw/research/0250-2026-04-22-dead-code-elimination-primary-sources-and-code-map-followup.md
  - ../../../raw/research/0134-2026-04-20-dead-code-elimination-binaryen-research.md
  - ../../../raw/research/0203-2026-04-21-dead-code-elimination-source-confirmation-followup.md
  - ../../../../../src/passes/dead_code_elimination.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/dead_code_elimination_test.mbt
  - ../../../../../src/passes/dead_code_elimination_live_repro_test.mbt
  - ../../../../../src/passes/perf_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./typed-control-voidification-and-eh.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
---

# Current Starshine `dead-code-elimination` strategy

Use this page together with the raw primary-source manifest in [`../../../raw/binaryen/2026-05-05-dead-code-elimination-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-dead-code-elimination-current-main-recheck.md), the strategy overview in [`./starshine-strategy.md`](./starshine-strategy.md), and the exact local MoonBit implementation map below.
The goal here is not to re-explain upstream Binaryen, but to show exactly where the current MoonBit implementation lives and how the local HOT-plus-pipeline split is wired today.

## Short version

The 2026-04-21 source-confirmation reread already corrected the upstream side:
Binaryen `version_129` `dce` is a small `TypeUpdater`-centered unreachable-shape postwalk.

Current Starshine is still broader than that oracle.
The local pass combines:

- a dedicated HOT owner file with branch-user, fallthrough, purity, and node-use caches
- region-local payload-forwarder and wrapper rewrites needed for current HOT lowering survival
- explicit nonfallthrough tail repair and `unreachable` materialization
- raw-skip heuristics in the hot pipeline manager
- writeback-validation and suspicious-carrier guard rails in the hot pipeline manager

So the honest one-line summary is:

- **Binaryen `dce` defines the semantic target, but current Starshine `dead-code-elimination` is a larger HOT rewrite family plus pipeline hygiene around that family.**

## Exact local code map

The fastest read-along path through the current Starshine implementation is:

- registry descriptor, summary, and preset placement in `src/passes/optimize.mbt`
  - `pass_registry_entry_hot("dead-code-elimination", ...)`
  - summary text: `Prune unreachable tails, dead dropped values, and dead-result structured control in hot IR regions.`
- main HOT implementation in `src/passes/dead_code_elimination.mbt`
  - `dead_code_elimination_run(...)`
  - `dead_code_elimination_visit_region(...)`
- core helper clusters in `src/passes/dead_code_elimination.mbt`
  - caches and liveness/purity support:
    - `DeadCodeEliminationNodeUseCache`
    - `DeadCodeEliminationFallthroughCache`
    - `DeadCodeEliminationBranchUserCache`
    - `DeadCodeEliminationPurityCache`
  - branch-target and fallthrough support:
    - `dead_code_elimination_build_branch_users_by_label(...)`
    - `dead_code_elimination_region_may_fallthrough(...)`
    - `dead_code_elimination_node_may_fallthrough(...)`
  - artifact-sensitive rewrite helpers:
    - `dead_code_elimination_try_rewrite_branch_payload_forwarder(...)`
    - `dead_code_elimination_try_rewrite_split_local_set_wrapper_forwarder(...)`
    - `dead_code_elimination_try_fold_nonfallthrough_prefix_into_branch_payload(...)`
  - dead-result and tail-repair helpers:
    - `dead_code_elimination_try_voidify_split_drop_control(...)`
    - `dead_code_elimination_voidify_control(...)`
    - `dead_code_elimination_ensure_explicit_unreachable_tail(...)`
    - `dead_code_elimination_finish_nonfallthrough_final_root(...)`
- raw-skip and pipeline guards in `src/passes/pass_manager.mbt`
  - raw-skip analysis helpers:
    - `run_hot_pipeline_dce_raw_has_early_terminator(...)`
    - `run_hot_pipeline_dce_raw_void_structured_noop(...)`
    - `run_hot_pipeline_dce_raw_live_typed_control_only(...)`
    - `run_hot_pipeline_dce_can_skip_raw(...)`
  - pass dispatch arm:
    - `"dead-code-elimination" => dead_code_elimination_run(ctx, func)`
  - pass-specific writeback guard:
    - `if descriptor_name == "dead-code-elimination" { ... }`
- focused local proof surfaces
  - `src/passes/dead_code_elimination_test.mbt`
  - `src/passes/dead_code_elimination_live_repro_test.mbt`
  - `src/passes/perf_test.mbt`
  - `src/cmd/cmd_wbtest.mbt`

That exact code map is the main practical addition in this refresh: readers can now jump directly from the strategy summary to the owning files and evidence surfaces.

## What the local owner file actually does

The real local implementation lives in `src/passes/dead_code_elimination.mbt`, not in `pass_manager.mbt`.
`pass_manager.mbt` owns only the surrounding raw-skip and writeback-routing logic.

Within the owner file, the pass is organized around a few durable concerns.

### 1. Cached branch-user, fallthrough, purity, and node-use facts

The local pass does not use Binaryen's small `TypeUpdater` shell.
Instead it rebuilds HOT-oriented facts as needed:

- node-use counts for safe detached-subtree cleanup
- branch-user and incoming-branch maps by label
- fallthrough caches for control/result reasoning
- purity caches for dead dropped-value cleanup

That broader cache stack is the clearest sign that current Starshine is not a direct line-by-line Binaryen port.

### 2. Region-local dead-result cleanup

The local pass still overlaps the upstream intent most strongly on reachable-prefix versus dead-tail cleanup.
The owner file includes helpers that:

- remove dead roots after nonfallthrough control
- replace roots with surviving children when that is HOT-safe
- voidify dropped control wrappers when the result really is dead locally
- preserve or materialize explicit `unreachable` tails when later lowering still needs them

This is where the local pass most directly matches the beginner mental model of “DCE.”

### 3. HOT-specific payload-forwarder and wrapper rewrites

Several helpers are explicitly about shapes that arose from HOT lifting/lowering and generated-artifact replay, not from the small upstream AST pass shape.
Examples include:

- branch-payload-forwarder rewrites
- split-`local.set` wrapper forwarder rewrites
- folding nonfallthrough prefixes into branch payloads

These helpers should be taught as **local lowering-survival logic**, not as the semantic definition of Binaryen `dce`.

### 4. Explicit final-tail repair

The owner file has a clear final-root repair story:

- decide whether a nonfallthrough final root needs an explicit `unreachable`
- avoid duplicating a tail that already exists
- insert the explicit tail only when the lowered form still needs it

That is broader and more operational than upstream Binaryen's small postwalk, but it is a durable local invariant.

## Raw-skip behavior is part of the local strategy

A major local difference from upstream Binaryen is the raw fast path in `src/passes/pass_manager.mbt`.
The pipeline can skip HOT lifting entirely when raw Wasm inspection shows there are no likely DCE candidates. There is no longer a blanket `-O4z` DCE no-op: DCE-positive O4z functions must run the pass, while the remaining raw skips are shape-specific guards or no-candidate classifications.

As of 2026-06-16, the `load-call-set-dce-noop`, `loop-outer-branch-dce-noop`, and broader `no-dce-candidates` skips are narrowed for explicit dead suffixes. If a function has a root or nested region that reaches an explicit `return`, `return_call*`, `throw*`, `br`, `br_table`, or `unreachable`, Starshine performs a raw explicit-suffix trim before considering those skips; guarded hazard functions still avoid HOT lifting. This matches Binaryen v130 `--dce` on the focused load/call/set and loop-outer-branch root and nested fixtures plus the literal-unreachable no-candidate fixture, while preserving the guard for true no-candidate hazard-only bodies; when a trimmed `block` or `loop` becomes literal `unreachable`, the raw path collapses that wrapper so the containing explicit suffix can be trimmed too. Structured-control fallthrough is intentionally not inferred beyond these exact literal-unreachable collapses because branch targets can make a containing structured node appear nonfallthrough without making its following sibling roots dead.

The key helpers are:

- `run_hot_pipeline_dce_raw_has_early_terminator(...)`
- `run_hot_pipeline_dce_raw_trim_explicit_dead_suffixes(...)`
- `run_hot_pipeline_dce_raw_void_structured_noop(...)`
- `run_hot_pipeline_dce_raw_live_typed_control_only(...)`
- `run_hot_pipeline_dce_can_skip_raw(...)`

The practical meaning is:

- some functions with structured control still take the raw fast path
- top-level parity success for `dead-code-elimination` does not always mean the full HOT rewrite family ran on that function
- perf and trace evidence are part of the real local contract, not just an optimization detail

## Writeback and validation guards are part of the current contract

`src/passes/pass_manager.mbt` also keeps pass-specific post-lowering safeguards for DCE.
The `descriptor_name == "dead-code-elimination"` branch checks for:

- invalid escape carriers
- suspicious escape carriers
- local-count blowups
- writeback validation errors

That matters because several historically visible failures surfaced during DCE replay even when the root cause was a HOT/writeback interaction rather than a pure pass-local semantic mismatch.
For current Starshine, those guard rails are part of the honest strategy story.

## Current proof surface in this repository

The local proof surface is broader than one regression file.

### Main HOT rewrite coverage

`src/passes/dead_code_elimination_test.mbt` locks the main local families, including:

- ordinary dead dropped-value cleanup
- unreachable-root pruning after `return`, including raw root and nested explicit-suffix trimming before the load/call/set, loop-outer-branch, and no-candidate raw skips
- dead-result typed `if` and block cleanup
- modern EH `try_table` body-fallthrough handling, including unreachable-body suffix trimming and result-drop collapse
- the limited lowered-legacy-`try` DCE reachability subset, including a conservative raw skip for reachable synthetic arms, plus the remaining stack-switching handler-label tooling boundary
- payload-forwarder rewrites
- split-`local.set` wrapper rewrites
- explicit `unreachable` tail repair
- detached label-owner and detached shared-subtree cleanup

This file is the best compact proof surface for what the MoonBit owner file actually tries to do.

The legacy `try` and stack-switching tests are intentionally narrow. Binaryen v130 supports both surfaces, but Starshine cannot yet represent them faithfully in `@lib`: legacy `try` text lowers to a synthetic sequential check block rather than a real `Try` node, while stack-switching `cont` / `resume` handler labels are rejected by the current WAST/lib type surface. The DCE tests therefore cover only the local legacy synthetic subset: skip when an alternate arm can fall through, and still trim when all lowered arms are unreachable. Reopen full legacy-EH and stack-switching DCE parity when the local representation exists; do not count the synthetic guard as full legacy `Try` parity.

### Live repro coverage

`src/passes/dead_code_elimination_live_repro_test.mbt` exists for artifact-sensitive cases that were worth freezing as direct repros, including:

- exact inner-carrier shapes
- typed loop-input drops needed for lowering

That file is especially useful for readers who want to understand why the local helper set grew beyond the upstream Binaryen algorithm.

### Perf and raw-skip coverage

`src/passes/perf_test.mbt` proves the raw fast path and its boundaries.
The existing tests lock cases such as:

- straight-line value-returning functions
- straight-line void direct calls
- branchless void structured control
- branchless typed final `if`
- branchy typed control that is still locally live and therefore a no-op for DCE

The same file also proves that the pipeline emits the expected `skip-raw reason=no-dce-candidates` trace when those fast-path rules fire.

### Refreshed direct compare coverage

The 2026-05-06 refreshed-harness lane ran:

- `moon info`
- `moon fmt`
- `moon test`
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass dead-code-elimination --out-dir .tmp/pass-fuzz-dead-code-elimination`

It reported 6759 compared cases, 6759 normalized matches, 0 semantic mismatches, and 20 Binaryen empty-recursion-group parser/canonicalization command failures. That re-proves the direct explicit pass after the fuzzer/harness churn while leaving whole-command runtime, raw wasm/text-form drift, and ordered-prefix proof as `[DCE]003` follow-up work.

### CLI and artifact replay coverage

`src/cmd/cmd_wbtest.mbt` proves that:

- `--dead-code-elimination` is a real CLI-visible pass flag
- the pass can validate the checked-in debug artifact through `run_cmd_with_adapter`
- the native default-IO path still reports the known debug-artifact blocker explicitly
- the pass resolves correctly inside larger explicit pass chains and preset-like command lines

That keeps the local strategy grounded in an end-to-end artifact replay lane rather than only in unit-style HOT tests.

## Current local-vs-upstream split

The safest contrast remains:

- **Binaryen `dce`:** a small child-first unreachable-shape cleanup pass centered on `TypeUpdater`
- **Starshine `dead-code-elimination`:** a broader HOT-region cleanup pass with cache-heavy control reasoning, lowering-sensitive wrapper rewrites, raw-skip heuristics, and writeback-validation guard rails

Current Starshine therefore includes behaviors that should not be silently attributed upstream, including:

- payload-forwarder rewrites
- split-wrapper retargeting
- explicit final-tail materialization logic
- raw no-op classification before HOT lift
- suspicious-carrier and local-limit writeback guards

The living docs should keep that split explicit.

## Why the implementation is split across two files

The split is now fairly clear:

- `src/passes/dead_code_elimination.mbt` owns the semantic HOT rewrite family
- `src/passes/pass_manager.mbt` owns pipeline policy around that family

That is a better mental model than treating everything under the DCE name as one monolithic pass body.
It also makes future refactors easier to reason about:

- semantic parity work belongs mainly in `dead_code_elimination.mbt`
- raw-skip policy and writeback-hygiene decisions belong mainly in `pass_manager.mbt`

## Honest future port rule

If Starshine moves closer to upstream Binaryen `dce`, preserve two truths at the same time:

1. Binaryen `version_129` remains the semantic oracle.
2. Current Starshine has already learned real HOT/lowering lessons that should not be discarded casually.

So future work should aim to shrink the semantic gap without erasing the local evidence encoded in:

- the payload-forwarder and wrapper rewrite helpers
- the explicit tail-repair logic
- the raw-skip boundaries
- the artifact replay tests

## Bottom line

Current Starshine `dead-code-elimination` is real, useful, and well-tested.
Its exact local implementation is now easy to follow:

- registration in `src/passes/optimize.mbt`
- HOT semantics in `src/passes/dead_code_elimination.mbt`
- raw-skip and writeback guards in `src/passes/pass_manager.mbt`
- focused proof in the pass, live-repro, perf, and CLI test files

That makes the current subset easy to teach honestly:

- **what it does today:** a broader HOT cleanup family around dead dropped values, dead-result control, payload-forwarder repair, and explicit tail repair
- **what it does not equal:** upstream Binaryen's smaller `TypeUpdater`-centered `dce`
