---
kind: concept
status: working
last_reviewed: 2026-04-13
sources:
  - ../../../raw/research/0076-2026-04-10-remove-unused-brs-br-table-carried-wrapper-parity.md
  - ../../../raw/research/0077-2026-04-10-remove-unused-brs-large-result-br-table-noop-skip.md
  - ../../../raw/research/0078-2026-04-10-remove-unused-brs-false-prefix-guard-raw-skip.md
  - ../../../raw/research/0079-2026-04-10-remove-unused-brs-mid-unique-tee-floor.md
  - ../../../raw/research/0080-2026-04-10-remove-unused-brs-large-brtable-hot-skip.md
  - ../../../raw/research/0081-2026-04-10-remove-unused-brs-large-value-if-branch-raw-skip.md
  - ../../../raw/research/0082-2026-04-10-remove-unused-brs-large-tagged-result-prefix-hot-skip.md
  - ../../../raw/research/0083-2026-04-10-remove-unused-brs-large-typed-brtable-encoder-raw-skip.md
  - ../../../raw/research/0084-2026-04-10-remove-unused-brs-brtable-one-arm-payload-parity.md
  - ../../../raw/research/0085-2026-04-10-remove-unused-brs-drop-heavy-local-set-floor.md
  - ../../../raw/research/0086-2026-04-13-remove-unused-brs-medium-branchy-hot-skip.md
  - ../../../raw/research/0087-2026-04-13-remove-unused-brs-call-heavy-mixed-if-mesh-hot-skip.md
  - ../../../raw/research/0088-2026-04-13-remove-unused-brs-localset-heavy-value-if-mesh-hot-skip.md
  - ../../../../../src/ir/hot_core.mbt
  - ../../../../../src/ir/hot_mutate.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/remove_unused_brs.mbt
  - ../../../../../src/passes/perf_test.mbt
related:
  - ./index.md
  - ./pattern-catalog.md
  - ./starshine-hot-ir-strategy.md
  - ./returned-ladder-hot-shapes.md
  - ./parity.md
---

# `remove-unused-brs` Visit Order And Bailouts

## Why This Page Exists

- RUB is not just a list of rewrites.
- Its execution model is part of its correctness and performance contract.
- Several of the hardest historical regressions came from changing discovery order or widening the scan surface, not from building the wrong replacement node.

## Raw Skip Reasons

The raw pre-lift layer can return early with one of these reasons:

- `decision-ladder-selects`
  a raw decision ladder was rewritten to `select`, and no HOT-only candidates remain
- `large-void-if-return-ladder-noop`
  a very large void-`if` / return family is filtered by raw shape counts instead of always paying lift first
- `large-result-br-table-dispatch-ladder-noop`
  a giant one-result `br_table` dispatch ladder is recognized as a Binaryen-compatible no-op before lift
- `large-value-if-branch-ladder-noop`
  a deep small-local value-`if` / bare-`br` ladder is recognized as a Binaryen-compatible no-op before lift
- `large-drop-heavy-branch-ladder-noop`
  a large-local drop-heavy branch ladder is recognized as a Binaryen-compatible no-op before lift
- `moderate-control-ladder-noop`
  a medium-size unchanged control ladder with heavy local traffic is filtered before lift once the raw shape is clearly outside RUB's profitable rewrite surface
- `large-typed-br-table-encoder-ladder-noop`
  a deep mixed value/void block shell around a single `br_table` encoder ladder is recognized as a Binaryen-compatible no-op before lift
- `structured-return-ladder-noop`
  a structured returned-ladder family is recognized as no-op unless a HOT-only carried-guard or condition-child family is also present
- `unique-loop-select-return-ladder-noop`
  a narrower loop/select returned family is recognized as no-op
  and now accepts the measured sixteen-tee mid-band variant instead of requiring twenty tees
- `no-remove-unused-brs-candidates`
  the original instruction tree does not contain any RUB-relevant control surface

The perf tests explicitly lock in both the skip reason and the absence of lift/pass timers where appropriate.

## Cheap Raw Prefilters

The large-dispatch raw skip is intentionally two-stage.

- `run_hot_pipeline_raw_remove_unused_brs_leading_block_chain_depth(...)` does a cheap leading-chain probe first.
- `run_hot_pipeline_raw_remove_unused_brs_can_skip_large_result_br_table_dispatch_ladder(...)` only runs its fuller recursive shape scan after that cheap guard proves the body starts with a very deep plain block chain.
- `run_hot_pipeline_raw_remove_unused_brs_leading_any_block_chain_depth(...)` plays the same role for the later typed `br_table` encoder family, but it follows any decoded block shell instead of only plain void blocks.
- `run_hot_pipeline_raw_remove_unused_brs_can_skip_large_typed_br_table_encoder_ladder(...)` only runs its fuller count checks after that cheaper decoded-shell probe proves the body starts with a very deep nested block wrapper.

That design is part of the pass contract.

- The skip is meant to retire giant artifact ladders like `Func 1219` / `Func 1220`, not to add another recursive scan to ordinary result blocks.
- The perf lock is `remove-unused-brs skips large result br_table dispatch ladders without hot lift`.
- The later typed encoder skip follows the same rule for `Func 1482`, and its lock is `remove-unused-brs skips large typed br_table encoder ladders without hot lift`.

## Raw Detector Boundaries

The raw layer also has to stay aligned with the real HOT legality surface.

The latest example is the prefix-guard detector that cancels `structured-return-ladder-noop`.

- It used to treat any later `br_if 0` inside the first void block of a result block as a carried-guard candidate.
- That was too broad: a reduced false-positive family with a standalone `drop` root before the later `br_if` still forced lift even though the real result-prefix matcher could never rewrite it.

The current rule is narrower.

- If the inner prefix before the first matching `br_if 0` already contains a clearly separate void root such as `drop`, `local.set`, `return`, `br`, a void `block` / `if`, `loop`, `try_table`, or `unreachable`, the raw layer no longer treats that block as a carried-guard HOT-only candidate.
- The perf lock is `remove-unused-brs skips structured return ladders when a false prefix guard candidate cannot rewrite`.

The unique loop/select detector has its own boundary lesson too.

- The measured mid-band family still needed the unique skip even though it only had `16` `local.tee`.
- The original `>= 20` tee floor was stricter than the real no-op family.
- The focused lock is `remove-unused-brs skips mid unique loop-select return ladders without hot lift`.
- The artifact follow-up matters here:
  - this classifier change reclassifies `Func 1171`
  - it does not explain the separate `Func 1150` / `wt__lower__module` hotspot

The later large value-`if` / branch raw skip has the same lesson in a different shape family.

- It is not a generic "skip large value ladders" rule.
- The detector is intentionally narrow:
  - tiny locals
  - deep plain leading block chain
  - nearly one-for-one `if` / `br` counts
  - `return_count == block_count`
  - no `local.set`, `br_if`, `br_table`, `select`, or loop surface
- That is the measured envelope that retired `Func 828`.
- The perf lock is `remove-unused-brs skips large value-if branch ladders without hot lift`.

The later typed `br_table` encoder raw skip adds the same lesson again with a different cheap probe.

- It is not a generic "skip typed `br_table`" rule.
- The detector is intentionally narrow:
  - large locals
  - very deep decoded block shell
  - exactly one `br_table`
  - many calls, `local.set`, `local.tee`, `if`, `br`, `return`, and `drop`
  - no `br_if`
  - no `select`
  - mixed value and void block counts in the measured artifact band
- The first stricter draft only matched the reduced perf lock and missed the real artifact because it assumed a single reduced typed root.
- The landed version keys on the decoded any-block shell and retires `Func 1482`.
- The perf lock is `remove-unused-brs skips large typed br_table encoder ladders without hot lift`.

The later large-local drop-heavy raw skip adds the same calibration lesson one more time.

- It is not a generic "skip large branch ladders" rule.
- The detector is intentionally narrow:
  - roughly `470` locals
  - no `select`
  - no `br_if`
  - no `br_table`
  - measured call / `local.set` / `local.tee` / `if` / `br` / `drop` traffic in the artifact band
- The first `local_set >= 210` draft still passed the reduced perf lock but missed the real artifact because `Func 145` only measured `local_set=201`.
- The HOT-only raw guards were both false on that same artifact body, so the miss was classifier width rather than a guard boundary.
- The landed `local_set >= 200` floor retires `Func 145`.
- The perf lock is `remove-unused-brs skips large drop-heavy branch ladders without hot lift`.

## HOT Skip Reasons

After lift, the pass still has hot-only bailouts:

- `large-br-table-return-ladder-noop`
- `large-tagged-result-prefix-ladder-noop`
- `medium-branchy-block-ladder-noop`
- `call-heavy-mixed-if-mesh-noop`
- `localset-heavy-value-if-mesh-noop`
- `large-void-if-return-ladder-noop`
- `nested-constructor-return-ladder-noop`

Those skips exist because some giant lifted families were repeatedly proven to be semantically unchanged while still costing a lot to traverse.

The hot skip is shape-based, not name-based.

- it counts calls, locals, `if`, `return`, `select`, `br_if`, blocks, loops, plain `br`, `br_table`, and `drop`
- the tagged result-prefix family also counts one-result blocks whose first roots are not plain prefix `Block`s
- it matches against specific wide-ladder or constructor-ladder signatures
- the newer large-`br_table` family specifically retires the traced unchanged pair `Func 1058` / `Func 1150` after lift instead of trying to force another raw skip boundary
- the same trace also shows why the bounds must be calibrated on lifted shape counts: the working block ceiling had to be wider than the printed WAT shape first suggested
- the later tagged result-prefix family retires `Func 356` after lift when repeated carried-prefix discovery only yields `reject=inner-op` and the pass still exits unchanged
- the later medium branchy block-ladder family retires another lifted unchanged cluster from the canonical artifact:
  - `Func 144`, `Func 301`, `Func 353`, `Func 1512`, `Func 1547`, `Func 1859`, and `Func 1867`
  - the landed rule is calibrated on lifted summary counts, not printed-WAT intuition, because the family only became obvious after extracting and tracing the real artifact bodies
- the later call-heavy mixed-if mesh family retires a second lifted unchanged cluster from the canonical artifact:
  - `Func 408`, `Func 413`, `Func 739`, `Func 832`, `Func 902`, `Func 1022`, `Func 1448`, and `Func 1815`
  - the landed rule again uses lifted summary counts rather than raw WAT guesses, because the real lifted block shell was much wider than the original printed shape suggested
- the later localset-heavy value-if mesh family retires a third lifted unchanged cluster from the canonical artifact:
  - `Func 837`, `Func 3021`, `Func 3120`, `Func 3130`, and `Func 3134`
  - this rule also follows lifted summary counts rather than raw WAT guesses, because the family only becomes obvious once the artifact bodies are lifted and the value-if plus localset traffic is counted structurally
- all three later lifted slices keep the same maintenance rule:
  - the landed detectors reuse the shared lifted shape scan and cheap summary bounds because widening the raw layer for the same families was noisier and harder to calibrate on the exact artifact shell
- after the later localset-heavy value-if mesh hot skip, the visible runtime budget is now led by `Func 497`, `Func 1168`, `Func 229`, `Func 990`, `Func 883`, and `Func 1213` on the unchanged side while `Func 1382` remains the older lift-heavy outlier

The relevant perf tests prove that these families still pay lift cost but skip the expensive rewrite walk.

## Region-First Traversal

`remove_unused_brs_visit_region(...)` does not start by descending into each root's full subtree.

Instead, it first checks root-local patterns in this rough order:

- `br_if` equality ladder to `br_table`
- block-root cleanup (`sink_if_arm_self_branch_block`, `inline_single_br_if_block`, branch-to-trap for simple branches to a following `unreachable`, `br_table` continuation wrappers, `block_prefix_payload_branch_root`, loop backedge `br_if` conditionalization, `rotate_void_block_single_loop`)
- dropped result-block cleanup
- outer `br` payload cleanup
- region-level `if` cleanup, including the Binaryen-shaped loop backedge `eqz` one-arm-if normalization
- local-set arm cleanup

Only after those direct opportunities are exhausted does the pass call `remove_unused_brs_visit_node(...)` on the surviving root.

That ordering is essential:

- root-local rewrites often expose cheaper inner shapes
- descending first would force the pass to rediscover the same structural cleanup in a more expensive context

## Threaded Local Context Instead Of Rediscovery

Two older whole-function rediscovery helpers are intentionally gone.

- The visitor now threads `RemoveUnusedBrsRootSite?` as `current_site` so payload-root rewrites can use their real parent region/index directly instead of searching the whole function for the same fact.
- Single-arm `nop` preservation is now passed explicitly at the known `then` / `else` trim sites instead of asking later whether a region is an `if` arm.

Maintenance rule:

- if a local fact is already known at the callsite, thread it down through visitation instead of re-finding it with another whole-function walk.

## Fast Structural Guards

Two carried-wrapper helpers now intentionally fail fast before label-ref-heavy discovery work:

- `remove_unused_brs_try_rewrite_block_prefix_payload_branch_root(...)`
- `remove_unused_brs_try_rewrite_result_block_prefix_payload_branch(...)`

The key rule is simple:

- if the first inner root is not already a `br_if`, do not pay the more expensive label-ref, self-tail, or payload-holder checks

That matters on the debug artifact because very large nested block dispatch ladders were repeatedly entering those helpers and bailing only after proving something that the first inner root already made impossible.

The perf locks are:

- `remove-unused-brs skips prefix-root scans for nested block dispatch ladders`
- `remove-unused-brs skips result-prefix scans for nested block dispatch ladders`

## Whole-Function Negative Guards

The direct one-arm payload branch rewrite now also has a whole-function parity guard.

- If the current function contains any `br_table`, `remove_unused_brs_try_rewrite_one_arm_payload_branch_if(...)` returns `false`.
- The reduced `Func 3771` family proved Binaryen keeps that direct payload-branch `if` conservative instead of lowering it to `drop(br_if ...)`.
- This is a parity boundary, not a general "`br_table` blocks all RUB work" rule:
  - the narrower continuation-wrapper rewrite from `0076` still runs on its own legality checks
  - the large `br_table` families from `0077`, `0080`, and `0083` are still separate no-op skip classes

## Seen Masks Instead Of A Plain Visited Set

The pass records three visitation modes in `seen`:

- plain
- payload-context
- return-context

This matters because:

- a node already visited in plain mode may still need a payload-sensitive rewrite later
- a node already visited in payload mode may still need a return-context rewrite later

Any future simplification of the seen mask needs to prove it does not suppress legal revisits.

## Cheap Caches And Expensive Analyses

The pass now shares one explicit cycle scan for the cheap whole-function facts that every fixpoint round needs.

The newer raw no-op filters also follow the same Binaryen-shaped maintenance rule:

- prove cheap local shape and cost bounds first
- only fall through to lift when the family still looks like it might pay for full structural discovery

- `remove_unused_brs_compute_cycle_scan(...)` computes:
  - `label_refs`
  - `branch_payload_children`
  - the piggybacked `has_br_table` parity bit
- The other integer caches (`seen`, reorder safety, embedded control, subtree returns) are reset in place for the current node count.

It only computes the expensive `use-def` analysis on demand for exit-only value-`if` voidification.

There is a dedicated perf regression proving that simple tail-return cleanup does not accidentally build `use-def`.

The broader maintenance rule is now:

- if a new whole-function negative guard only needs one more cheap fact, extend the shared per-cycle scan instead of adding another walk
- if the fact is already known from traversal context, thread it through the visitor instead of rescanning the function

## Mutation Churn Control

- The fixpoint is capped at eight cycles.
- The perf test `remove-unused-brs trims one mutation step from tail branch payload if cleanup` explicitly watches mutation churn in one cleanup family.
- The perf test `remove-unused-brs rewrites br_table continuation wrappers in one mutation` now does the same for the new continuation-wrapper parity slice.
- This is not cosmetic.
- Several historical parity slices were "correct enough" locally but mutated too many times on the real artifact and blew the pass budget.

## Returned-Ladder Bailout Interaction

The returned-ladder raw skips are not absolute.

The raw layer intentionally cancels the skip when it detects HOT-only families such as:

- condition-child value-`if`
- prefix guard payload branch candidates

That is why the perf tests include both:

- functions that should skip
- structurally similar returned ladders that must still lift and rewrite

## Debugging Rule

When a new parity mismatch shows up, use the trace and bailout surfaces to answer these first:

1. Did the raw layer skip, rewrite, or lift?
2. Did the HOT layer report a skip reason?
3. Did RUB report any mutation at all?
4. Was the family blocked by label refs, branch-payload-child marking, or reorder safety?

If those answers are missing, the next code change is probably premature.

## Practical Rule

- Treat execution order, skip heuristics, and mutation count as part of the pass contract.
- Do not collapse raw and HOT behavior into one conceptual bucket when documenting or debugging the pass.
- If a new matcher only works after widening the scan surface substantially, add the proof that it belongs in the current visit order and does not just bypass the bailout design.
