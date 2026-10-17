///|
test "DAE candidate effects retain exact result plan and source ownership" {
  let (input, output) = dae_signature_plan_metadata_fixture(2)
  let input_bytes = @binary.encode_module(input).unwrap()
  let output_bytes = @binary.encode_module(output).unwrap()
  let graph = dae_current_boundary_graph_new(input)
  let touched = [true, true, false, false]
  let candidate : DaePassResult = {
    mod_out: output,
    touched,
    changed: true,
    primary_def: 0,
  }
  let dependencies = dae_boundary_dependency_graph_new(graph)
  for
    family in [
      DaeUnusedParameterWork,
      DaeUniformActualWork,
      DaeLocalizationRetryWork,
      DaeGcParameterRefinementWork,
      DaePostCleanupBoundaryRevisitWork,
      DaeGcResultRefinementWork,
      DaeDroppedResultWork,
      DaeTypeRepairRetryWork,
      DaeControlReconstructionWork,
      DaeBodyCleanupWork,
      DaeForwardingWork,
    ] {
    let item = dae_work_item_new(graph, dependencies, 0, family)
    let actual = dae_work_item_candidate_effects(input, graph, item, candidate)
    assert_eq(
      actual,
      dae_candidate_effects_reference(input, graph, item, candidate),
    )
    assert_true(actual.result_removed[0])
    assert_true(actual.invalidation_domains.contains(DaeInvalidateCalls))
    let plan = dae_build_signature_rewrite_plan_from_candidate(
      dae_collect_original_boundary_snapshot(input),
      input,
      graph,
      0,
      candidate,
      actual,
    ).unwrap()
    let applied = dae_apply_rewrite_plan(input, graph, plan)
    assert_true(applied.applied)
    assert_eq(
      @binary.encode_module(applied.result.mod_out).unwrap(),
      output_bytes,
    )
    actual.structurally_touched[2] = true
    assert_false(touched[2])
    assert_false(graph.snapshot.call_facts.tail_calls[0])
  }
  assert_eq(@binary.encode_module(input).unwrap(), input_bytes)
  assert_eq(@binary.encode_module(output).unwrap(), output_bytes)
}

///|
test "DAE candidate effects preserve imported slots nested calls escapes and tail calls" {
  let input = pass_test_module_from_wat(
    "(module (type $i (func (param i32) (result i32))) " +
    "(import \"m\" \"f\" (func $external (type $i))) " +
    "(func $target (type $i) local.get 0) (elem declare func $target) " +
    "(func (export \"run\") (param i32) (result i32) " +
    "local.get 0 if i32.const 4 call $target drop end ref.func $target drop " +
    "local.get 0 return_call $target unreachable i32.const 5 call $target drop))",
  )
  let output = pass_test_module_from_wat(
    "(module (type $i (func (param i32) (result i32))) " +
    "(import \"m\" \"f\" (func $external (type $i))) " +
    "(func $target (result i32) i32.const 3) (elem declare func $target) " +
    "(func (export \"run\") (param i32) (result i32) " +
    "local.get 0 if call $target drop end ref.func $target drop " +
    "return_call $target unreachable call $target drop))",
  ).without_name_sec()
  @validate.validate_module(input).unwrap()
  @validate.validate_module(output).unwrap()
  let graph = dae_current_boundary_graph_new(input)
  let item = dae_work_item_new(
    graph,
    dae_boundary_dependency_graph_new(graph),
    0,
    DaeUniformActualWork,
  )
  let candidate : DaePassResult = {
    mod_out: output,
    touched: [true, true],
    changed: true,
    primary_def: 0,
  }
  let actual = dae_work_item_candidate_effects(input, graph, item, candidate)
  assert_eq(
    actual,
    dae_candidate_effects_reference(input, graph, item, candidate),
  )
  assert_eq(actual.parameter_changed, [true, false])
  assert_eq(actual.body_materialized, [true, false])
  assert_false(actual.result_changed[0])
  assert_false(actual.invalidation_domains.contains(DaeInvalidateCalls))
  assert_true(graph.snapshot.call_facts.escaped[1])
  assert_true(graph.snapshot.call_facts.tail_calls[1])
  assert_eq(graph.snapshot.call_facts.direct_callers[1], [1])
}

///|
test "DAE candidate effects preserve GC refinement and exact invalidation order" {
  let input = pass_test_module_from_wat(
    "(module (type $base (sub (struct))) (type $leaf (sub $base (struct))) " +
    "(func $target (param (ref null $base)) (result (ref null $base)) local.get 0) " +
    "(func (export \"run\") (result i32) struct.new $leaf call $target ref.is_null))",
  )
  let saved = @binary.encode_module(input).unwrap()
  let graph = dae_current_boundary_graph_new(input)
  let candidate = dae_try_refine_direct_gc_types_for_def_with_facts(
    input,
    0,
    graph.snapshot.call_facts,
    true,
    true,
  )
  assert_true(candidate.changed)
  let item = dae_work_item_new(
    graph,
    dae_boundary_dependency_graph_new(graph),
    0,
    DaeGcParameterRefinementWork,
  )
  let actual = dae_work_item_candidate_effects(input, graph, item, candidate)
  assert_eq(
    actual,
    dae_candidate_effects_reference(input, graph, item, candidate),
  )
  assert_true(actual.parameter_type_refined[0])
  assert_true(actual.result_changed[0])
  assert_false(actual.result_removed[0])
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  let plan = dae_build_signature_rewrite_plan_from_candidate(
    dae_collect_original_boundary_snapshot(input),
    input,
    graph,
    0,
    candidate,
    actual,
  ).unwrap()
  let applied = dae_apply_rewrite_plan(input, graph, plan)
  assert_true(applied.applied)
  @validate.validate_module(applied.result.mod_out).unwrap()
}

///|
test "DAE candidate effects keep no-change and missing-section handling" {
  let (input, output) = dae_signature_plan_metadata_fixture(0)
  let graph = dae_current_boundary_graph_new(input)
  let item = dae_work_item_new(
    graph,
    dae_boundary_dependency_graph_new(graph),
    0,
    DaeBodyCleanupWork,
  )
  let inactive : DaePassResult = {
    mod_out: output,
    touched: [true, true],
    changed: false,
    primary_def: 0,
  }
  assert_eq(
    dae_work_item_candidate_effects(input, graph, item, inactive),
    dae_commit_effects_empty(2),
  )
  // Missing code and type sections are intentionally invalid as a replacement.
  // Effect collection must still match the original collector before validation.
  let missing : DaePassResult = {
    mod_out: pass_test_module_from_wat("(module)"),
    touched: [true],
    changed: true,
    primary_def: 0,
  }
  assert_eq(
    dae_work_item_candidate_effects(input, graph, item, missing),
    dae_candidate_effects_reference(input, graph, item, missing),
  )
}
