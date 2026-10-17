///|
fn row_assert_snapshot(
  actual : DaeOriginalBoundarySnapshot,
  expected : DaeOriginalBoundarySnapshot,
) -> Unit raise {
  assert_eq(actual.imported, expected.imported)
  assert_eq(actual.defined, expected.defined)
  assert_eq(actual.total, expected.total)
  assert_eq(actual.type_indices, expected.type_indices)
  assert_eq(actual.escaped, expected.escaped)
  assert_eq(actual.exposure.length(), expected.exposure.length())
  for index in 0..<actual.exposure.length() {
    assert_eq(
      actual.exposure[index].imported,
      expected.exposure[index].imported,
    )
    assert_eq(
      actual.exposure[index].exported,
      expected.exposure[index].exported,
    )
    assert_eq(actual.exposure[index].start, expected.exposure[index].start)
    assert_eq(
      actual.exposure[index].ref_func_body,
      expected.exposure[index].ref_func_body,
    )
    assert_eq(
      actual.exposure[index].ref_func_module,
      expected.exposure[index].ref_func_module,
    )
    assert_eq(
      actual.exposure[index].active_element,
      expected.exposure[index].active_element,
    )
    assert_eq(
      actual.exposure[index].passive_element,
      expected.exposure[index].passive_element,
    )
    assert_eq(
      actual.exposure[index].declarative_element,
      expected.exposure[index].declarative_element,
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

///|
fn row_fixture_same() -> @lib.Module {
  pass_test_module_from_wat(
    "(module (func $t (param i32) (result i32) local.get 0) " +
    "(func (result i32) unreachable i32.const 1 call $t call $t call $t) " +
    "(func (result i32) unreachable i32.const 2 call $t call $t) " +
    "(func (export \"run\") (result i32) i32.const 7 call $t))",
  )
}

///|
fn row_fixture_escaped() -> @lib.Module {
  pass_test_module_from_wat(
    "(module (import \"m\" \"source\" (func $source (result i32))) " +
    "(func $t (param i32) (result i32) local.get 0) " +
    "(func (result i32) unreachable call $source call $t drop call $source call $t) " +
    "(func (export \"run\") (result i32) unreachable call $source call $t drop call $source call $t))",
  )
}

///|
fn row_check_input(input : @lib.Module) -> Unit raise {
  @validate.validate_module(input).unwrap()
  let before = @binary.encode_module(input).unwrap()
  let actual = dae_collect_original_boundary_snapshot(input)
  let expected = row_ref_dae_collect_original_boundary_snapshot(input)
  row_assert_snapshot(actual, expected)
  row_check_probe_projection(input, actual)
  assert_eq(
    dae_collect_original_private_result_same_operand_call_counts_with_escaped(
      input,
      actual.escaped,
    ),
    row_ref_dae_collect_original_private_result_same_operand_call_counts_with_escaped(
      input,
      expected.escaped,
    ),
  )
  let a = dae_collect_original_escaped_result_operand_call_facts_with_escaped(
    input,
    actual.escaped,
    actual.dead_suffix_escaped_result_call_facts,
  )
  let b = row_ref_dae_collect_original_escaped_result_operand_call_facts_with_escaped(
    input,
    expected.escaped,
    expected.dead_suffix_escaped_result_call_facts,
  )
  assert_eq(
    a.dead_suffix_escaped_result_operand_call_counts,
    b.dead_suffix_escaped_result_operand_call_counts,
  )
  assert_eq(
    a.private_result_escaped_operand_call_counts,
    b.private_result_escaped_operand_call_counts,
  )
  for optimize in [false, true] {
    let trace : Array[String] = []
    let reference_trace : Array[String] = []
    let output = dae_run_module_pass(
      input,
      optimize~,
      trace=Some(fn(line) { trace.push(line) }),
    )
    let reference = row_ref_dae_run_module_pass(
      input,
      optimize~,
      trace=Some(fn(line) { reference_trace.push(line) }),
    )
    @validate.validate_module(output).unwrap()
    @validate.validate_module(reference).unwrap()
    assert_eq(output.code_sec, reference.code_sec)
    assert_eq(output.func_sec, reference.func_sec)
    assert_eq(output.type_sec, reference.type_sec)
    assert_eq(
      @binary.encode_module(output).unwrap(),
      @binary.encode_module(reference).unwrap(),
    )
    assert_eq(trace, reference_trace)
    assert_eq(@binary.encode_module(input).unwrap(), before)
  }
}

///|
fn row_check_productive() -> Unit raise {
  let input = pass_test_module_from_wat(
    "(module (import \"m\" \"mark\" (func $mark (param i32))) " +
    "(func $t (param i32) (result i32) local.get 0 call $mark local.get 0) " +
    "(func (export \"run\") (result i32) i32.const 7 call $t))",
  ).with_custom_secs([
    @lib.CustomSec::new(
      @lib.Name::from_string("collector-row-proof"),
      b"bounded-metadata",
    ),
  ])
  @validate.validate_module(input).unwrap()
  let before = @binary.encode_module(input).unwrap()
  row_check_input(input)
  for optimize in [false, true] {
    let trace : Array[String] = []
    let reference_trace : Array[String] = []
    let actual = dae_run_core(input, fn(line) { trace.push(line) }, optimize~)
    let expected = row_ref_dae_run_core(
      input,
      fn(line) { reference_trace.push(line) },
      optimize~,
    )
    assert_true(actual.changed)
    assert_eq(actual.changed, expected.changed)
    assert_eq(actual.primary_def, expected.primary_def)
    assert_eq(actual.touched, expected.touched)
    assert_true(actual.touched[0] && actual.touched[1])
    assert_eq(actual.effects, expected.effects)
    assert_eq(actual.mod_out.custom_secs, input.custom_secs)
    assert_true(actual.effects.parameter_changed[0])
    assert_eq(
      actual.single_caller_throttle_consumed,
      expected.single_caller_throttle_consumed,
    )
    assert_eq(trace, reference_trace)
    assert_eq(actual.mod_out.code_sec, expected.mod_out.code_sec)
    assert_eq(
      @binary.encode_module(actual.mod_out).unwrap(),
      @binary.encode_module(expected.mod_out).unwrap(),
    )
    @validate.validate_module(actual.mod_out).unwrap()
    @validate.validate_module(expected.mod_out).unwrap()
    let indices = dae_collect_func_type_indices(actual.mod_out)
    let @lib.FuncType(params, _) = dae_resolve_func_type(
      actual.mod_out,
      indices,
      1,
    ).unwrap()
    assert_eq(params.length(), 0)
    assert_eq(
      dae_count_module_calls_anywhere_to(actual.mod_out.code_sec.unwrap().0, 0),
      1,
    )
    assert_eq(@binary.encode_module(input).unwrap(), before)
  }
  // The active DAEO adapter owns the shared nested roster. Its reference
  // freezes only the changed collector closure and otherwise retains that
  // exact adapter, options, order, repair and full-validation behavior.
  let trace : Array[String] = []
  let reference_trace : Array[String] = []
  let output = run_hot_pipeline_apply_dae_optimizing_module_pass(
    input,
    HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
  ).unwrap()
  let reference = row_ref_run_hot_pipeline_apply_dae_optimizing_module_pass(
    input,
    HotPipelineOptions::new(trace=Some(fn(line) { reference_trace.push(line) })),
  ).unwrap()
  assert_eq(trace, reference_trace)
  assert_eq(output.code_sec, reference.code_sec)
  assert_eq(
    @binary.encode_module(output).unwrap(),
    @binary.encode_module(reference).unwrap(),
  )
  @validate.validate_module(output).unwrap()
  @validate.validate_module(reference).unwrap()
  for pass in ["dae", "dae-optimizing"] {
    let output = run_hot_pipeline(input, HotPipelineOptions::new(), [pass]).unwrap()
    let reference = if pass == "dae" {
      row_ref_dae_run_module_pass(input)
    } else {
      row_ref_run_hot_pipeline_apply_dae_optimizing_module_pass(
        input,
        HotPipelineOptions::new(),
      ).unwrap()
    }
    @validate.validate_module(output).unwrap()
    @validate.validate_module(reference).unwrap()
    assert_eq(output.code_sec, reference.code_sec)
    assert_eq(output.func_sec, reference.func_sec)
    assert_eq(output.type_sec, reference.type_sec)
    assert_eq(
      @binary.encode_module(output).unwrap(),
      @binary.encode_module(reference).unwrap(),
    )
    assert_eq(
      dae_count_module_calls_anywhere_to(output.code_sec.unwrap().0, 0),
      1,
    )
    assert_eq(@binary.encode_module(input).unwrap(), before)
  }
}

///|
fn row_check_probe_projection(
  input : @lib.Module,
  snapshot : DaeOriginalBoundarySnapshot,
) -> Unit raise {
  let saved = @binary.encode_module(input).unwrap()
  let normal_same = dae_collect_original_private_result_same_operand_call_counts_with_escaped(
    input,
    snapshot.escaped,
  )
  let probe_same = row_probe_dae_collect_original_private_result_same_operand_call_counts_with_escaped(
    input,
    snapshot.escaped,
  )
  let old_same = row_ref_dae_collect_original_private_result_same_operand_call_counts_with_escaped(
    input,
    snapshot.escaped,
  )
  assert_eq(normal_same, old_same)
  assert_eq(probe_same, normal_same)
  assert_eq(normal_same, snapshot.private_result_same_operand_call_counts)
  let normal_operand = dae_collect_original_escaped_result_operand_call_facts_with_escaped(
    input,
    snapshot.escaped,
    snapshot.dead_suffix_escaped_result_call_facts,
  )
  let probe_operand = row_probe_dae_collect_original_escaped_result_operand_call_facts_with_escaped(
    input,
    snapshot.escaped,
    snapshot.dead_suffix_escaped_result_call_facts,
  )
  let old_operand = row_ref_dae_collect_original_escaped_result_operand_call_facts_with_escaped(
    input,
    snapshot.escaped,
    snapshot.dead_suffix_escaped_result_call_facts,
  )
  assert_eq(
    normal_operand.dead_suffix_escaped_result_operand_call_counts,
    old_operand.dead_suffix_escaped_result_operand_call_counts,
  )
  assert_eq(
    normal_operand.private_result_escaped_operand_call_counts,
    old_operand.private_result_escaped_operand_call_counts,
  )
  assert_eq(
    probe_operand.dead_suffix_escaped_result_operand_call_counts,
    normal_operand.dead_suffix_escaped_result_operand_call_counts,
  )
  assert_eq(
    probe_operand.private_result_escaped_operand_call_counts,
    normal_operand.private_result_escaped_operand_call_counts,
  )
  assert_eq(
    normal_operand.dead_suffix_escaped_result_operand_call_counts,
    snapshot.escaped_result_operand_call_facts.dead_suffix_escaped_result_operand_call_counts,
  )
  assert_eq(
    normal_operand.private_result_escaped_operand_call_counts,
    snapshot.escaped_result_operand_call_facts.private_result_escaped_operand_call_counts,
  )
  if normal_same.length() > 0 {
    // These are fresh collector results. Mutating either implementation's
    // outputs must not mutate a snapshot, another result, or borrowed bodies.
    normal_same[0] += 1
    probe_same[0] += 1
    normal_operand.dead_suffix_escaped_result_operand_call_counts[0] += 1
    normal_operand.private_result_escaped_operand_call_counts[0] += 1
    probe_operand.dead_suffix_escaped_result_operand_call_counts[0] += 1
    probe_operand.private_result_escaped_operand_call_counts[0] += 1
    assert_eq(
      dae_collect_original_private_result_same_operand_call_counts_with_escaped(
        input,
        snapshot.escaped,
      ),
      old_same,
    )
    assert_eq(
      row_probe_dae_collect_original_private_result_same_operand_call_counts_with_escaped(
        input,
        snapshot.escaped,
      ),
      old_same,
    )
    let fresh_normal = dae_collect_original_escaped_result_operand_call_facts_with_escaped(
      input,
      snapshot.escaped,
      snapshot.dead_suffix_escaped_result_call_facts,
    )
    let fresh_probe = row_probe_dae_collect_original_escaped_result_operand_call_facts_with_escaped(
      input,
      snapshot.escaped,
      snapshot.dead_suffix_escaped_result_call_facts,
    )
    assert_eq(
      fresh_normal.dead_suffix_escaped_result_operand_call_counts,
      old_operand.dead_suffix_escaped_result_operand_call_counts,
    )
    assert_eq(
      fresh_normal.private_result_escaped_operand_call_counts,
      old_operand.private_result_escaped_operand_call_counts,
    )
    assert_eq(
      fresh_probe.dead_suffix_escaped_result_operand_call_counts,
      old_operand.dead_suffix_escaped_result_operand_call_counts,
    )
    assert_eq(
      fresh_probe.private_result_escaped_operand_call_counts,
      old_operand.private_result_escaped_operand_call_counts,
    )
    row_assert_snapshot(
      snapshot,
      row_ref_dae_collect_original_boundary_snapshot(input),
    )
  }
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}
