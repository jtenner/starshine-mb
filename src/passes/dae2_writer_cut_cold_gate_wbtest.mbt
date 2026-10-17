///|
/// Calls the same wrapper as actual main. Journal presence is captured at
/// lift handoff but asserted only after all real transform and ownership checks.
fn dae2_writer_cut_cold_check(kind : Int32) -> Unit raise {
  let input = dae2_writer_cut_cold_fixture(kind, 2)
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  for closed_world in [false, true] {
    let probe = dae2_writer_cut_probe_setup(input, closed_world)
    let info = probe.infos[probe.index]
    let original = input.code_sec.unwrap().0[probe.index -
      dae_imported_func_count(input)]
    let writes = info.raw_write_locations.unwrap_or([])
    assert_eq(writes.length(), if kind == 1 { 1 } else { 0 })
    let source_used = probe.source.used.copy()
    let source_edges = probe.source.edges.copy()
    let source_work = probe.source.work.copy()
    let actual_func = dae2_lift_for_rewrite(
      input,
      probe.context,
      probe.index,
      info,
    ).unwrap()
    let journal_at_lift = actual_func.lifted_local_accesses is Some(_)
    let expected_func = dae2_writer_cut_test_lift(
      input,
      probe.context,
      probe.index,
    )
    if kind >= 2 {
      assert_true(
        @ir.hot_lift_local_accesses(expected_func).capture_sources
        .unwrap()
        .length() >=
        2,
      )
    }
    let revision = @ir.hot_revision_current(actual_func)
    assert_eq(
      @ir.hot_node_count(actual_func),
      @ir.hot_node_count(expected_func),
    )
    assert_eq(actual_func.roots, expected_func.roots)
    assert_eq(actual_func.children, expected_func.children)
    assert_eq(
      @ir.hot_local_count(actual_func),
      @ir.hot_local_count(expected_func),
    )
    for node in 0..<@ir.hot_node_count(actual_func) {
      @debug.assert_eq(
        @ir.hot_node_get(actual_func, node),
        @ir.hot_node_get(expected_func, node),
      )
    }
    let expected = Dae2RawReplayState::new(probe.source, probe.boundary_count)
    info.assign_node_locations(
      expected.graph,
      @ir.hot_node_count(expected_func),
    )
    let old_builds = [0]
    dae2_writer_cut_frozen_dae2_analyze_function(
      expected.graph,
      probe.infos,
      probe.index,
      probe.type_infos,
      expected_func,
      local_graph_builds=Some(old_builds),
    )
    assert_true(expected.solve_function(info, probe.infos))
    let actual = Dae2RawReplayState::new(probe.source, probe.boundary_count)
    let builds = [0]
    assert_true(
      dae2_writer_cut_analyze_raw_replay(
        probe.source,
        actual,
        probe.infos,
        probe.index,
        probe.type_infos,
        actual_func,
        original,
        local_graph_builds=Some(builds),
      ),
    )
    assert_true(actual_func.lifted_local_accesses is None)
    for node in 0..<info.node_count {
      assert_eq(
        actual.graph.used[info.node_location_base + node],
        expected.graph.used[info.node_location_base + node],
      )
    }
    for location in 0..<probe.boundary_count {
      assert_eq(actual.graph.used[location], probe.source.used[location])
      assert_eq(actual.graph.used[location], expected.graph.used[location])
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
    let production_lifts = [0]
    let output = dae2_run_module_pass(
      input,
      closed_world,
      raw_rewrite=false,
      stack_suffix_rewrite=false,
      rewrite_lifts=Some(production_lifts),
    ).unwrap()
    assert_true(production_lifts[0] > 0)
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
    dae2_writer_cut_census_bytes_equal(
      @binary.encode_module(actual_output).unwrap(),
      @binary.encode_module(expected_output).unwrap(),
      "cold gate exact output",
    )
    let @lib.Func(_, @lib.Expr(before)) = original
    let @lib.Func(_, @lib.Expr(after)) = actual_body
    assert_eq(
      dae2_writer_cut_effect_count(before),
      dae2_writer_cut_effect_count(after),
    )
    dae2_writer_cut_census_bytes_equal(
      @binary.encode_module(input).unwrap(),
      saved,
      "cold gate source ownership",
    )
    // The nested capture writer is not a root; the old fallback must remain.
    // This old reference bound is checked before the required allocation RED.
    assert_eq(old_builds[0], if kind == 3 { 1 } else { 0 })
    // The actual capture-only route may still use a cut in the baseline. The
    // complete node/output guards above are required in both versions.
    if kind < 3 {
      assert_eq(builds[0], 0)
    }
    assert_eq(journal_at_lift, kind == 1)
    if kind == 3 {
      assert_eq(builds[0], 1)
    }
  }
}

///|
test "writer rewrite cold no source writes allocates no source journal" {
  dae2_writer_cut_cold_check(0)
}

///|
test "writer rewrite single source write retains journal on old no-CFG path" {
  dae2_writer_cut_cold_check(1)
}

///|
test "writer rewrite capture-only root uses old entry proof without journals" {
  dae2_writer_cut_cold_check(2)
}

///|
test "writer rewrite capture-only nested writer retains full old flow fallback" {
  dae2_writer_cut_cold_check(3)
}
