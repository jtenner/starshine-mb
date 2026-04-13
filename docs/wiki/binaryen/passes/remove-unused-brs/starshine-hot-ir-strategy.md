---
kind: concept
status: working
last_reviewed: 2026-04-13
sources:
  - ../../../raw/research/0079-2026-04-10-remove-unused-brs-mid-unique-tee-floor.md
  - ../../../raw/research/0080-2026-04-10-remove-unused-brs-large-brtable-hot-skip.md
  - ../../../raw/research/0081-2026-04-10-remove-unused-brs-large-value-if-branch-raw-skip.md
  - ../../../raw/research/0082-2026-04-10-remove-unused-brs-large-tagged-result-prefix-hot-skip.md
  - ../../../raw/research/0083-2026-04-10-remove-unused-brs-large-typed-brtable-encoder-raw-skip.md
  - ../../../raw/research/0084-2026-04-10-remove-unused-brs-brtable-one-arm-payload-parity.md
  - ../../../raw/research/0085-2026-04-10-remove-unused-brs-drop-heavy-local-set-floor.md
  - ../../../../../src/ir/hot_core.mbt
  - ../../../../../src/ir/hot_mutate.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/remove_unused_brs.mbt
  - ../../../../../src/passes/perf_test.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../../../../src/cmd/cmd_test.mbt
related:
  - ./index.md
  - ./pattern-catalog.md
  - ./tail-and-return-cleanups.md
  - ./select-and-condition-rewrites.md
  - ./branch-exit-and-payload-rewrites.md
  - ./carried-guards-and-result-blocks.md
  - ./visit-order-and-bailouts.md
  - ./parity.md
---

# Starshine HOT-IR Strategy For `remove-unused-brs`

## Two-Layer Architecture

- Starshine does not run RUB as one monolithic lifted rewrite.
- The current implementation has two distinct layers:
  - a raw pre-lift path in [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
  - the real HOT pass in [`../../../../../src/passes/remove_unused_brs.mbt`](../../../../../src/passes/remove_unused_brs.mbt)
- That split is deliberate.
- The raw layer exists so obvious no-op families and one cheap decision-ladder normalization can avoid HOT lift entirely.
- The HOT layer exists because the real branch-shape work needs explicit labels, holders, region APIs, and on-demand analyses that only make sense after lift.

## Raw Pre-Lift Layer

The raw layer does three kinds of work:

- Candidate detection.
  It checks whether the original instruction tree even contains `nop`, `if`, `br`, `br_if`, `br_table`, or `return` surfaces worth considering.
- A narrow raw normalization.
  `run_hot_pipeline_raw_remove_unused_brs_rewrite_decision_ladder_instrs(...)` rewrites a cheap `local.get` / `i32.eq const` / `if(result i32)` chain into a raw `select` when that lets the function skip lift cleanly.
- Skip decisions.
  The raw layer recognizes several families where lifting used to cost a lot while doing no useful work:
  - `decision-ladder-selects`
  - `large-result-br-table-dispatch-ladder-noop`
  - `large-value-if-branch-ladder-noop`
  - `large-drop-heavy-branch-ladder-noop`
  - `large-typed-br-table-encoder-ladder-noop`
  - `structured-return-ladder-noop`
  - `unique-loop-select-return-ladder-noop`
  - `no-remove-unused-brs-candidates`

The current unique-loop/select classifier is also slightly wider than the earlier March version.

- it now accepts the measured sixteen-tee mid-band ladder family
- the artifact follow-up shows that this reclassifies `Func 1171`, not the still-open `Func 1150` hotspot

The later value-`if` / branch raw classifier is intentionally even narrower.

- it targets the tiny-local, deep-block `i64` ladder family that retired `Func 828`
- it is a raw skip only because the artifact function was still `changed=false` after paying full lift plus HOT traversal
- after that slice, the leading pass-heavy hotspot moves to `Func 356`

The later typed `br_table` encoder classifier is also intentionally artifact-shaped.

- it targets the deep mixed value/void block shell around a single encoder `br_table` that retired `Func 1482`
- it reuses a cheap decoded any-block-chain probe before the fuller count checks
- the first stricter single-root draft only matched the reduced perf lock, so the landed version was calibrated against the traced artifact body instead of freezing the reduced-only approximation
- after that slice, the visible runtime budget moves to `Func 1382`

The later drop-heavy branch classifier is intentionally artifact-calibrated too.

- it targets the large-local, no-`select`, no-`br_if`, no-`br_table` branch ladder that retired `Func 145`
- the first `local_set >= 210` draft still passed the reduced lock but missed the real artifact body
- the traced raw body for `Func 145` measured `local_set=201`, and both HOT-only raw guards were false
- the landed `local_set >= 200` floor now retires that artifact function before lift
- after that slice, the remaining pass-heavy work shifts to `Func 96`, `Func 788`, and `Func 1068`, while `Func 1382` remains the separate lift-heavy target

The raw layer is not trying to re-implement the whole pass.

- It only handles the parts that are:
  - obviously local in raw WAT form
  - cheap to prove correct without HOT analyses
  - known from perf history to be worth skipping

## HOT Fixpoint Layer

- The HOT layer is `remove_unused_brs_run(...)`.
- It also has a small lifted no-op front door before the main walk:
  - `large-br-table-return-ladder-noop`
  - `large-tagged-result-prefix-ladder-noop`
  - `large-void-if-return-ladder-noop`
  - `nested-constructor-return-ladder-noop`
- The newer `large-br-table-return-ladder-noop` family exists because some artifact functions still need lift, but RUB itself was doing no useful work after that point.
- The direct one-arm payload branch cleanup also now has a negative whole-function boundary:
  - if the function contains any `br_table`, `remove_unused_brs_try_rewrite_one_arm_payload_branch_if(...)` is disabled
  - the reduced `Func 3771` failure proved Binaryen keeps that family conservative instead of emitting `drop(br_if ...)`
  - this does not block the narrower continuation-wrapper rewrite from `0076`
- The current traced debug artifact slice retires:
  - `Func 1058` / `parse__opcode__instruction`
  - `Func 1150` / `wt__lower__module`
- The later lifted tagged result-prefix slice also retires:
  - `Func 356` / `dfe__try__rewrite__instruction__type__idxs`
- The raw layer also now retires:
  - `Func 828` / `hot__lift__impl__exact__family`
  - `Func 1482`
- The tagged result-prefix detector carries its own cost lesson:
  - the landed version piggybacks on the shared lifted ladder-shape scan
  - it also cheap-fails on locals, roots, and node count before the full walk
  - the first draft still retired `Func 356`, but it paid a second full scan and moved aggregate trace totals the wrong way
- It runs a bounded fixpoint:
  - recompute analysis scaffolding
  - walk the root region
  - apply structural rewrites
  - repeat up to eight cycles while mutations keep happening
- The `2026-04-13` perf audit also tightened the fixpoint plumbing:
  - all three lifted ladder-skip classifiers now share one precomputed summary instead of rescanning the function three times
  - each cycle uses one shared `remove_unused_brs_compute_cycle_scan(...)` for label reference counts, branch-payload-child marks, and the piggybacked `has_br_table` parity bit
  - root-site and single-arm-`nop` context are threaded through visitation instead of being rediscovered by extra whole-function scans
  - detached cleanup now bounds and dedupes candidate deletion work instead of repeatedly chasing every detached node shape

That reset-per-cycle approach matters because many rewrites change:

- which labels are still referenced
- which blocks are now branch-payload carriers
- whether a region tail is still removable
- whether a subtree still contains explicit `Return`

## Context Tracking

The HOT visitor tracks more than just the current node.

- `payload_context`
  means "the current subtree feeds a branch payload or equivalent preserved carrier path".
- `return_context`
  means "the current subtree is in a position where stripping or rewriting return-shaped control is legal and useful".
- `seen`
  is not a plain visited set. It records which node has already been visited in:
  - plain mode
  - payload mode
  - return mode

That detail matters because the same node may be safe to revisit under a stronger context even if it was already seen in a weaker one.

The visitor now also carries one more local fact when it matters.

- `current_site`
  threads the current root-site information down to payload-root rewrites so they do not have to rediscover their parent region/index with a separate whole-function search.

## Traversal Order

- `remove_unused_brs_visit_region(...)` first checks region-root patterns that are best recognized before descending:
  - `br_if` equality ladders to `br_table`
  - block-root self-branch sinking
  - inline single-`br_if` wrapper blocks
  - block-prefix payload-branch roots
  - loop-wrapper rotation
  - region-level `if` rewrites
  - local-set arm rewrites
- Only after those region-root opportunities are exhausted does the visitor descend into node-specific logic.

That ordering is one of the main reasons the docs treat RUB as a structured optimizer rather than a post-order peephole pass.

## Why So Many Guards Exist

Several guards recur across the implementation:

- Label-reference checks.
  A transformation usually refuses to touch a control node if its label is still referenced somewhere else.
- Branch-arity checks.
  Multi-value payload rewrites are only legal when the surviving payload side still supplies the exact arity the destination label expects.
- Reorder-safety checks.
  `select` formation is intentionally narrow. The pass only reorders conditions or value arms when the involved nodes are known to be safe, or when the condition is proven safe over the value-arm local-read surface.
- Branch-payload-child checks.
  Some result blocks are themselves payload carriers for another branch. Those wrappers cannot always be simplified immediately without breaking later structure.
- On-demand `use-def`.
  The pass only builds `use-def` when it must prove the single-use exit-only chain for `remove_unused_brs_try_voidify_exit_only_value_if(...)`.

## Why This Pass Is Still HOT-IR Work

- The current in-tree strategy depends heavily on HOT-only concepts:
  - holder blocks
  - region references
  - branch target labels
  - result arity queries
  - replacing a control node with a demoted block
  - splicing region roots while preserving detached-child cleanup
- The raw path is an optimization layer, not the real home of the pass.
- Any future RUB work that matters for artifact parity still needs to fit the HOT traversal and fixpoint model.

## Where Starshine Intentionally Differs From A Naive Port

- Starshine already includes targeted raw and hot bailouts that Binaryen itself does not need in the same way.
- Those are not accidental hacks. They are the current cost-control contract for the MoonBit debug artifact.
- The pass also distinguishes several HOT-only carrier families that do not appear as obviously in printed WAT:
  - returned ladders through explicit `Return`
  - prefix-guard payload result blocks
  - dropped carried wrappers
  - self-target arm-local block cleanup

## Current Maintenance Rule

- Keep the two-layer design.
- Add raw rewrites only when the family is obviously cheap and lift avoidance is the main win.
- Add HOT rewrites only when the structural guard is narrow enough to preserve current perf behavior and existing returned-ladder regressions.
- When a new HOT skip only needs one more count from a shape that is already being scanned, extend the shared scan instead of adding another whole-function walk.
- When a new whole-function negative parity guard only needs one more cheap fact, piggyback it onto an existing per-cycle scan instead of adding a dedicated walk.
- When a new helper needs broad nested discovery, assume the strategy is wrong until the cost model is proven.
