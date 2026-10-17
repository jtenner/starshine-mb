///|
/// Shared fixture construction only. This is outside native timed closures.
priv struct Dae2WriterCutProbe {
  context : @ir.HotModuleContext
  source : Dae2Graph
  infos : Array[Dae2Function]
  type_infos : Array[Int32]
  boundary_count : Int32
  index : Int32
}

///|
fn dae2_writer_cut_probe_setup(
  input : @lib.Module,
  closed_world : Bool,
) -> Dae2WriterCutProbe {
  let context = @ir.hot_module_context_from_module(input)
  let indices = dae_collect_func_type_indices(input)
  let imported = dae_imported_func_count(input)
  let source = Dae2Graph::new()
  let infos : Array[Dae2Function] = []
  for index in 0..<indices.length() {
    let @lib.FuncType(params, results) = @ir.hot_module_resolve_func_type(
      context,
      @lib.FuncIdx::new(index.to_uint()),
    ).unwrap()
    infos.push(Dae2Function::new(source, params, results))
  }
  let exposure = dae_collect_original_exposure(
    dae2_exposure_module(input),
    indices.length(),
    indices,
  )
  let type_infos = dae2_prepare_type_locations(
    input, context, source, infos, exposure, closed_world,
  )
  let boundary_count = source.used.length()
  for index in imported..<indices.length() {
    let original = input.code_sec.unwrap().0[index - imported]
    let @lib.Func(_, @lib.Expr(body)) = original
    ignore(
      dae2_collect_control_type_infos(
        body,
        type_infos,
        infos[index].control_type_infos,
        call_infos=Some(infos[index].call_infos),
      ),
    )
    infos[index].call_infos_ready = true
    dae2_pin_flat_observable_params(
      source, infos, index, body, indices, type_infos, exposure,
    )
    let plan = dae2_raw_dependency_plan(
      source,
      infos,
      index,
      type_infos,
      original,
      None,
      module_context=Some(context),
    ).unwrap()
    plan.commit(source)
    infos[index].raw_analysis = true
    infos[index].raw_write_locations = plan.write_locations
  }
  source.solve()
  dae2_preserve_type_identity(
    input.type_sec.unwrap(),
    source,
    infos,
    type_infos,
  )
  {
    context,
    source,
    infos,
    type_infos,
    boundary_count,
    index: indices.length() - 1,
  }
}

///|
/// Caller formal parameters remain public/kept in these bounded fixtures.
fn dae2_writer_cut_probe_lower(
  input : @lib.Module,
  probe : Dae2WriterCutProbe,
  replay : Dae2RawReplayState,
  func : @ir.HotFunc,
) -> @lib.Func {
  let info = probe.infos[probe.index]
  let lower_state : HotPipelineLowerState = {
    next_type_sec: input.type_sec,
    type_sec_changed: false,
  }
  let controls : @hashmap.HashMap[Int32, @lib.TypeIdx] = @hashmap.new()
  dae2_preserve_control_types(
    func,
    probe.context,
    replay.graph,
    probe.infos,
    probe.type_infos,
    lower_state,
    controls,
  )
  let arities = Array::makei(@ir.hot_node_count(func), fn(node) {
    @ir.hot_node_result_arity(func, node)
  })
  let memo = Array::make(info.node_count, -1)
  let roots = @ir.hot_root_span(func).map(fn(root) {
    dae2_rewrite_node(
      replay.graph,
      probe.infos,
      probe.index,
      func,
      root,
      memo,
      arities,
      lower_state,
      probe.type_infos,
    )
  })
  ignore(@ir.hot_root_splice(func, 0, @ir.hot_root_count(func), roots))
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_results(func, info.results),
  )
  run_hot_pipeline_prepare_tuple_make_lowering(func, lower_state)
  @ir.hot_verify_control(func).unwrap()
  @ir.hot_lower_func_unverified(func)
}

///|
fn dae2_writer_cut_probe_graph_equal(
  actual : Dae2Graph,
  expected : Dae2Graph,
) -> Unit raise {
  assert_eq(actual.edges, expected.edges)
  assert_eq(actual.next_edge, expected.next_edge)
  assert_eq(actual.first_edge, expected.first_edge)
  assert_eq(actual.last_edge, expected.last_edge)
  assert_eq(actual.used, expected.used)
  assert_eq(actual.work, expected.work)
  assert_eq(actual.cursor, expected.cursor)
}

///|
/// fault0: admitted cut, fault1: intentionally invalid source map, fault2:
/// intentionally invalid private demand row. Only fault2 calls the shared
/// production inner gate directly; the two release controls call the main's
/// outer qualification gate and observe its actual post-call journal field.
fn dae2_writer_cut_probe_check(fault : Int32) -> Unit raise {
  let input = if fault == 3 {
    pass_test_module_from_wat(
      "(module (import \"m\" \"effect\" (func $effect (param i32) (result i32))) " +
      "(func $h (param i64) (result i32) i32.const 10) " +
      "(func (export \"run\") (param i32) (result i32) " +
      "local.get 0 call $effect loop nop end i32.const 1 i32.add " +
      "call $effect i64.extend_i32_s call $h))",
    )
  } else {
    dae2_writer_cut_fixture(if fault == 2 { 1 } else { 0 })
  }
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  for closed_world in [false, true] {
    let probe = dae2_writer_cut_probe_setup(input, closed_world)
    let info = probe.infos[probe.index]
    let original = input.code_sec.unwrap().0[probe.index -
      dae_imported_func_count(input)]
    let source_used = probe.source.used.copy()
    let source_edges = probe.source.edges.copy()
    let source_work = probe.source.work.copy()
    let actual_func = dae2_writer_cut_test_lift(
      input,
      probe.context,
      probe.index,
    )
    let expected_func = dae2_writer_cut_test_lift(
      input,
      probe.context,
      probe.index,
    )
    let revision = @ir.hot_revision_current(actual_func)
    let expected = Dae2RawReplayState::new(probe.source, probe.boundary_count)
    info.assign_node_locations(
      expected.graph,
      @ir.hot_node_count(expected_func),
    )
    dae2_analyze_function(
      expected.graph,
      probe.infos,
      probe.index,
      probe.type_infos,
      expected_func,
    )
    assert_true(expected.solve_function(info, probe.infos))
    let expected_base = info.node_location_base
    let expected_bits = Array::makei(info.node_count, fn(node) {
      expected.graph.used[expected_base + node]
    })
    let actual = Dae2RawReplayState::new(probe.source, probe.boundary_count)
    let builds = if fault == 3 { [0, 0] } else { [0] }
    if fault == 1 {
      let journal = @ir.hot_lift_local_accesses(actual_func)
      let (local, node) = journal.writes[0]
      journal.writes[0] = (local + 1, node)
    }
    let ok = if fault == 2 {
      // The production inner seed/analyze/matches_writers/reset path is shared
      // verbatim. The only unsupported input is this private copied demand bit.
      let cut = dae2_writer_cut_prepare(
        probe.source,
        info,
        actual_func,
        original,
      ).unwrap()
      let demands = cut.writer_demands.copy()
      let mut target = -1
      for index in 0..<cut.accesses.writes.length() {
        let (_, node) = cut.accesses.writes[index]
        if node >= 0 &&
          @ir.hot_node_op(actual_func, node) is @ir.LocalTee &&
          demands[index] {
          target = index
          break
        }
      }
      assert_true(target >= 0)
      demands[target] = false
      let broken = { ..cut, writer_demands: demands, }
      dae2_writer_cut_analyze_prepared_replay(
        actual,
        probe.infos,
        probe.index,
        probe.type_infos,
        actual_func,
        Some(broken),
        local_graph_builds=Some(builds),
      )
    } else {
      dae2_writer_cut_analyze_raw_replay(
        probe.source,
        actual,
        probe.infos,
        probe.index,
        probe.type_infos,
        actual_func,
        original,
        local_graph_builds=Some(builds),
      )
    }
    let released_at_boundary = actual_func.lifted_local_accesses is None
    assert_true(ok)
    for node in 0..<info.node_count {
      assert_eq(
        actual.graph.used[info.node_location_base + node],
        expected_bits[node],
      )
      @debug.assert_eq(
        @ir.hot_node_get(actual_func, node),
        @ir.hot_node_get(expected_func, node),
      )
    }
    for location in 0..<probe.boundary_count {
      assert_eq(actual.graph.used[location], probe.source.used[location])
    }
    if fault == 1 || fault == 2 {
      // A missing reset/full replay cannot pass merely by matching the bits.
      // All insertion-ordered graph and worklist fields must be restored too.
      dae2_writer_cut_probe_graph_equal(actual.graph, expected.graph)
    }
    if fault == 2 {
      assert_eq(actual.epoch, 2)
    }
    assert_eq(@ir.hot_revision_current(actual_func), revision)
    assert_eq(probe.source.used, source_used)
    assert_eq(probe.source.edges, source_edges)
    assert_eq(probe.source.work, source_work)
    let actual_body = dae2_writer_cut_probe_lower(
      input, probe, actual, actual_func,
    )
    let expected_body = dae2_writer_cut_probe_lower(
      input, probe, expected, expected_func,
    )
    @debug.assert_eq(actual_body, expected_body)
    // Use the real final signatures, and replace only the public caller with
    // each independently rewritten/lowered body. Fixture control headers are
    // inline scalar headers, so no source type-index remap is required here.
    let output = dae2_run_module_pass(
      input,
      closed_world,
      raw_rewrite=false,
      stack_suffix_rewrite=false,
    ).unwrap()
    let actual_bodies = output.code_sec.unwrap().0.copy()
    let expected_bodies = actual_bodies.copy()
    actual_bodies[actual_bodies.length() - 1] = actual_body
    expected_bodies[expected_bodies.length() - 1] = expected_body
    let actual_output = output.with_code_sec(@lib.CodeSec::new(actual_bodies))
    let expected_output = output.with_code_sec(
      @lib.CodeSec::new(expected_bodies),
    )
    @validate.validate_module(actual_output).unwrap()
    @validate.validate_module(expected_output).unwrap()
    assert_eq(
      @binary.encode_module(actual_output).unwrap(),
      @binary.encode_module(expected_output).unwrap(),
    )
    let @lib.Func(_, @lib.Expr(source_body)) = original
    let @lib.Func(_, @lib.Expr(lowered_body)) = actual_body
    assert_eq(
      dae2_writer_cut_effect_count(source_body),
      dae2_writer_cut_effect_count(lowered_body),
    )
    assert_eq(@binary.encode_module(input).unwrap(), saved)
    assert_eq(builds[0], if fault == 0 || fault == 3 { 0 } else { 1 })
    if fault != 2 {
      // Required actual retention RED is last, after real transform/validity
      // and node/output/effect/ownership checks, on the exact handoff snapshot.
      assert_true(released_at_boundary)
    }
    if fault == 3 {
      assert_eq(builds[1], 0)
    }
  }
}
