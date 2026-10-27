///|
fn dae_liveness_handoff_fixture(hot : Bool, reads~ : Int32 = 0) -> @lib.Module {
  let read = if hot {
    "block (result i32) local.get 0 br 0 end"
  } else {
    "local.get 0"
  }
  let prefix = StringBuilder()
  for _ in 0..<reads {
    prefix.write_string("local.get 1 drop ")
  }
  pass_test_module_from_wat(
    "(module (func $target (param i32 i32) (result i32) \{prefix.to_string()}i32.const 9 local.set 0 \{read} local.get 1 i32.add) (func (export \"run\") (result i32) i32.const 7 i32.const 11 call $target))",
  ).with_custom_secs([
    @lib.CustomSec::new(@lib.Name::new("liveness.keep"), b"kept"),
  ])
}

///|
fn dae_liveness_handoff_assert_result(
  input : @lib.Module,
  actual : DaePassResult,
  expected : DaePassResult,
) -> Unit raise {
  assert_true(actual.changed)
  assert_eq(actual.changed, expected.changed)
  assert_eq(actual.primary_def, expected.primary_def)
  assert_eq(actual.touched, expected.touched)
  assert_eq(actual.mod_out.custom_secs, input.custom_secs)
  assert_eq(
    @binary.encode_module(actual.mod_out).unwrap(),
    @binary.encode_module(expected.mod_out).unwrap(),
  )
  @validate.validate_module(actual.mod_out).unwrap()
}

///|
test "DAE reused entry masks preserve scalar plans actions and encoded output" {
  for hot in [false, true] {
    let input = dae_liveness_handoff_fixture(hot)
    let saved = @binary.encode_module(input).unwrap()
    let original = dae_collect_original_boundary_snapshot(input)
    let graph = dae_current_boundary_graph_new(input)
    let syntax = dae_local_use_for_callee(graph.snapshot.funcs[0], 2, 0, 2)
    let live = dae_incoming_parameter_liveness(input, 0, 2)
    let expected = dae_build_scalar_unused_param_rewrite_plan(
      input,
      original,
      graph,
      0,
      [true, false],
      syntax,
      1,
      [1],
    ).unwrap()
    let work = [0, 0]
    let actual = dae_build_scalar_unused_param_rewrite_plan(
      input,
      original,
      graph,
      0,
      [true, false],
      syntax,
      1,
      [1],
      entry_live=Some(live),
      liveness_work=Some(work),
    ).unwrap()
    assert_eq(actual.parameter_actions, expected.parameter_actions)
    assert_eq(
      actual.local_projection.local_map,
      expected.local_projection.local_map,
    )
    assert_eq(
      actual.local_projection.preserved_removed_params,
      expected.local_projection.preserved_removed_params,
    )
    assert_eq(actual.replacement_signature, expected.replacement_signature)
    assert_eq(actual.touched_functions, expected.touched_functions)
    assert_eq(
      actual.invalidated_dependencies,
      expected.invalidated_dependencies,
    )
    let application = dae_apply_rewrite_plan(input, graph, actual)
    let reference = dae_apply_rewrite_plan(input, graph, expected)
    assert_true(application.applied)
    assert_eq(application.effects, reference.effects)
    dae_liveness_handoff_assert_result(
      input,
      application.result,
      reference.result,
    )
    assert_eq(dae_wb_param_count(application.result.mod_out, 0), 1)
    assert_eq(work, [0, 0])
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
test "DAE selected unread work reuses masks through scalar and plan fallback routes" {
  for hot in [false, true] {
    for supplied_graph in [false, true] {
      let input = dae_liveness_handoff_fixture(hot)
      let saved = @binary.encode_module(input).unwrap()
      let original = dae_collect_original_boundary_snapshot(input)
      let graph = dae_current_boundary_graph_new(input)
      let original_arg = if supplied_graph { Some(original) } else { None }
      let graph_arg = if supplied_graph { Some(graph) } else { None }
      let expected_effects = []
      let expected = dae_boundary_syntax_frozen_try_rewrite_selected_defs_unread_params_with_facts_once(
        input,
        [true, false],
        graph.snapshot.call_facts,
        original=original_arg,
        graph=graph_arg,
        producer_effects_report=expected_effects,
      )
      let actual_effects = []
      let work = [0, 0]
      let actual = dae_try_rewrite_selected_defs_unread_params_with_facts_once(
        input,
        [true, false],
        graph.snapshot.call_facts,
        original=original_arg,
        graph=graph_arg,
        producer_effects_report=actual_effects,
        liveness_work=Some(work),
      )
      dae_liveness_handoff_assert_result(input, actual, expected)
      assert_eq(actual_effects, expected_effects)
      assert_eq(dae_wb_param_count(actual.mod_out, 0), 1)
      assert_eq(work, [1, 0])
      assert_eq(@binary.encode_module(input).unwrap(), saved)
    }
  }
}

///|
test "DAE ordinary core reuses original syntax facts with unchanged output and effects" {
  for hot in [false, true] {
    for optimize in [false, true] {
      let input = dae_liveness_handoff_fixture(hot)
      let saved = @binary.encode_module(input).unwrap()
      let original = dae_collect_original_boundary_snapshot(input)
      let graph = dae_current_boundary_graph_new(input)
      let expected_effects = []
      let expected = dae_boundary_syntax_frozen_run_core_once(
        input,
        [false, false],
        dae_collect_module_call_counts_anywhere(graph.snapshot.funcs, 0, 2),
        optimize,
        false,
        original,
        graph,
        max_def_exclusive=1,
        producer_effects_report=expected_effects,
      )
      let work = [0, 0]
      let actual_effects = []
      let actual = dae_run_core_once(
        input,
        [false, false],
        dae_collect_module_call_counts_anywhere(graph.snapshot.funcs, 0, 2),
        optimize,
        false,
        original,
        graph,
        max_def_exclusive=1,
        producer_effects_report=actual_effects,
        liveness_work=Some(work),
      )
      dae_liveness_handoff_assert_result(input, actual, expected)
      assert_eq(actual_effects, expected_effects)
      assert_eq(work, [1, 0])
      assert_eq(@binary.encode_module(input).unwrap(), saved)
    }
  }
}

///|
test "DAE intentionally unsupported legacy try remains live with supplied syntax facts" {
  let input = pass_test_module_from_wat(
    "(module (tag $t) (func $target (param i32) (result i32) (try (result i32) (do local.get 0) (catch $t i32.const 0))) (func (export \"run\") (result i32) i32.const 7 call $target))",
  )
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let graph = dae_current_boundary_graph_new(input)
  let syntax = dae_local_use_for_callee(graph.snapshot.funcs[0], 1, 0, 1)
  assert_true(dae_fast_param_entry_liveness(input, 0, 1) is None)
  assert_true(dae_hot_param_entry_liveness(input, 0, 1) is None)
  let work = [0, 0]
  assert_eq(
    dae_incoming_parameter_liveness(
      input,
      0,
      1,
      syntactic_use=Some(syntax),
      liveness_work=Some(work),
    ),
    dae_incoming_parameter_liveness(input, 0, 1),
  )
  assert_eq(dae_incoming_parameter_liveness(input, 0, 1), [true])
  assert_eq(work, [1, 0])
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}
