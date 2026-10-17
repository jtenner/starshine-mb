// Dedicated artifacts: exact full field equality, bounded failure messages.

///|
fn dae_boundary_syntax_artifact_assert_snapshot(
  actual : DaeOriginalBoundarySnapshot,
  expected : DaeOriginalBoundarySnapshot,
) -> Unit raise {
  assert_true(actual.imported == expected.imported, msg="imported")
  assert_true(actual.defined == expected.defined, msg="defined")
  assert_true(actual.total == expected.total, msg="total")
  assert_true(actual.type_indices == expected.type_indices, msg="type_indices")
  assert_true(actual.escaped == expected.escaped, msg="escaped")
  assert_true(
    actual.exposure.length() == expected.exposure.length(),
    msg="exposure.length()",
  )
  for idx in 0..<actual.exposure.length() {
    assert_true(
      actual.exposure[idx].imported == expected.exposure[idx].imported,
      msg="exposure[\{idx}].imported",
    )
    assert_true(
      actual.exposure[idx].exported == expected.exposure[idx].exported,
      msg="exposure[\{idx}].exported",
    )
    assert_true(
      actual.exposure[idx].start == expected.exposure[idx].start,
      msg="exposure[\{idx}].start",
    )
    assert_true(
      actual.exposure[idx].ref_func_body == expected.exposure[idx].ref_func_body,
      msg="exposure[\{idx}].ref_func_body",
    )
    assert_true(
      actual.exposure[idx].ref_func_module ==
      expected.exposure[idx].ref_func_module,
      msg="exposure[\{idx}].ref_func_module",
    )
    assert_true(
      actual.exposure[idx].active_element ==
      expected.exposure[idx].active_element,
      msg="exposure[\{idx}].active_element",
    )
    assert_true(
      actual.exposure[idx].passive_element ==
      expected.exposure[idx].passive_element,
      msg="exposure[\{idx}].passive_element",
    )
    assert_true(
      actual.exposure[idx].declarative_element ==
      expected.exposure[idx].declarative_element,
      msg="exposure[\{idx}].declarative_element",
    )
  }
  assert_true(actual.param_counts == expected.param_counts, msg="param_counts")
  assert_true(
    actual.large_unreachable_prefixes == expected.large_unreachable_prefixes,
    msg="large_unreachable_prefixes",
  )
  assert_true(
    actual.call_summary.call_counts == expected.call_summary.call_counts,
    msg="call_summary.call_counts",
  )
  assert_true(
    actual.call_summary.prior_call_counts ==
    expected.call_summary.prior_call_counts,
    msg="call_summary.prior_call_counts",
  )
  assert_true(
    actual.call_summary.nonself_undropped_call_counts ==
    expected.call_summary.nonself_undropped_call_counts,
    msg="call_summary.nonself_undropped_call_counts",
  )
  assert_true(
    actual.call_summary.active_nonself_call_counts ==
    expected.call_summary.active_nonself_call_counts,
    msg="call_summary.active_nonself_call_counts",
  )
  assert_true(
    actual.call_summary.active_parameterized_nonself_call_counts ==
    expected.call_summary.active_parameterized_nonself_call_counts,
    msg="call_summary.active_parameterized_nonself_call_counts",
  )
  assert_true(
    actual.call_summary.active_parameterized_result_nonself_call_counts ==
    expected.call_summary.active_parameterized_result_nonself_call_counts,
    msg="call_summary.active_parameterized_result_nonself_call_counts",
  )
  assert_true(
    actual.call_summary.prior_undropped_call_counts ==
    expected.call_summary.prior_undropped_call_counts,
    msg="call_summary.prior_undropped_call_counts",
  )
  assert_true(
    actual.call_summary.self_call_counts ==
    expected.call_summary.self_call_counts,
    msg="call_summary.self_call_counts",
  )
  assert_true(
    actual.private_result_dead_suffix_call_counts ==
    expected.private_result_dead_suffix_call_counts,
    msg="private_result_dead_suffix_call_counts",
  )
  assert_true(
    actual.private_result_same_operand_call_counts ==
    expected.private_result_same_operand_call_counts,
    msg="private_result_same_operand_call_counts",
  )
  assert_true(
    actual.escaped_result_operand_call_facts.dead_suffix_escaped_result_operand_call_counts ==
    expected.escaped_result_operand_call_facts.dead_suffix_escaped_result_operand_call_counts,
    msg="escaped_result_operand_call_facts.dead_suffix_escaped_result_operand_call_counts",
  )
  assert_true(
    actual.escaped_result_operand_call_facts.private_result_escaped_operand_call_counts ==
    expected.escaped_result_operand_call_facts.private_result_escaped_operand_call_counts,
    msg="escaped_result_operand_call_facts.private_result_escaped_operand_call_counts",
  )
  assert_true(
    actual.private_result_dead_suffix_calls_from_escaped_operand_callees ==
    expected.private_result_dead_suffix_calls_from_escaped_operand_callees,
    msg="private_result_dead_suffix_calls_from_escaped_operand_callees",
  )
  assert_true(
    actual.escaped_dead_suffix_call_counts ==
    expected.escaped_dead_suffix_call_counts,
    msg="escaped_dead_suffix_call_counts",
  )
  assert_true(
    actual.escaped_undropped_dead_suffix_call_counts ==
    expected.escaped_undropped_dead_suffix_call_counts,
    msg="escaped_undropped_dead_suffix_call_counts",
  )
  assert_true(
    actual.dead_suffix_other_calls == expected.dead_suffix_other_calls,
    msg="dead_suffix_other_calls",
  )
  assert_true(
    actual.dead_suffix_undropped_self_calls ==
    expected.dead_suffix_undropped_self_calls,
    msg="dead_suffix_undropped_self_calls",
  )
  assert_true(
    actual.dead_suffix_dropped_self_calls ==
    expected.dead_suffix_dropped_self_calls,
    msg="dead_suffix_dropped_self_calls",
  )
  assert_true(
    actual.dead_suffix_block_undropped_self_calls ==
    expected.dead_suffix_block_undropped_self_calls,
    msg="dead_suffix_block_undropped_self_calls",
  )
  assert_true(
    actual.dead_suffix_dropped_self_call_full_param_forwards ==
    expected.dead_suffix_dropped_self_call_full_param_forwards,
    msg="dead_suffix_dropped_self_call_full_param_forwards",
  )
  assert_true(
    actual.dead_suffix_result_calls_from_undropped_self_callers ==
    expected.dead_suffix_result_calls_from_undropped_self_callers,
    msg="dead_suffix_result_calls_from_undropped_self_callers",
  )
  assert_true(
    actual.dead_suffix_result_calls_from_no_param_undropped_self_callers ==
    expected.dead_suffix_result_calls_from_no_param_undropped_self_callers,
    msg="dead_suffix_result_calls_from_no_param_undropped_self_callers",
  )
  assert_true(
    actual.dead_suffix_undropped_calls_from_parameterized_dropped_self_callers ==
    expected.dead_suffix_undropped_calls_from_parameterized_dropped_self_callers,
    msg="dead_suffix_undropped_calls_from_parameterized_dropped_self_callers",
  )
  assert_true(
    actual.dead_suffix_dropped_calls_from_parameterized_self_callers ==
    expected.dead_suffix_dropped_calls_from_parameterized_self_callers,
    msg="dead_suffix_dropped_calls_from_parameterized_self_callers",
  )
  assert_true(
    actual.dead_suffix_dropped_calls_from_no_param_result_callers ==
    expected.dead_suffix_dropped_calls_from_no_param_result_callers,
    msg="dead_suffix_dropped_calls_from_no_param_result_callers",
  )
  assert_true(
    actual.dead_suffix_mixed_dropped_undropped_call_counts ==
    expected.dead_suffix_mixed_dropped_undropped_call_counts,
    msg="dead_suffix_mixed_dropped_undropped_call_counts",
  )
  assert_true(
    actual.dead_suffix_dropped_earlier_result_calls ==
    expected.dead_suffix_dropped_earlier_result_calls,
    msg="dead_suffix_dropped_earlier_result_calls",
  )
  assert_true(
    actual.later_dead_suffix_dropped_call_counts ==
    expected.later_dead_suffix_dropped_call_counts,
    msg="later_dead_suffix_dropped_call_counts",
  )
  assert_true(
    actual.dead_suffix_same_self_result_operand_calls ==
    expected.dead_suffix_same_self_result_operand_calls,
    msg="dead_suffix_same_self_result_operand_calls",
  )
  assert_true(
    actual.dead_suffix_undropped_self_call_param_operands ==
    expected.dead_suffix_undropped_self_call_param_operands,
    msg="dead_suffix_undropped_self_call_param_operands",
  )
  assert_true(
    actual.dead_suffix_calls_from_param_operand_self_result_callers ==
    expected.dead_suffix_calls_from_param_operand_self_result_callers,
    msg="dead_suffix_calls_from_param_operand_self_result_callers",
  )
  assert_true(
    actual.dead_suffix_result_other_calls ==
    expected.dead_suffix_result_other_calls,
    msg="dead_suffix_result_other_calls",
  )
  assert_true(
    actual.dead_suffix_self_recursive_void_side_calls ==
    expected.dead_suffix_self_recursive_void_side_calls,
    msg="dead_suffix_self_recursive_void_side_calls",
  )
  assert_true(
    actual.dead_suffix_self_recursive_result_side_calls ==
    expected.dead_suffix_self_recursive_result_side_calls,
    msg="dead_suffix_self_recursive_result_side_calls",
  )
  assert_true(
    actual.dead_suffix_escaped_result_call_facts.dropped_calls ==
    expected.dead_suffix_escaped_result_call_facts.dropped_calls,
    msg="dead_suffix_escaped_result_call_facts.dropped_calls",
  )
  assert_true(
    actual.dead_suffix_escaped_result_call_facts.undropped_calls ==
    expected.dead_suffix_escaped_result_call_facts.undropped_calls,
    msg="dead_suffix_escaped_result_call_facts.undropped_calls",
  )
  assert_true(
    actual.dead_suffix_mutual_calls == expected.dead_suffix_mutual_calls,
    msg="dead_suffix_mutual_calls",
  )
}

///|
fn dae_boundary_syntax_artifact_load(path : String) -> @lib.Module {
  let bytes = @sfs.read_file_bytes(path).unwrap()
  @binary.decode_module(bytes).unwrap()
}

///|
fn dae_boundary_syntax_artifact_phases(size : String) -> Unit raise {
  let root = "/home/dev/Projects/starshine-mb/.tmp/dae-speed-20261016"
  let original = dae_boundary_syntax_artifact_load(
    "\{root}/inputs/\{size}.wasm",
  )
  @validate.validate_module(original).unwrap()
  let original_bytes = @binary.encode_module(original).unwrap()
  let retained = dae_collect_original_boundary_snapshot(original)
  let retained_reference = dae_boundary_syntax_frozen_collect_original_boundary_snapshot(
    original,
  )
  dae_boundary_syntax_artifact_assert_snapshot(retained, retained_reference)
  assert_true(
    @binary.encode_module(original).unwrap() == original_bytes,
    msg="original ownership after first snapshot",
  )
  for pass_name in ["dae", "dae-optimizing"] {
    // Saved c474 CLI outputs are independent later sources. No whole pass runs
    // here, and the original semantic boundary must remain unchanged.
    let current = dae_boundary_syntax_artifact_load(
      "\{root}/iteration11/primary-clock-suite/command-\{size}/\{pass_name}-starshine.wasm",
    )
    @validate.validate_module(current).unwrap()
    let current_bytes = @binary.encode_module(current).unwrap()
    assert_false(
      current_bytes == original_bytes,
      msg="fixture must contain a real saved post-pass source",
    )
    let actual = dae_collect_original_boundary_snapshot(current)
    let expected = dae_boundary_syntax_frozen_collect_original_boundary_snapshot(
      current,
    )
    dae_boundary_syntax_artifact_assert_snapshot(actual, expected)
    assert_true(
      @binary.encode_module(current).unwrap() == current_bytes,
      msg="current source ownership after both collectors",
    )
    dae_boundary_syntax_artifact_assert_snapshot(retained, retained_reference)
    // Rebuild a reference too: equality of two retained alias objects alone
    // would not detect a common accidental mutation of both first snapshots.
    dae_boundary_syntax_artifact_assert_snapshot(
      retained,
      dae_boundary_syntax_frozen_collect_original_boundary_snapshot(original),
    )
    assert_true(
      @binary.encode_module(original).unwrap() == original_bytes,
      msg="original source ownership after later phase",
    )
  }
}

///|
#skip("whole small artifact all-field differential across saved source phases; dedicated native lane")
test "artifact DAE boundary syntax all fields small original and S11 post-pass sources" {
  dae_boundary_syntax_artifact_phases("small")
}

///|
#skip("whole large artifact all-field differential across saved source phases; dedicated native lane")
test "artifact DAE boundary syntax all fields large original and S11 post-pass sources" {
  dae_boundary_syntax_artifact_phases("large")
}
