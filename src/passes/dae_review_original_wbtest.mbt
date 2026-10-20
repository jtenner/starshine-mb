///|
fn dae_review_assert_original_snapshots(input : @lib.Module) -> Unit raise {
  let actual = dae_collect_original_boundary_snapshot(input)
  let expected = dae_review_original_snapshot_reference(input)
  assert_eq(actual.imported, expected.imported)
  assert_eq(actual.defined, expected.defined)
  assert_eq(actual.total, expected.total)
  assert_eq(actual.type_indices, expected.type_indices)
  assert_eq(actual.escaped, expected.escaped)
  assert_eq(actual.param_counts, expected.param_counts)
  assert_eq(
    actual.large_unreachable_prefixes,
    expected.large_unreachable_prefixes,
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
  assert_eq(actual.dead_suffix_mutual_calls, expected.dead_suffix_mutual_calls)
  assert_eq(
    actual.escaped_result_operand_call_facts.dead_suffix_escaped_result_operand_call_counts,
    expected.escaped_result_operand_call_facts.dead_suffix_escaped_result_operand_call_counts,
  )
  assert_eq(
    actual.dead_suffix_escaped_result_call_facts.dropped_calls,
    expected.dead_suffix_escaped_result_call_facts.dropped_calls,
  )
  assert_eq(
    actual.dead_suffix_escaped_result_call_facts.undropped_calls,
    expected.dead_suffix_escaped_result_call_facts.undropped_calls,
  )
}

///|
test "DAE shared original type indices retain boundary collector facts" {
  for
    source in [
      "(module (func $a (param i32) (result i32) local.get 0) (func (export \"run\") (result i32) i32.const 7 call $a))",
      "(module (func $a (param i32) (result i32) unreachable local.get 0 call $a drop i32.const 7 call $b) (func $b (param i32) (result i32) unreachable local.get 0 call $a))",
    ] {
    dae_review_assert_original_snapshots(pass_test_module_from_wat(source))
  }
}

///|
fn dae_review_original_bench(
  it : @bench.T,
  reference : Bool,
  long_body~ : Bool = false,
) -> Unit raise {
  let padding = if long_body {
    Array::make(64, "local.get 0 drop").join(" ")
  } else {
    ""
  }
  let funcs = Array::makei(128, fn(index) {
    "(func $f\{index} (param i32) (result i32) \{padding} local.get 0)"
  }).join(" ")
  let input = pass_test_module_from_wat("(module \{funcs})")
  dae_review_assert_original_snapshots(input)
  it.bench(fn() {
    it.keep(
      if reference {
        dae_review_original_snapshot_reference(input)
      } else {
        dae_collect_original_boundary_snapshot(input)
      },
    )
  })
}

///|
#skip("paired native controls; dedicated performance lane")
test "bench DAE original 128 functions pre-review reference" (it : @bench.T) {
  dae_review_original_bench(it, true)
}

///|
#skip("paired native controls; dedicated performance lane")
test "bench DAE original 128 functions shared type indices" (it : @bench.T) {
  dae_review_original_bench(it, false)
}

///|
#skip("paired native controls; dedicated performance lane")
test "bench DAE original long bodies pre-review reference" (it : @bench.T) {
  dae_review_original_bench(it, true, long_body=true)
}

///|
#skip("paired native controls; dedicated performance lane")
test "bench DAE original long bodies shared root and type indices" (
  it : @bench.T,
) {
  dae_review_original_bench(it, false, long_body=true)
}
