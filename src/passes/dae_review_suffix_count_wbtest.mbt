///|
fn dae_review_suffix_counts(
  input : @lib.Module,
  facts : DaeOriginalBoundarySnapshot,
  reference : Bool,
) -> Array[Int32] {
  if reference {
    dae_review_suffix_count_reference(
      input,
      facts.param_counts,
      facts.call_summary.call_counts,
      facts.call_summary.active_nonself_call_counts,
      facts.call_summary.active_parameterized_nonself_call_counts,
      facts.call_summary.nonself_undropped_call_counts,
      facts.call_summary.self_call_counts,
      facts.escaped_dead_suffix_call_counts,
      facts.dead_suffix_undropped_self_calls,
      facts.dead_suffix_undropped_self_call_param_operands,
      facts.dead_suffix_result_other_calls,
      facts.dead_suffix_mutual_calls,
    )
  } else {
    dae_collect_original_dead_suffix_calls_from_param_operand_self_result_callers(
      input,
      facts.param_counts,
      facts.call_summary.call_counts,
      facts.call_summary.active_nonself_call_counts,
      facts.call_summary.active_parameterized_nonself_call_counts,
      facts.call_summary.nonself_undropped_call_counts,
      facts.call_summary.self_call_counts,
      facts.escaped_dead_suffix_call_counts,
      facts.dead_suffix_undropped_self_calls,
      facts.dead_suffix_undropped_self_call_param_operands,
      facts.dead_suffix_result_other_calls,
      facts.dead_suffix_mutual_calls,
    )
  }
}

///|
fn dae_review_suffix_count_input(width : Int32) -> @lib.Module {
  let targets = Array::makei(width, fn(index) {
    "(func $v\{index} (result i32) i32.const \{index})"
  }).join(" ")
  let calls = Array::makei(width, fn(index) { "call $v\{index} drop" }).join(
    " ",
  )
  pass_test_module_from_wat(
    "(module (func $self (param i32) (result i32) unreachable \{calls} \{calls} local.get 0 call $self) " +
    "\{targets} (func (export \"run\") i32.const 1 call $self drop))",
  )
}

///|
test "DAE parameter self-call suffix counts retain repeated callee occurrences" {
  let input = dae_review_suffix_count_input(3)
  let facts = dae_collect_original_boundary_snapshot(input)
  let actual = dae_review_suffix_counts(input, facts, false)
  assert_eq(actual, [0, 2, 2, 2, 0])
  assert_eq(actual, dae_review_suffix_counts(input, facts, true))
}

///|
fn dae_review_suffix_count_bench(it : @bench.T, reference : Bool) -> Unit raise {
  let input = dae_review_suffix_count_input(128)
  let facts = dae_collect_original_boundary_snapshot(input)
  let counts = dae_review_suffix_counts(input, facts, false)
  assert_eq(counts, dae_review_suffix_counts(input, facts, true))
  assert_eq(counts[1], 2)
  it.bench(fn() { it.keep(dae_review_suffix_counts(input, facts, reference)) })
}

///|
#skip("paired native controls; dedicated performance lane")
test "bench DAE suffix counts per-callee reference" (it : @bench.T) {
  dae_review_suffix_count_bench(it, true)
}

///|
#skip("paired native controls; dedicated performance lane")
test "bench DAE suffix counts single target walk" (it : @bench.T) {
  dae_review_suffix_count_bench(it, false)
}
