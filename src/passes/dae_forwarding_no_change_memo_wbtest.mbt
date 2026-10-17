///|
fn dae_forwarding_memo_blocked_fixture() -> @lib.Module {
  pass_test_module_from_wat(
    (
      #|(module
      #|  (func $a (param i32)
      #|    local.get 0 drop local.get 0 call $b)
      #|  (func $b (param i32)
      #|    local.get 0 drop local.get 0 call $a))
    ),
  )
}

///|
test "DAE forwarding memo shares exact negative component proof and keeps per target diagnostics" {
  let input = dae_forwarding_memo_blocked_fixture()
  let saved = @binary.encode_module(input).unwrap()
  let original = dae_collect_original_boundary_snapshot(input)
  let graph = dae_current_boundary_graph_new(input)
  let dependencies = dae_boundary_dependency_graph_new(graph)
  let memo = DaeForwardingNoChangeMemo::new()
  let attempts = [0]
  let diagnostics = dae_diagnostics_new()
  let first = dae_work_item_new(graph, dependencies, 0, DaeForwardingWork)
  let second = dae_work_item_new(graph, dependencies, 1, DaeForwardingWork)
  assert_eq(first.component_members, [0, 1])
  assert_eq(second.component_members, first.component_members)
  for item in [first, second] {
    match
      dae_process_forwarding_work_item_with_memo(
        original,
        input,
        [],
        false,
        graph,
        dependencies,
        item,
        diagnostics,
        memo,
        analysis_attempts=Some(attempts),
      ) {
      DaeWorkNoChange(DaeNoStrictImprovement) => ()
      _ =>
        fail("blocked forwarding values must keep the scalar no-change result")
    }
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
  // This required memo entry guards repeated whole-component analysis. The
  // assertions above also retain actual IR ownership and per-item outcomes.
  assert_eq(memo.entries.get(first.component_id), Some([0, 1]))
  assert_eq(attempts[0], 1)
  assert_eq(diagnostics.boundaries_analyzed, 2)
  assert_eq(
    dae_diagnostics_reason_count(diagnostics, DaeNoStrictImprovement),
    2,
  )
  assert_eq(diagnostics.candidates_applied, 0)
  @validate.validate_module(input).unwrap()
}

///|
test "DAE forwarding memo clears after alias owned commit before a positive component rewrite" {
  let input = dae_forwarding_memo_blocked_fixture()
  let original = dae_collect_original_boundary_snapshot(input)
  let graph = dae_current_boundary_graph_new(input)
  let dependencies = dae_boundary_dependency_graph_new(graph)
  let memo = DaeForwardingNoChangeMemo::new()
  let diagnostics = dae_diagnostics_new()
  let item = dae_work_item_new(graph, dependencies, 0, DaeForwardingWork)
  match
    dae_process_forwarding_work_item_with_memo(
      original,
      input,
      [],
      false,
      graph,
      dependencies,
      item,
      diagnostics,
      memo,
    ) {
    DaeWorkNoChange(DaeNoStrictImprovement) => ()
    _ =>
      fail("expected the initial non-forwarding reads to block this component")
  }
  // Simulate an explicit producer-owned commit through shared body arrays.
  // Calls, paths, function signatures, and graph epochs all remain identical.
  for func in input.code_sec.unwrap().0 {
    let @lib.Func(_, @lib.Expr(body)) = func
    body[0] = @lib.Instruction::nop()
    body[1] = @lib.Instruction::nop()
  }
  assert_eq(graph.module_epoch, 0)
  memo.invalidate()
  assert_eq(memo.entries.length(), 0)
  let saved = @binary.encode_module(input).unwrap()
  let reference_graph = dae_current_boundary_graph_new(input)
  let reference_dependencies = dae_boundary_dependency_graph_new(
    reference_graph,
  )
  let reference_item = dae_work_item_new(
    reference_graph,
    reference_dependencies,
    0,
    DaeForwardingWork,
  )
  let reference = match
    dae_process_work_item(
      original,
      input,
      [],
      false,
      reference_graph,
      reference_dependencies,
      reference_item,
      dae_diagnostics_new(),
    ) {
    DaeWorkCommitted(application) => application
    _ => fail("scalar forwarding reference must remove both cycle parameters")
  }
  let application = match
    dae_process_forwarding_work_item_with_memo(
      original,
      input,
      [],
      false,
      graph,
      dependencies,
      item,
      diagnostics,
      memo,
    ) {
    DaeWorkCommitted(application) => application
    _ =>
      fail(
        "a commit must discard negative proofs before positive forwarding work",
      )
  }
  assert_eq(application.primary_def, reference.primary_def)
  assert_eq(application.effects.parameter_changed, [true, true])
  assert_eq(
    application.effects.structurally_touched,
    reference.effects.structurally_touched,
  )
  assert_eq(application.mod_out.code_sec, reference.mod_out.code_sec)
  assert_eq(application.mod_out.func_sec, reference.mod_out.func_sec)
  assert_eq(application.mod_out.type_sec, reference.mod_out.type_sec)
  assert_eq(
    @binary.encode_module(application.mod_out).unwrap(),
    @binary.encode_module(reference.mod_out).unwrap(),
  )
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  assert_eq(memo.entries.length(), 0)
  @validate.validate_module(application.mod_out).unwrap()
}

///|
test "DAE forwarding memo checks complete member order options and current epochs" {
  let input = dae_forwarding_memo_blocked_fixture()
  let saved = @binary.encode_module(input).unwrap()
  let original = dae_collect_original_boundary_snapshot(input)
  let graph = dae_current_boundary_graph_new(input)
  let dependencies = dae_boundary_dependency_graph_new(graph)
  let memo = DaeForwardingNoChangeMemo::new()
  let diagnostics = dae_diagnostics_new()
  let attempts = [0]
  let first = dae_work_item_new(graph, dependencies, 0, DaeForwardingWork)
  let reordered = { ..first, target_def: 1, component_members: [1, 0], }
  let option_item = { ..reordered, allow_immutable_global_get: true, }
  for item in [first, reordered, option_item] {
    match
      dae_process_forwarding_work_item_with_memo(
        original,
        input,
        [],
        false,
        graph,
        dependencies,
        item,
        diagnostics,
        memo,
        analysis_attempts=Some(attempts),
      ) {
      DaeWorkNoChange(DaeNoStrictImprovement) => ()
      _ => fail("memo key changes must retain the full scalar no-change result")
    }
  }
  assert_eq(attempts[0], 3)
  assert_eq(memo.entries.get(first.component_id), Some([1, 0]))
  graph.module_epoch += 1
  let current = dae_work_item_new(graph, dependencies, 1, DaeForwardingWork)
  for _index in 0..<2 {
    match
      dae_process_forwarding_work_item_with_memo(
        original,
        input,
        [],
        false,
        graph,
        dependencies,
        current,
        diagnostics,
        memo,
        analysis_attempts=Some(attempts),
      ) {
      DaeWorkNoChange(DaeNoStrictImprovement) => ()
      _ => fail("fresh target diagnostics must survive an epoch change")
    }
  }
  assert_eq(attempts[0], 4)
  assert_eq(memo.entries.get(first.component_id), Some([0, 1]))
  assert_eq(diagnostics.boundaries_analyzed, 5)
  assert_eq(
    dae_diagnostics_reason_count(diagnostics, DaeNoStrictImprovement),
    5,
  )
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  @validate.validate_module(input).unwrap()
}

///|
test "DAE effect frontier memo retains scalar commit order effects and source ownership" {
  for
    input in [
      dae_forwarding_memo_blocked_fixture(),
      dae_forwarded_component_plan_fixture(),
    ] {
    let saved = @binary.encode_module(input).unwrap()
    for allow_parameters in [false, true] {
      let original = dae_collect_original_boundary_snapshot(input)
      let reference_trace : Array[String] = []
      let reference = dae_run_effect_frontier_worklist(
        original,
        input,
        [true, true],
        allow_parameters,
        fn(message) { reference_trace.push(message) },
        allow_forwarding_memo=false,
      )
      let actual_trace : Array[String] = []
      let actual = dae_run_effect_frontier_worklist(
        original,
        input,
        [true, true],
        allow_parameters,
        fn(message) { actual_trace.push(message) },
      )
      assert_eq(actual_trace, reference_trace)
      assert_eq(actual.changed, reference.changed)
      assert_eq(actual.touched, reference.touched)
      assert_eq(
        actual.effects.structurally_touched,
        reference.effects.structurally_touched,
      )
      assert_eq(
        actual.effects.parameter_changed,
        reference.effects.parameter_changed,
      )
      assert_eq(
        actual.effects.candidates_produced,
        reference.effects.candidates_produced,
      )
      assert_eq(
        actual.effects.candidates_applied,
        reference.effects.candidates_applied,
      )
      assert_eq(
        actual.diagnostics.boundaries_analyzed,
        reference.diagnostics.boundaries_analyzed,
      )
      assert_eq(
        actual.diagnostics.candidate_requeues,
        reference.diagnostics.candidate_requeues,
      )
      assert_eq(actual.mod_out.code_sec, reference.mod_out.code_sec)
      assert_eq(actual.mod_out.type_sec, reference.mod_out.type_sec)
      assert_eq(actual.mod_out.func_sec, reference.mod_out.func_sec)
      assert_eq(
        @binary.encode_module(actual.mod_out).unwrap(),
        @binary.encode_module(reference.mod_out).unwrap(),
      )
      assert_eq(@binary.encode_module(input).unwrap(), saved)
      @validate.validate_module(actual.mod_out).unwrap()
    }
  }
}
