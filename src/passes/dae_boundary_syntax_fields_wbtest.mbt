///|
fn dae_boundary_syntax_assert_snapshot(
  actual : DaeOriginalBoundarySnapshot,
  expected : DaeOriginalBoundarySnapshot,
) -> Unit raise {
  assert_eq(actual.imported, expected.imported)
  assert_eq(actual.defined, expected.defined)
  assert_eq(actual.total, expected.total)
  assert_eq(actual.type_indices, expected.type_indices)
  assert_eq(actual.escaped, expected.escaped)
  assert_eq(actual.exposure.length(), expected.exposure.length())
  for idx in 0..<actual.exposure.length() {
    assert_eq(actual.exposure[idx].imported, expected.exposure[idx].imported)
    assert_eq(actual.exposure[idx].exported, expected.exposure[idx].exported)
    assert_eq(actual.exposure[idx].start, expected.exposure[idx].start)
    assert_eq(
      actual.exposure[idx].ref_func_body,
      expected.exposure[idx].ref_func_body,
    )
    assert_eq(
      actual.exposure[idx].ref_func_module,
      expected.exposure[idx].ref_func_module,
    )
    assert_eq(
      actual.exposure[idx].active_element,
      expected.exposure[idx].active_element,
    )
    assert_eq(
      actual.exposure[idx].passive_element,
      expected.exposure[idx].passive_element,
    )
    assert_eq(
      actual.exposure[idx].declarative_element,
      expected.exposure[idx].declarative_element,
    )
  }
  assert_eq(actual.param_counts, expected.param_counts)
  assert_eq(
    actual.large_unreachable_prefixes,
    expected.large_unreachable_prefixes,
  )
  assert_eq(actual.call_summary.call_counts, expected.call_summary.call_counts)
  assert_eq(
    actual.call_summary.prior_call_counts,
    expected.call_summary.prior_call_counts,
  )
  assert_eq(
    actual.call_summary.nonself_undropped_call_counts,
    expected.call_summary.nonself_undropped_call_counts,
  )
  assert_eq(
    actual.call_summary.active_nonself_call_counts,
    expected.call_summary.active_nonself_call_counts,
  )
  assert_eq(
    actual.call_summary.active_parameterized_nonself_call_counts,
    expected.call_summary.active_parameterized_nonself_call_counts,
  )
  assert_eq(
    actual.call_summary.active_parameterized_result_nonself_call_counts,
    expected.call_summary.active_parameterized_result_nonself_call_counts,
  )
  assert_eq(
    actual.call_summary.prior_undropped_call_counts,
    expected.call_summary.prior_undropped_call_counts,
  )
  assert_eq(
    actual.call_summary.self_call_counts,
    expected.call_summary.self_call_counts,
  )
  assert_eq(
    actual.private_result_dead_suffix_call_counts,
    expected.private_result_dead_suffix_call_counts,
  )
  assert_eq(
    actual.private_result_same_operand_call_counts,
    expected.private_result_same_operand_call_counts,
  )
  assert_eq(
    actual.escaped_result_operand_call_facts.dead_suffix_escaped_result_operand_call_counts,
    expected.escaped_result_operand_call_facts.dead_suffix_escaped_result_operand_call_counts,
  )
  assert_eq(
    actual.escaped_result_operand_call_facts.private_result_escaped_operand_call_counts,
    expected.escaped_result_operand_call_facts.private_result_escaped_operand_call_counts,
  )
  assert_eq(
    actual.private_result_dead_suffix_calls_from_escaped_operand_callees,
    expected.private_result_dead_suffix_calls_from_escaped_operand_callees,
  )
  assert_eq(
    actual.escaped_dead_suffix_call_counts,
    expected.escaped_dead_suffix_call_counts,
  )
  assert_eq(
    actual.escaped_undropped_dead_suffix_call_counts,
    expected.escaped_undropped_dead_suffix_call_counts,
  )
  assert_eq(actual.dead_suffix_other_calls, expected.dead_suffix_other_calls)
  assert_eq(
    actual.dead_suffix_undropped_self_calls,
    expected.dead_suffix_undropped_self_calls,
  )
  assert_eq(
    actual.dead_suffix_dropped_self_calls,
    expected.dead_suffix_dropped_self_calls,
  )
  assert_eq(
    actual.dead_suffix_block_undropped_self_calls,
    expected.dead_suffix_block_undropped_self_calls,
  )
  assert_eq(
    actual.dead_suffix_dropped_self_call_full_param_forwards,
    expected.dead_suffix_dropped_self_call_full_param_forwards,
  )
  assert_eq(
    actual.dead_suffix_result_calls_from_undropped_self_callers,
    expected.dead_suffix_result_calls_from_undropped_self_callers,
  )
  assert_eq(
    actual.dead_suffix_result_calls_from_no_param_undropped_self_callers,
    expected.dead_suffix_result_calls_from_no_param_undropped_self_callers,
  )
  assert_eq(
    actual.dead_suffix_undropped_calls_from_parameterized_dropped_self_callers,
    expected.dead_suffix_undropped_calls_from_parameterized_dropped_self_callers,
  )
  assert_eq(
    actual.dead_suffix_dropped_calls_from_parameterized_self_callers,
    expected.dead_suffix_dropped_calls_from_parameterized_self_callers,
  )
  assert_eq(
    actual.dead_suffix_dropped_calls_from_no_param_result_callers,
    expected.dead_suffix_dropped_calls_from_no_param_result_callers,
  )
  assert_eq(
    actual.dead_suffix_mixed_dropped_undropped_call_counts,
    expected.dead_suffix_mixed_dropped_undropped_call_counts,
  )
  assert_eq(
    actual.dead_suffix_dropped_earlier_result_calls,
    expected.dead_suffix_dropped_earlier_result_calls,
  )
  assert_eq(
    actual.later_dead_suffix_dropped_call_counts,
    expected.later_dead_suffix_dropped_call_counts,
  )
  assert_eq(
    actual.dead_suffix_same_self_result_operand_calls,
    expected.dead_suffix_same_self_result_operand_calls,
  )
  assert_eq(
    actual.dead_suffix_undropped_self_call_param_operands,
    expected.dead_suffix_undropped_self_call_param_operands,
  )
  assert_eq(
    actual.dead_suffix_calls_from_param_operand_self_result_callers,
    expected.dead_suffix_calls_from_param_operand_self_result_callers,
  )
  assert_eq(
    actual.dead_suffix_result_other_calls,
    expected.dead_suffix_result_other_calls,
  )
  assert_eq(
    actual.dead_suffix_self_recursive_void_side_calls,
    expected.dead_suffix_self_recursive_void_side_calls,
  )
  assert_eq(
    actual.dead_suffix_self_recursive_result_side_calls,
    expected.dead_suffix_self_recursive_result_side_calls,
  )
  assert_eq(
    actual.dead_suffix_escaped_result_call_facts.dropped_calls,
    expected.dead_suffix_escaped_result_call_facts.dropped_calls,
  )
  assert_eq(
    actual.dead_suffix_escaped_result_call_facts.undropped_calls,
    expected.dead_suffix_escaped_result_call_facts.undropped_calls,
  )
  assert_eq(actual.dead_suffix_mutual_calls, expected.dead_suffix_mutual_calls)
}
