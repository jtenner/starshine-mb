///|
fn dae_core_handoff_input() -> @lib.Module {
  dae_validation_reuse_fixture(1)
  .with_custom_secs([
    @lib.CustomSec::new(@lib.Name::new("vendor.keep"), b"kept"),
  ])
  .with_name_sec(
    @lib.NameSec::new(
      func_names=Some(
        @lib.NameMap::new([@lib.NameAssoc::new(0U, @lib.Name::new("target"))]),
      ),
    ),
  )
}

///|
fn dae_core_handoff_candidate(
  input : @lib.Module,
  original : DaeOriginalBoundarySnapshot,
  graph : DaeCurrentBoundaryGraph,
  report : Array[(@lib.Module, @lib.Module)],
  counts : Array[Int32],
) -> DaePassResult {
  dae_try_rewrite_candidate(
    input,
    0,
    [true],
    [Some(@lib.Instruction::i32_const(@lib.I32(7)))],
    dae_local_use_for_callee(graph.snapshot.funcs[0], 1, 0, 1),
    1,
    [1],
    original=Some(original),
    graph=Some(graph),
    checked_candidate_report=Some(report),
    rewrite_validation_counts=Some(counts),
  )
}

///|
fn dae_core_handoff_round(
  reference : Bool,
) -> (DaeCoreResultApplication, Array[Int32], @lib.Module) raise {
  let input = dae_core_handoff_input()
  let saved = @binary.encode_module(input).unwrap()
  let original = dae_collect_original_boundary_snapshot(input)
  let graph = dae_current_boundary_graph_new(input)
  let item = dae_work_item_new(
    graph,
    dae_boundary_dependency_graph_new(graph),
    0,
    DaeUniformActualWork,
  )
  let report = []
  let counts = [0, 0]
  let candidate = dae_core_handoff_candidate(
    input, original, graph, report, counts,
  )
  assert_true(candidate.changed)
  assert_eq(report.length(), 1)
  assert_eq(counts, [1, 0])
  let effects = dae_work_item_candidate_effects(input, graph, item, candidate)
  let options = HotPipelineOptions::new()
  let outcome = if reference {
    dae_process_precomputed_signature_work_item(
      original,
      input,
      [false, false, true],
      true,
      graph,
      item,
      candidate,
      effects,
      rewrite_validation_counts=Some(counts),
    )
  } else {
    dae_process_core_precomputed_signature_with_report(
      original,
      input,
      [false, false, true],
      true,
      graph,
      item,
      candidate,
      effects,
      options.trace,
      hot_pipeline_dae_no_callback_trace(options),
      report,
      rewrite_validation_counts=Some(counts),
    )
  }
  let application = match outcome {
    DaeWorkCommitted(value) => value
    _ => fail("expected the scalar constant parameter rewrite to commit")
  }
  assert_true(application.applied && application.changed)
  assert_eq(dae_wb_param_count(application.mod_out, 0), 0)
  assert_true(application.touched[0] && application.touched[1])
  assert_true(application.touched[2])
  assert_eq(application.effects.candidates_applied, 1)
  assert_eq(application.mod_out.custom_secs, input.custom_secs)
  assert_true(application.mod_out.name_sec is None)
  assert_true(input.name_sec is Some(_))
  @validate.validate_module(application.mod_out).unwrap()
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  (application, counts, input)
}

///|
test "DAE certified core handoff reuses one gate with exact scalar output metadata and retained touches" {
  let (expected, reference_counts, _) = dae_core_handoff_round(true)
  let (actual, counts, _) = dae_core_handoff_round(false)
  assert_eq(actual.touched, expected.touched)
  assert_eq(actual.effects, expected.effects)
  assert_eq(actual.primary_def, expected.primary_def)
  assert_eq(actual.mod_out.code_sec, expected.mod_out.code_sec)
  assert_eq(actual.mod_out.type_sec, expected.mod_out.type_sec)
  assert_eq(actual.mod_out.func_sec, expected.mod_out.func_sec)
  assert_eq(
    @binary.encode_module(actual.mod_out).unwrap(),
    @binary.encode_module(expected.mod_out).unwrap(),
  )
  assert_eq(reference_counts, [2, 0])
  assert_eq(counts, [1, 1])
}

///|
test "DAE default options preserve no callback provenance while user and perf callbacks are intentionally excluded" {
  let options = HotPipelineOptions::new()
  let proof = hot_pipeline_dae_no_callback_trace(options).unwrap()
  assert_true(physical_equal(proof.callback, options.trace))
  let custom = HotPipelineOptions::new(trace=Some(fn(_ : String) { () }))
  assert_true(hot_pipeline_dae_no_callback_trace(custom) is None)
  let timed = HotPipelineOptions::new(perf=Some(HotPerfSession::new()))
  assert_true(hot_pipeline_dae_no_callback_trace(timed) is None)
  let replaced = { ..options, trace: fn(_ : String) { () }, }
  assert_true(hot_pipeline_dae_no_callback_trace(replaced) is None)
}

///|
test "DAE core handoff keeps the full gate for a false source report" {
  let input = dae_core_handoff_input()
  let saved = @binary.encode_module(input).unwrap()
  let original = dae_collect_original_boundary_snapshot(input)
  let graph = dae_current_boundary_graph_new(input)
  let item = dae_work_item_new(
    graph,
    dae_boundary_dependency_graph_new(graph),
    0,
    DaeUniformActualWork,
  )
  let report = []
  let counts = [0, 0]
  let candidate = dae_core_handoff_candidate(
    input, original, graph, report, counts,
  )
  report[0] = (input.with_custom_secs(input.custom_secs), report[0].1)
  let options = HotPipelineOptions::new()
  let effects = dae_work_item_candidate_effects(input, graph, item, candidate)
  let outcome = dae_process_core_precomputed_signature_with_report(
    original,
    input,
    [false, false, true],
    true,
    graph,
    item,
    candidate,
    effects,
    options.trace,
    hot_pipeline_dae_no_callback_trace(options),
    report,
    rewrite_validation_counts=Some(counts),
  )
  match outcome {
    DaeWorkCommitted(actual) => {
      assert_eq(dae_wb_param_count(actual.mod_out, 0), 0)
      assert_true(actual.touched[2])
      @validate.validate_module(actual.mod_out).unwrap()
    }
    _ => fail("a false source report must fall back to the full valid gate")
  }
  assert_eq(counts, [2, 0])
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "DAE core handoff rejects an intentionally invalid replacement candidate despite an earlier valid report" {
  let input = dae_core_handoff_input()
  let saved = @binary.encode_module(input).unwrap()
  let original = dae_collect_original_boundary_snapshot(input)
  let graph = dae_current_boundary_graph_new(input)
  let item = dae_work_item_new(
    graph,
    dae_boundary_dependency_graph_new(graph),
    0,
    DaeUniformActualWork,
  )
  let report = []
  let counts = [0, 0]
  let valid = dae_core_handoff_candidate(input, original, graph, report, counts)
  let funcs = valid.mod_out.code_sec.unwrap().0.copy()
  funcs[2] = @lib.Func::new(
    @lib.Locals::empty(),
    @lib.Expr::new([@lib.Instruction::local_get(@lib.LocalIdx::new(99U))]),
  )
  let candidate = {
    ..valid,
    mod_out: valid.mod_out.with_code_sec(@lib.CodeSec::new(funcs)),
  }
  let effects = dae_work_item_candidate_effects(input, graph, item, candidate)
  let options = HotPipelineOptions::new()
  let outcome = dae_process_core_precomputed_signature_with_report(
    original,
    input,
    [false, false, true],
    true,
    graph,
    item,
    candidate,
    effects,
    options.trace,
    hot_pipeline_dae_no_callback_trace(options),
    report,
    rewrite_validation_counts=Some(counts),
  )
  assert_true(outcome is DaeWorkNoChange(_))
  assert_eq(counts[1], 0)
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  @validate.validate_module(input).unwrap()
}
