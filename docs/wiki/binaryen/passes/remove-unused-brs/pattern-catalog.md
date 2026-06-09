---
kind: concept
status: working
last_reviewed: 2026-06-09
sources:
  - ../../../raw/research/0721-2026-06-09-remove-unused-brs-merge-blocks-audit.md
  - ../../../raw/research/0076-2026-04-10-remove-unused-brs-br-table-carried-wrapper-parity.md
  - ../../../raw/research/0077-2026-04-10-remove-unused-brs-large-result-br-table-noop-skip.md
  - ../../../raw/research/0078-2026-04-10-remove-unused-brs-false-prefix-guard-raw-skip.md
  - ../../../raw/research/0080-2026-04-10-remove-unused-brs-large-brtable-hot-skip.md
  - ../../../raw/research/0081-2026-04-10-remove-unused-brs-large-value-if-branch-raw-skip.md
  - ../../../raw/research/0082-2026-04-10-remove-unused-brs-large-tagged-result-prefix-hot-skip.md
  - ../../../raw/research/0083-2026-04-10-remove-unused-brs-large-typed-brtable-encoder-raw-skip.md
  - ../../../raw/research/0084-2026-04-10-remove-unused-brs-brtable-one-arm-payload-parity.md
  - ../../../raw/research/0085-2026-04-10-remove-unused-brs-drop-heavy-local-set-floor.md
  - ../../../raw/research/0086-2026-04-13-remove-unused-brs-medium-branchy-hot-skip.md
  - ../../../raw/research/0087-2026-04-13-remove-unused-brs-call-heavy-mixed-if-mesh-hot-skip.md
  - ../../../raw/research/0088-2026-04-13-remove-unused-brs-localset-heavy-value-if-mesh-hot-skip.md
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/remove_unused_brs.mbt
  - ../../../../../src/passes/remove_unused_brs_test.mbt
  - ../../../../../src/passes/perf_test.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./starshine-hot-ir-strategy.md
  - ./tail-and-return-cleanups.md
  - ./select-and-condition-rewrites.md
  - ./branch-exit-and-payload-rewrites.md
  - ./carried-guards-and-result-blocks.md
  - ./returned-ladder-hot-shapes.md
  - ./visit-order-and-bailouts.md
  - ./parity.md
---

# `remove-unused-brs` Pattern Catalog

This page is the exhaustive rewrite inventory for the current tree.

- If a helper mutates control structure for RUB, it should appear here.
- If a helper deliberately skips or preserves a family because widening it would be wrong or too expensive, it should appear here too.
- The detailed family pages own the long-form explanation; this page owns completeness.

## How To Read This Catalog

- "Raw" means pre-lift work in `pass_manager.mbt`.
- "HOT" means lifted work in `remove_unused_brs.mbt`.
- "Preserve" means the pass recognized the family but intentionally left it alone.
- Test names below refer to focused regressions in [`../../../../../src/passes/remove_unused_brs_test.mbt`](../../../../../src/passes/remove_unused_brs_test.mbt) unless a perf or CLI file is named explicitly.

## Raw Pre-Lift Patterns And Skips

- `run_hot_pipeline_raw_remove_unused_brs_rewrite_decision_ladder_instrs(...)`
  Rewrites a raw `local.get` / `i32.eq const` / `if(result i32 const else const)` ladder into `select` before lift.
  This is the only real raw transform, and it is intentionally narrow.
  Covered by perf test `remove-unused-brs rewrites decision ladders without hot lift`.
- `run_hot_pipeline_raw_remove_unused_brs_leading_block_chain_depth(...)`
  Cheap prefilter for the large result `br_table` dispatch no-op family.
- `run_hot_pipeline_raw_remove_unused_brs_leading_any_block_chain_depth(...)`
  Cheap prefilter for the later large typed `br_table` encoder no-op family.
- `run_hot_pipeline_raw_remove_unused_brs_can_skip_large_result_br_table_dispatch_ladder(...)`
  Recognizes giant one-result `br_table` dispatch ladders with a deep leading block chain and no HOT-only surface, then skips them before lift.
  Covered by perf test `remove-unused-brs skips large result br_table dispatch ladders without hot lift`.
- `run_hot_pipeline_raw_remove_unused_brs_can_skip_large_typed_br_table_encoder_ladder(...)`
  Recognizes the later deep mixed value/void block shell around a single `br_table` encoder ladder that still matched Binaryen exactly but was paying full lift plus HOT cost on the artifact.
  Covered by perf test `remove-unused-brs skips large typed br_table encoder ladders without hot lift`.
- `run_hot_pipeline_raw_remove_unused_brs_can_skip_large_value_if_branch_ladder(...)`
  Recognizes the later tiny-local `i64` value-`if` / bare-`br` ladder family that still matched Binaryen exactly but was paying full lift plus HOT cost on the artifact.
  Covered by perf test `remove-unused-brs skips large value-if branch ladders without hot lift`.
- `run_hot_pipeline_raw_remove_unused_brs_can_skip_large_drop_heavy_branch_ladder(...)`
  Recognizes the later large-local drop-heavy branch ladder family that still matched Binaryen exactly but was paying full lift plus HOT cost on the artifact.
  The landed local-set floor is calibrated to the real `Func 145` body, not only the reduced perf lock.
  Covered by perf test `remove-unused-brs skips large drop-heavy branch ladders without hot lift`.
- `run_hot_pipeline_raw_remove_unused_brs_can_skip_structured_return_ladder(...)`
  Recognizes structured returned-ladder no-op families that used to waste HOT work.
- `run_hot_pipeline_raw_remove_unused_brs_can_skip_unique_loop_select_return_ladder(...)`
  Recognizes a narrower loop/select returned-ladder no-op family.
  The current bounds now intentionally include the measured sixteen-tee mid-band variant.
  Covered by perf tests `remove-unused-brs skips unique loop-select return ladders without hot lift` and `remove-unused-brs skips mid unique loop-select return ladders without hot lift`.
- `run_hot_pipeline_raw_remove_unused_brs_has_prefix_guard_payload_branch_candidate(...)`
  Cancels the raw skip if the function contains the prefix-guard payload branch family that only HOT can rewrite.
  The detector is now narrower: it ignores reduced false-positive families where the inner prefix already contains a clearly separate void root before the later `br_if`.
  Covered by perf test `remove-unused-brs skips structured return ladders when a false prefix guard candidate cannot rewrite`.
- `run_hot_pipeline_raw_remove_unused_brs_has_condition_child_value_if_candidate(...)`
  Cancels the raw structured-return skip if a condition-child value-`if` rewrite still exists.
- `run_hot_pipeline_raw_remove_unused_brs_has_hot_only_candidates(...)`
  Prevents the decision-ladder raw rewrite from skipping lift when other HOT-only candidates remain.
- `run_hot_pipeline_instr_has_remove_unused_brs_candidate(...)`
  Final raw "anything interesting left?" gate.

Detailed page:
- [`./visit-order-and-bailouts.md`](./visit-order-and-bailouts.md)

## HOT No-Op Skip Patterns

- `remove_unused_brs_can_skip_large_br_table_return_ladder(...)`
  Recognizes lifted large `br_table` / return ladders with no `br_if`, dense void-`if` traffic, and no observed rewrite surface worth traversing.
  Covered by perf test `remove-unused-brs skips large br_table return ladders after lift`.
- `remove_unused_brs_can_skip_large_tagged_result_prefix_ladder(...)`
  Recognizes lifted large carried result-prefix ladders with many tagged non-`Block` prefix roots that repeatedly fail the direct result-prefix rewrite and still exit unchanged.
  Covered by perf test `remove-unused-brs skips large tagged result-prefix ladders after lift`.
- `remove_unused_brs_can_skip_medium_branchy_block_ladder(...)`
  Recognizes the later lifted medium branchy block-ladder family that still paid full HOT traversal even though the canonical artifact functions exited unchanged.
  Covered by CLI test `run_cmd_with_adapter traces remove-unused-brs medium branchy hot skip on extracted debug artifact func 1547`.
- `remove_unused_brs_can_skip_call_heavy_mixed_if_mesh(...)`
  Recognizes the later lifted call-heavy mixed-if mesh family that still paid full HOT traversal even though the canonical artifact functions exited unchanged.
  Covered by CLI test `run_cmd_with_adapter traces remove-unused-brs call-heavy mixed-if mesh hot skip on extracted debug artifact func 408`.
- `remove_unused_brs_can_skip_localset_heavy_value_if_mesh(...)`
  Recognizes the later lifted localset-heavy value-if mesh family that still paid full HOT traversal even though the canonical artifact functions exited unchanged.
  Covered by CLI test `run_cmd_with_adapter traces remove-unused-brs localset-heavy value-if mesh hot skip on extracted debug artifact func 3021`.
- `remove_unused_brs_can_skip_large_void_return_ladder(...)`
  Recognizes older large lifted no-op families that still pay lift cost but should not enter the full RUB walk.
  Covered by perf tests:
  - `remove-unused-brs skips large void-if return ladders after lift`
  - `remove-unused-brs skips single-root value-if ladders after lift`
  - `remove-unused-brs skips nested constructor ladders after lift`

Detailed page:
- [`./visit-order-and-bailouts.md`](./visit-order-and-bailouts.md)

## HOT Tail And Return Cleanup Patterns

- `remove_unused_brs_try_remove_region_tail(...)`
  Removes a terminal `br` or `return` when the enclosing region already falls to the same destination.
  Handles both stack-style payload roots and repeated child payloads.
  Covered by:
  - `removes trailing branch to the enclosing block`
  - `removes trailing return at function exit`
  - `removes trailing multi-value branch to the enclosing block`
  - `removes trailing multi-value return at function exit`
- `remove_unused_brs_try_strip_tail_if_exits(...)`
  When both arms of a tail `if` already end in the same removable exit, strip the duplicated exits from the arms and leave the `if`.
- `remove_unused_brs_try_strip_return_context_tail(...)`
  Removes trailing `return` structure in return context when the tail already carries exactly the enclosing result payload.
  Covered by:
  - `strips nested returns inside root returned loops`
  - `strips nested multi-value returns in root return context`
  - `detects nested multi-value root return context`
  - `strips nested returned scalar wrapper blocks`
- `remove_unused_brs_try_voidify_tail_return_if(...)`
  Turns a tail `return (if ...)` family into a void `if` plus `unreachable` once both arms already exit and payload discipline is preserved.
  Covered by:
  - `voidifies tail return-wrapped ifs whose arms already break away`
  - `voidifies multi-value tail return-wrapped ifs`
  - `voidifies nested tail return-wrapped if ladders`
- `remove_unused_brs_try_voidify_exit_only_value_if(...)`
  Voidifies a one-result `if` whose only surviving use chain leads directly into exit traffic through allowed wrappers like `local.tee`.
  Covered by:
  - `voidifies result ifs whose arms only return under drop`
  - `voidifies dropped exit-only ifs through local.tee wrappers`
- `remove_unused_brs_trim_trailing_nops(...)`
  Deletes trailing `nop` roots, but intentionally preserves:
  - a single root-level `nop`
  - a single `nop` that is the entire body of an `if` arm

Detailed page:
- [`./tail-and-return-cleanups.md`](./tail-and-return-cleanups.md)

## HOT Select And Condition Patterns

- `remove_unused_brs_try_rewrite_value_if_to_select(...)`
  Rewrites one-result `if` nodes into `select` when the condition and value arms satisfy the pass's reorder-safety rules.
  Covered by:
  - `rewrites pure value if into select`
  - `rewrites pure const ifs into select`
  - `rewrites const-arm ifs into select even with local.tee conditions`
  - `rewrites reorder-safe condition ladders into select`
  - `rewrites call-conditioned value ifs under branch conditions into select`
  - `rewrites returned condition ladders with pre-calls into select`
  - `rewrites i64 value ifs with local.tee condition ladders into select`
  - `rewrites pure local.get ifs into select`
- `remove_unused_brs_try_rewrite_condition_child_value_if_to_select(...)`
  Selectifies a condition-child value-`if` that sits under a void outer `if`.
  Covered by:
  - `rewrites nested condition if expressions under branches`
  - perf test `lifts structured return ladders when a condition-child value if still needs select rewriting`
- `remove_unused_brs_try_merge_nested_if_conditions(...)`
  Merges nested one-armed conditions before the later branch cleanup.
  Covered by:
  - `merges nested one-armed if conditions before branching`
  - `flattens else-if ladders with embedded value-if conditions`
- `remove_unused_brs_try_fold_constant_br_if(...)`
  Folds root `br_if` nodes with constant conditions, including payload-carrying forms where the final child is the condition and earlier children are the branch/fallthrough payload. False conditions splice the payload into the region; true conditions become a plain payload `br`.
  Covered by:
  - `folds constant br-if conditions`
  - `folds constant br-if with carried payloads`
- `remove_unused_brs_try_rewrite_br_if_eq_ladder_to_br_table(...)`
  Collapses repeated `br_if (local == const)` ladders to a `br_table` when all branches target the same label and the constant range stays small.
  Covered by:
  - `rewrites repeated branch-target equality ladders into br_table`
- `remove_unused_brs_try_rewrite_one_sided_stack_tail_if_to_select(...)`
  Builds a `select` when only one arm ends in a removable stack-style branch/return and the other arm already yields a direct value expression.
  Covered by:
  - `rewrites one-sided stack-style tail branch ifs into select`
  - `rewrites one-sided tail return ifs into select`
- `remove_unused_brs_try_rewrite_tail_value_if_simple_payload_arm(...)`
  Wraps an earlier region prefix in a new result block so one simple branch arm can become a block-local `select`-friendly payload form.
  Covered by:
  - `simplifies block-carried one-arm payload branches into value selection`
  - the returned-ladder select regressions for side-effectful scalar arms

Detailed page:
- [`./select-and-condition-rewrites.md`](./select-and-condition-rewrites.md)

## HOT Branch-Exit And Payload Patterns

- `remove_unused_brs_try_rewrite_if_br(...)`
  Converts one-armed `if br` into `br_if`, including a nested-`br_if` case where both conditions can be combined safely.
  Covered by:
  - `rewrites one-armed if break into br_if`
- `remove_unused_brs_try_inline_single_br_if_block(...)`
  Inlines a void block that only contains a single `br` or `br_if` and whose label is otherwise unused.
- `remove_unused_brs_try_rewrite_region_local_set_copy_arm(...)`
  Rewrites `local.set (if cond then value else local.get same_local)` into a one-armed `if` that only performs the `local.set` when needed.
  Covered by:
  - `rewrites local.set if copy arms into one-armed ifs`
- `remove_unused_brs_try_rewrite_region_local_set_br_arm(...)`
  Rewrites `local.set (if cond then br else value)` into `br_if` plus the surviving `local.set`.
  Covered by:
  - `rewrites local.set if break arms into br_if plus set`
- `remove_unused_brs_try_rewrite_two_arm_branch_if(...)`
  Rewrites `if { br X } else { br Y }` into `br_if X cond; br Y`, or a single `br` if both arms target the same label.
  Covered by:
  - `rewrites two-armed branch exits into br_if plus branch`
  - `rewrites branch-exit ifs even when neither target is the immediate holder`
  - `rewrites branch-exit ifs nested in dropped multi-value blocks`
  - `drains long runs of two-armed branch exits in one region`
- `remove_unused_brs_try_rewrite_one_arm_payload_branch_if(...)`
  Rewrites a one-arm payload branch `if` into `drop(br_if payload)` plus fallthrough body.
  Deliberately disabled when the current function contains any `br_table`; the reduced `Func 3771` family proved Binaryen keeps that direct payload-branch `if` conservative in that wider function context.
  Covered by:
  - `rewrites one-arm payload branch ladders into br_if plus fallthrough`
  - `remove-unused-brs keeps one-arm payload branch ifs in br_table functions`
- `remove_unused_brs_try_rewrite_branch_payload_if(...)`
  Rewrites an `if` that itself sits inside the payload list of an outer `br`.
  Covered by:
  - `rewrites branch payload ifs with branching else arms`
  - `rewrites multi-value branch payload ifs`
  - `rewrites nested simple payload ifs under branch payload arms`
  - `voidifies nested branch-exit ifs inside branch payload arms`
  - `voidifies nested branch-exit ifs inside local.set payload arms`
- `remove_unused_brs_try_rewrite_tail_value_if_branch_exit(...)`
  Rewrites a tail value-`if` when one arm exits by plain branch and the other contributes the fallthrough payload.
  Covered by:
  - `strips stack-style branch exits from tail value if arms`
  - `strips stack-style returns from tail value if arms`
- `remove_unused_brs_try_rewrite_return_child_if_branch_exit(...)`
  Descends into returned value-`if` children to apply branch-exit cleanup beneath explicit `Return`.
  Covered by:
  - `rewrites payload ifs inside returned loop bodies`
  - `flattens nested returned ladder branch exits`
- `remove_unused_brs_try_flatten_block_if_chain(...)` and `remove_unused_brs_flatten_block_if_chains(...)`
  Flatten block-local `if` chains once earlier rewrites have exposed direct block/holder structure.
  Covered by:
  - `flattens block-local if-else break chains into br_if`
  - `flattens block-local if chains when the else arm breaks`

Detailed page:
- [`./branch-exit-and-payload-rewrites.md`](./branch-exit-and-payload-rewrites.md)

## HOT Carried-Guard And Result-Block Patterns

- `remove_unused_brs_try_rewrite_prefixed_one_arm_payload_branch_if_suffix(...)`
  Rewrites a result-block suffix where earlier roots stay in place and a later one-arm payload branch can become `drop(br_if ...)`.
  Covered by:
  - `rewrites prefixed one-arm payload branches into br_if plus fallthrough`
- `remove_unused_brs_try_rewrite_result_block_prefix_payload_branch(...)`
  Rewrites the result-block carrier family where an inner void block starts with `br_if` to itself and ends with an outer payload `br`.
  Covered by:
  - `rewrites result-block br_if prefixes into one-arm payload ifs`
  - `rewrites result-block br_if prefixes with payload bodies into one-arm payload ifs`
  - `rewrites stack-style branch-payload result wrappers around br_if prefixes`
  - `rewrites sibling-carried branch payload wrappers around br_if prefixes`
- `remove_unused_brs_try_rewrite_br_table_continuation_wrappers(...)`
  Retargets nested continuation-wrapper `br_table` arms directly to the outer exit when the wrapper labels are only referenced by that `br_table`, then lowers the now-dead forwarding tails to `unreachable`.
  Covered by:
  - `retargets br_table continuation wrappers to the outer exit`
  - perf test `remove-unused-brs rewrites br_table continuation wrappers in one mutation`
- `remove_unused_brs_try_rewrite_drop_result_block_if_tail_branch(...)`
  Splits `drop(block(result T) (if ...) (br target ...))` into the dropped `if` plus dropped branch payload, removing the extra result wrapper.
- `remove_unused_brs_try_rewrite_block_prefix_payload_branch_root(...)`
  Rewrites a void block root whose body starts with `br_if` to its own label and later exits the enclosing region with payload.
  Covered by:
  - `rewrites sibling carried guard blocks into one-arm ifs`
  - `rewrites carried guard blocks into one-arm ifs under result blocks`
  - `rewrites dropped result-block guard carriers into one-arm ifs`
  - `rewrites dropped result-block guard carriers under local.set`
  - `rewrites prefixed dropped carried guards inside then arms`
  - `rewrites sibling carried guards with removable self tails`
  - `lowers carried guard blocks in result-block then arms`
  - CLI test `run_cmd_with_adapter dumps lowered remove-unused-brs carried guard wrappers without br_if`
  The matcher now fails fast before label-ref or self-tail analysis when the first inner root is not even a `br_if`.
- `remove_unused_brs_try_rewrite_result_block_one_arm_payload_if(...)`
  Rewrites the simple direct one-arm payload-`if` result-block family into a value-producing `if`.
  It deliberately preserves the prefix-heavy carried-wrapper oracle family that Binaryen still keeps.
  Covered by:
  - `simplifies block-carried one-arm payload branches into value selection`
  - `preserves prefix-heavy block-carried one-arm payload wrappers for oracle parity`
  The related result-prefix matcher now also fails fast before label-ref and payload-holder work when the inner prefix does not start with `br_if`.

Detailed page:
- [`./carried-guards-and-result-blocks.md`](./carried-guards-and-result-blocks.md)

## HOT Structural Reshaping Patterns

- `remove_unused_brs_try_restructure_one_arm_return_if_suffix(...)`
  Moves a suffix into an explicit `else` arm when the `then` arm is only `return` and the suffix already exits the enclosing block.
  Covered by:
  - `restructures one-arm return ifs with nonfallthrough suffixes into else arms`
  - `restructures loop-body one-arm return ifs with nonfallthrough suffixes into else arms`
- `remove_unused_brs_try_restructure_one_exit_arm_if_suffix(...)`
  Moves a suffix into the fallthrough arm when exactly one arm is nonfallthrough.
  Covered by:
  - `restructures loop-body one-exit-arm ifs with carried self tails into fallthrough arms`
- `remove_unused_brs_try_sink_if_arm_self_branch_block(...)`
  Sinks a self-target branch out of an `if` arm into an arm-local wrapper block so the explicit `br` disappears.
  Covered by:
  - `sinks self-target if-arm block branches into arm-local wrappers`
- `remove_unused_brs_try_rotate_void_block_single_loop(...)`
  Rotates a trivial `block -> loop` wrapper into `loop -> block` form when the loop body contains no nested value control.
  Covered by:
  - `rotates void block wrappers around single loop bodies`
  - `keeps single-loop block wrappers when the loop body has nested value control`

Detailed pages:
- [`./branch-exit-and-payload-rewrites.md`](./branch-exit-and-payload-rewrites.md)
- [`./returned-ladder-hot-shapes.md`](./returned-ladder-hot-shapes.md)

## HOT-Only Shape Recognition And Deliberate Preservation

- `remove_unused_brs_can_skip_large_void_return_ladder(...)`
  HOT skip for giant no-op families after lift.
- `remove_unused_brs_can_skip_medium_branchy_block_ladder(...)`
  HOT skip for the later medium-size branchy unchanged family retired from the canonical debug artifact.
- `remove_unused_brs_region_tail_control_payload_count(...)`
  Shared legality check for stack-style payload stripping.
- `remove_unused_brs_has_safe_exit_only_value_if_use_chain(...)`
  Single-use proof for exit-only value-`if` voidification.
- `remove_unused_brs_compute_cycle_scan(...)`
  Shared per-cycle legality scan for label references, branch-payload children, and the piggybacked `has_br_table` parity bit.

Detailed pages:
- [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md)
- [`./visit-order-and-bailouts.md`](./visit-order-and-bailouts.md)
