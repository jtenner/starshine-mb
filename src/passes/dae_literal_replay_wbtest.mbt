///|
fn dae_literal_replay_fixture_run(
  mod_ : @lib.Module,
  original_boundary_snapshot : DaeOriginalBoundarySnapshot,
  original_builds : Array[Int],
  reference? : Bool = false,
) -> DaePassResult {
  let original_param_counts = original_boundary_snapshot.param_counts
  let original_call_summary = original_boundary_snapshot.call_summary
  let original_call_counts = original_call_summary.call_counts
  let original_active_nonself_call_counts = original_call_summary.active_nonself_call_counts
  let original_active_parameterized_nonself_call_counts = original_call_summary.active_parameterized_nonself_call_counts
  let original_nonself_undropped_call_counts = original_call_summary.nonself_undropped_call_counts
  let original_self_call_counts = original_call_summary.self_call_counts
  let original_dead_suffix_escaped_result_call_facts = original_boundary_snapshot.dead_suffix_escaped_result_call_facts
  let original_escaped_result_operand_call_facts = original_boundary_snapshot.escaped_result_operand_call_facts
  let original_dead_suffix_escaped_result_operand_call_counts = original_escaped_result_operand_call_facts.dead_suffix_escaped_result_operand_call_counts
  let original_private_result_dead_suffix_calls_from_escaped_operand_callees = original_boundary_snapshot.private_result_dead_suffix_calls_from_escaped_operand_callees
  let original_escaped_dead_suffix_call_counts = original_boundary_snapshot.escaped_dead_suffix_call_counts
  let original_dead_suffix_undropped_self_calls = original_boundary_snapshot.dead_suffix_undropped_self_calls
  let original_dead_suffix_dropped_self_calls = original_boundary_snapshot.dead_suffix_dropped_self_calls
  let original_dead_suffix_block_undropped_self_calls = original_boundary_snapshot.dead_suffix_block_undropped_self_calls
  let original_dead_suffix_result_calls_from_undropped_self_callers = original_boundary_snapshot.dead_suffix_result_calls_from_undropped_self_callers
  let original_dead_suffix_result_calls_from_no_param_undropped_self_callers = original_boundary_snapshot.dead_suffix_result_calls_from_no_param_undropped_self_callers
  let original_dead_suffix_dropped_calls_from_parameterized_self_callers = original_boundary_snapshot.dead_suffix_dropped_calls_from_parameterized_self_callers
  let original_dead_suffix_same_self_result_operand_calls = original_boundary_snapshot.dead_suffix_same_self_result_operand_calls
  let original_dead_suffix_undropped_self_call_param_operands = original_boundary_snapshot.dead_suffix_undropped_self_call_param_operands
  let original_dead_suffix_result_other_calls = original_boundary_snapshot.dead_suffix_result_other_calls
  let original_dead_suffix_mutual_calls = original_boundary_snapshot.dead_suffix_mutual_calls
  let original_dead_suffix_calls_from_param_operand_self_result_callers = original_boundary_snapshot.dead_suffix_calls_from_param_operand_self_result_callers
  if reference {
    dae_literal_replay_reference(
      mod_, original_param_counts, original_call_counts, original_active_nonself_call_counts,
      original_active_parameterized_nonself_call_counts, original_nonself_undropped_call_counts,
      original_self_call_counts, original_private_result_dead_suffix_calls_from_escaped_operand_callees,
      original_escaped_dead_suffix_call_counts, original_dead_suffix_undropped_self_calls,
      original_dead_suffix_dropped_self_calls, original_dead_suffix_block_undropped_self_calls,
      original_dead_suffix_result_calls_from_undropped_self_callers, original_dead_suffix_result_calls_from_no_param_undropped_self_callers,
      original_dead_suffix_same_self_result_operand_calls, original_dead_suffix_undropped_self_call_param_operands,
      original_dead_suffix_result_other_calls, original_dead_suffix_escaped_result_call_facts,
      original_dead_suffix_mutual_calls, original_dead_suffix_calls_from_param_operand_self_result_callers,
      original_dead_suffix_escaped_result_operand_call_counts, original_dead_suffix_dropped_calls_from_parameterized_self_callers,
    )
  } else {
    dae_try_rewrite_reverse_exact_literal_once(
      mod_,
      original_param_counts,
      original_call_counts,
      original_active_nonself_call_counts,
      original_active_parameterized_nonself_call_counts,
      original_nonself_undropped_call_counts,
      original_self_call_counts,
      original_private_result_dead_suffix_calls_from_escaped_operand_callees,
      original_escaped_dead_suffix_call_counts,
      original_dead_suffix_undropped_self_calls,
      original_dead_suffix_dropped_self_calls,
      original_dead_suffix_block_undropped_self_calls,
      original_dead_suffix_result_calls_from_undropped_self_callers,
      original_dead_suffix_result_calls_from_no_param_undropped_self_callers,
      original_dead_suffix_same_self_result_operand_calls,
      original_dead_suffix_undropped_self_call_param_operands,
      original_dead_suffix_result_other_calls,
      original_dead_suffix_escaped_result_call_facts,
      original_dead_suffix_mutual_calls,
      original_dead_suffix_calls_from_param_operand_self_result_callers,
      original_dead_suffix_escaped_result_operand_call_counts,
      original_dead_suffix_dropped_calls_from_parameterized_self_callers,
      original_snapshot_builds=Some(original_builds),
    )
  }
}

///|
test "DAE literal replay avoids unused snapshots while preserving a nonconstant call" {
  let mod_ = pass_test_module_from_wat(
    "(module (func $id (param i32) (result i32) local.get 0) (func (export \"run\") (param i32) (result i32) local.get 0 call $id))",
  )
  let original = dae_collect_original_boundary_snapshot(mod_)
  let original_builds = [0]
  let result = dae_literal_replay_fixture_run(mod_, original, original_builds)
  assert_false(result.changed)
  assert_eq(result.mod_out, mod_)
  assert_eq(original_builds[0], 0)
}

///|
test "DAE literal replay builds candidate facts and retains exact rewrite output" {
  let mod_ = pass_test_module_from_wat(
    "(module (func $id (param i32) (result i32) local.get 0) (func (export \"run\") (result i32) i32.const 7 call $id))",
  )
  let original = dae_collect_original_boundary_snapshot(mod_)
  let original_builds = [0]
  let result = dae_literal_replay_fixture_run(mod_, original, original_builds)
  let expected = dae_literal_replay_fixture_run(
    mod_,
    original,
    [0],
    reference=true,
  )
  assert_true(result.changed)
  assert_eq(result.mod_out, expected.mod_out)
  assert_eq(result.touched, expected.touched)
  assert_eq(result.primary_def, expected.primary_def)
  assert_eq(original_builds[0], 1)
  @validate.validate_module(result.mod_out).unwrap()
}
