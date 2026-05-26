# DAE003 constant-actual and unread-parameter inventory

## Scope

This note closes the inventory-only `[DAE003-A]` backlog subtask. It maps the currently supported `dae-optimizing` constant-actual and unread-parameter families to implementation helpers, focused tests or trace surfaces, and prior research notes so later DAE003 work can target only unclosed breadth.

No pass behavior changes were made in this slice.

## Current generic constant-actual machinery

- Uniform materialized constants are compared by `dae_materialized_const_equal(...)` in `src/passes/dead_argument_elimination.mbt`. The supported materialized values are `i32.const`, `i64.const`, `f32.const`, `f64.const`, `ref.null`, `string.const`, and `global.get` equality by global index.
- `dae_collect_uniform_const_actuals_with_facts(...)` / `dae_collect_uniform_const_actuals_visited(...)` collect same-value actuals from the current direct-caller facts. The scanner descends into `block`, `loop`, `try_table`, and `if` bodies using block entry-stack accounting, but the actual value shape at a callsite must be a single instruction after `dae_collect_callsite_shapes(...)` has isolated the argument slice.
- `dae_resolve_uniform_const_candidate(...)` accepts a direct materializable constant, or a forwarded `local.get` resolved through `dae_resolve_forwarded_uniform_const_local_get(...)`. Forwarded resolution bails out for escaped callers, tail-call callers, imported/unavailable callers, self-recursive callers, non-param locals, and written locals. This is the current safe subset for non-adjacent local forwarding.
- Immutable `global.get` support is opt-in through `allow_immutable_global_get=true`, guarded by `dae_global_get_is_immutable(...)` / `dae_instr_is_materializable_const_with_immutable_global(...)`. The generic default path does not admit mutable or unknown globals.
- `dae_try_rewrite_reverse_exact_literal_once(...)` is the exploratory generic pass over private direct callees. It removes read-only parameters whose current direct callers all provide the same exact materialized value, while separately tracking unread parameters as a dead-param condition.
- `dae_try_rewrite_selected_defs_exact_literal_with_facts_once(...)` applies the same exact-literal proof to selected definitions with a caller-facts snapshot. It is the implementation hook for most artifact-selected literal lanes.

## Current generic unread-parameter machinery

- `dae_local_use_for_callee(...)` supplies parameter read/write information. Parameters with no `local.get` use are removable unread parameters.
- `dae_try_rewrite_selected_defs_unread_params_with_facts_once(...)` handles selected private direct callees with no escape, no tail calls, at least one direct call, and no selected self-caller. It removes parameters that are unread by the callee and lets `dae_try_rewrite_candidate(...)` repair signatures and call operands.
- The low-callee, low-wrapper-callee, boundary-wrapper-callee, selected-unread, selected-Func538, and selected-forwarded-wrapper lanes in `dae_run_core(...)` are all selected scheduling surfaces over that same unread-parameter helper.

## Implemented scheduling surfaces and selected families

| Family | Implementation surface | Current guard / scope | Tests or evidence |
| --- | --- | --- | --- |
| Small-module reverse exact literals | `dae_try_rewrite_reverse_exact_literal_once(...)` from `dae_run_core(...)` | `original_defined <= 1024`, up to 8 reverse productive rewrites | Earlier DAE002 notes and focused exact-literal tests in `src/passes/dae_optimizing_test.mbt` |
| Mid-size low-forwarded-const revisit | `dae_try_rewrite_reverse_exact_literal_once(..., reverse=false, max_def_exclusive=4096)` | `original_defined <= 4096`, up to 64 productive rewrites over first 4096 defs | `dae-optimizing materializes high fact-discovered exact literal outside selected list`; research note `0606` |
| Large-artifact high-wrapper exact-literal chain | `dae_try_rewrite_selected_defs_exact_literal_with_facts_once(...)` over defs `4593, 4592, 4591, 4589, 4588, 4587, 4586, 4584` | Large modules only; selected list avoids whole-artifact reverse scans | Notes `0567`-`0569`, strategy page high-wrapper discussion |
| Low direct-callee unread params | `dae_collect_direct_callee_defs_from_caller_prefix(current, 64)` + `dae_try_rewrite_selected_defs_unread_params_with_facts_once(...)` | Up to 14 productive low-callee rewrites from the first 64 caller defs | Note `0569`; trace `pass[dae-optimizing]:low-callee-core` |
| Low shifted-wrapper unread params | `dae_collect_shifted_forward_wrapper_callee_defs(current, 64, 128)` + unread helper | Up to 21 productive low-wrapper rewrites | Strategy page low-wrapper/high-callee family; trace `low-wrapper-callee-core` |
| Boundary wrapper/callee unread params | `dae_find_shifted_forward_wrapper_callee_def(...)` over wrapper defs `128..196` listed in `dae_run_core(...)` | Fixed wrapper family, revalidated against current module before each selected rewrite | Trace `boundary-wrapper-callee-core`; backlog DAE003 selected lanes |
| Selected literal/unread defs | Selected defs `505`, `3799`, `538`, mid literals `267,268,287,288,311,408,428,504,505,538,869,1777,4206,4368`, and high literals `1720,1755,1775,1794,2156,3736,3799,4117,4134,4303,4320` | Artifact-specific selected scheduling; some defs refresh call facts after earlier rewrites | Notes `0576`-`0585` for Func505; backlog current checkpoints |
| Immutable global exact literal | `dae_try_rewrite_selected_defs_exact_literal_with_facts_once(..., allow_immutable_global_get=true)` for def `313` | Selected global lane only; immutable globals accepted, mutable/unknown globals rejected | Strategy page `mid-global-exact-literal`; DAE003-G remains open for broader coverage |
| Selected default/suffix argument families | `dae_try_rewrite_selected_defs_exact_literal_with_facts_once(...)` for defs `326`, `327`, `328`, `1795`; `dae_try_specialize_selected_single_i32_suffix_default_arg_once(...)` for def `3765` | Selected artifact defaults, with exact call-count/caller guard for the `3737 -> 3765` forwarded default | Notes around selected artifact lanes; trace `selected-func327-default-args`, `selected-forwarded-default-args` |
| Func3737 forwarded wrapper fallback | `dae_try_remove_func3737_wrapper_suffix_param_once(...)`, falling back to unread helper | Selected wrapper pair only; exact shape/caller checks | Trace `selected-func3737-wrapper-param` / `selected-forwarded-wrapper-unread-param` |

## Focused test map

The durable behavior tests for this inventory live primarily in `src/passes/dae_optimizing_test.mbt` and the helper-level white-box coverage in `src/passes/dead_argument_elimination_wbtest.mbt` / `src/passes/pass_manager_wbtest.mbt`. Search strings that identify the active DAE003 surface include:

- `dae-optimizing materializes high fact-discovered exact literal outside selected list`
- exact-literal and constant-actual tests covering same-literal direct callers, scalar memory-load sibling carriers, and typed single-result `TypeIdxBlockType` wrappers
- unread-param selected-lane traces such as `low-callee-core`, `low-wrapper-callee-core`, `selected-unread-before-literals`, and `selected-func538-unread`
- immutable-global / selected-global traces such as `mid-global-exact-literal`
- selected default-argument traces such as `selected-func327-default-args`, `selected-func328-default-args`, `selected-func1795-default-args`, `selected-forwarded-default-args`, and `selected-func3737-wrapper-param`

## Remaining DAE003 gaps after this inventory

- `[DAE003-B]`: reproduce and classify current artifact/frontier misses that are truly due to constant-actual or unread-parameter materialization, excluding representation-only, lowerer, raw-cleanup, and result-removal drift.
- `[DAE003-C]`: broaden non-adjacent forwarding beyond the current single-instruction actual plus guarded forwarded-`local.get` subset.
- `[DAE003-D]`: handle localized `A -> B -> C` forwarding chains with starvation-aware ordering instead of fixed selected lanes.
- `[DAE003-E]`: define the safe recursive/self-recursive constant/unread subset without reopening case-000690 escaped-self operand hazards.
- `[DAE003-F]`: broaden structured carriers where the actual value is represented through block/loop/if/try_table or typed wrappers rather than a single isolated instruction.
- `[DAE003-G]`: broaden immutable-global/materialized-constant handling beyond selected lanes with type/liveness guard coverage.
- `[DAE003-H]`: revisit fixed iteration budgets using bounded ordering/worklist evidence and pass-local timing.
- `[DAE003-I]`: close DAE003 only after artifact replay and direct fuzz show no remaining current frontier is attributable to missed safe constant/unread materialization.

## Validation

- `git diff --check`
- `moon info`
- `moon fmt`
- `moon test`

Because this was an inventory/documentation slice only, no compare-pass fuzz run was required and no mismatch classification changed.
