///|
/// Pre-review startup collector control.
fn dae_review_original_snapshot_reference(
  mod_ : @lib.Module,
) -> DaeOriginalBoundarySnapshot {
  let imported = dae_imported_func_count(mod_)
  let defined = dae_defined_func_count(mod_)
  let total = imported + defined
  let type_indices = dae_collect_func_type_indices(mod_)
  let exposure = dae_collect_original_exposure(mod_, total, type_indices)
  let escaped = dae_exposure_to_escaped(exposure)
  let param_counts = dae_collect_original_param_counts_with_type_indices(
    mod_, type_indices,
  )
  let call_summary = dae_collect_original_call_summary_with_context(
    mod_, imported, defined, type_indices, escaped,
  )
  // This temporary belongs only to the borrowed bodies of this invocation.
  // Discover roots lazily so the existing predicate and failure order stays.
  let first_roots : Array[Int32]? = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) if funcs.length() == defined =>
      Some(Array::make(defined, -2))
    _ => None
  }
  let private_result_dead_suffix_call_counts = dae_collect_original_private_result_dead_suffix_call_counts_with_escaped(
    mod_,
    call_summary.call_counts,
    escaped,
    first_roots~,
  )
  let private_result_same_operand_call_counts = dae_collect_original_private_result_same_operand_call_counts_with_escaped(
    mod_, escaped,
  )
  let dead_suffix_escaped_result_call_facts = dae_collect_original_dead_suffix_escaped_result_call_facts_with_escaped(
    mod_,
    escaped,
    first_roots~,
  )
  let escaped_result_operand_call_facts = dae_collect_original_escaped_result_operand_call_facts_with_escaped(
    mod_, escaped, dead_suffix_escaped_result_call_facts,
  )
  let private_result_dead_suffix_calls_from_escaped_operand_callees = dae_collect_original_private_result_dead_suffix_calls_from_escaped_operand_callees(
    mod_,
    escaped_result_operand_call_facts.dead_suffix_escaped_result_operand_call_counts,
    first_roots~,
  )
  let escaped_dead_suffix_call_counts = dae_collect_original_escaped_dead_suffix_call_counts_with_escaped(
    mod_,
    escaped,
    first_roots~,
  )
  let escaped_undropped_dead_suffix_call_counts = dae_collect_original_escaped_undropped_dead_suffix_call_counts_with_escaped(
    mod_,
    escaped,
    first_roots~,
  )
  let dead_suffix_other_calls = dae_collect_original_dead_suffix_other_calls(
    mod_,
    first_roots~,
  )
  let dead_suffix_undropped_self_calls = dae_collect_original_dead_suffix_undropped_self_calls(
    mod_,
    first_roots~,
  )
  let dead_suffix_dropped_self_calls = dae_collect_original_dead_suffix_dropped_self_calls(
    mod_,
    first_roots~,
  )
  let dead_suffix_block_undropped_self_calls = dae_collect_original_dead_suffix_block_undropped_self_calls(
    mod_,
  )
  let dead_suffix_dropped_self_call_full_param_forwards = dae_collect_original_dead_suffix_dropped_self_call_full_param_forwards(
    mod_,
  )
  let dead_suffix_result_calls_from_undropped_self_callers = dae_collect_original_dead_suffix_result_calls_from_undropped_self_callers_with_escaped(
    mod_,
    call_summary.nonself_undropped_call_counts,
    escaped,
    first_roots~,
  )
  let dead_suffix_result_calls_from_no_param_undropped_self_callers = dae_collect_original_dead_suffix_result_calls_from_no_param_undropped_self_callers(
    mod_,
    first_roots~,
  )
  let dead_suffix_undropped_calls_from_parameterized_dropped_self_callers = dae_collect_original_dead_suffix_undropped_calls_from_parameterized_dropped_self_callers(
    mod_,
    first_roots~,
  )
  let dead_suffix_dropped_calls_from_parameterized_self_callers = dae_collect_original_dead_suffix_dropped_calls_from_parameterized_self_callers(
    mod_,
    first_roots~,
  )
  let dead_suffix_dropped_calls_from_no_param_result_callers = dae_collect_original_dead_suffix_dropped_calls_from_no_param_result_callers(
    mod_,
    first_roots~,
  )
  let dead_suffix_mixed_dropped_undropped_call_counts = dae_collect_original_dead_suffix_mixed_dropped_undropped_call_counts_with_escaped(
    mod_,
    escaped,
    first_roots~,
  )
  let dead_suffix_dropped_earlier_result_calls = dae_collect_original_dead_suffix_dropped_earlier_result_calls(
    mod_,
    first_roots~,
  )
  let later_dead_suffix_dropped_call_counts = dae_collect_original_later_dead_suffix_dropped_call_counts(
    mod_,
    first_roots~,
  )
  let dead_suffix_same_self_result_operand_calls = dae_collect_original_dead_suffix_same_self_result_operand_calls(
    mod_,
  )
  let dead_suffix_undropped_self_call_param_operands = dae_collect_original_dead_suffix_undropped_self_call_param_operands(
    mod_,
    first_roots~,
  )
  let dead_suffix_result_other_calls = dae_collect_original_dead_suffix_result_other_calls_with_escaped(
    mod_,
    escaped,
    first_roots~,
  )
  let dead_suffix_self_recursive_void_side_calls = dae_collect_original_dead_suffix_self_recursive_void_side_calls(
    mod_,
    first_roots~,
    original_self_call_counts=Some(call_summary.self_call_counts),
  )
  let dead_suffix_self_recursive_result_side_calls = dae_collect_original_dead_suffix_self_recursive_result_side_calls(
    mod_,
    first_roots~,
  )
  let dead_suffix_mutual_calls = dae_review_mutual_reference(mod_, first_roots~)
  let dead_suffix_calls_from_param_operand_self_result_callers = dae_review_suffix_count_reference(
    mod_,
    param_counts,
    call_summary.call_counts,
    call_summary.active_nonself_call_counts,
    call_summary.active_parameterized_nonself_call_counts,
    call_summary.nonself_undropped_call_counts,
    call_summary.self_call_counts,
    escaped_dead_suffix_call_counts,
    dead_suffix_undropped_self_calls,
    dead_suffix_undropped_self_call_param_operands,
    dead_suffix_result_other_calls,
    dead_suffix_mutual_calls,
    first_roots~,
  )
  {
    imported,
    defined,
    total,
    type_indices,
    escaped,
    exposure,
    param_counts,
    large_unreachable_prefixes: dae_collect_original_large_unreachable_prefixes(
      mod_,
    ),
    call_summary,
    private_result_dead_suffix_call_counts,
    private_result_same_operand_call_counts,
    escaped_result_operand_call_facts,
    private_result_dead_suffix_calls_from_escaped_operand_callees,
    escaped_dead_suffix_call_counts,
    escaped_undropped_dead_suffix_call_counts,
    dead_suffix_other_calls,
    dead_suffix_undropped_self_calls,
    dead_suffix_dropped_self_calls,
    dead_suffix_block_undropped_self_calls,
    dead_suffix_dropped_self_call_full_param_forwards,
    dead_suffix_result_calls_from_undropped_self_callers,
    dead_suffix_result_calls_from_no_param_undropped_self_callers,
    dead_suffix_undropped_calls_from_parameterized_dropped_self_callers,
    dead_suffix_dropped_calls_from_parameterized_self_callers,
    dead_suffix_dropped_calls_from_no_param_result_callers,
    dead_suffix_mixed_dropped_undropped_call_counts,
    dead_suffix_dropped_earlier_result_calls,
    later_dead_suffix_dropped_call_counts,
    dead_suffix_same_self_result_operand_calls,
    dead_suffix_undropped_self_call_param_operands,
    dead_suffix_calls_from_param_operand_self_result_callers,
    dead_suffix_result_other_calls,
    dead_suffix_self_recursive_void_side_calls,
    dead_suffix_self_recursive_result_side_calls,
    dead_suffix_escaped_result_call_facts,
    dead_suffix_mutual_calls,
  }
}
