///|
/// Baseline adapter. It uses the real old CFG path, with no simulated counter.
fn dae2_writer_cut_test_lift(
  input : @lib.Module,
  context : @ir.HotModuleContext,
  index : Int32,
) -> @ir.HotFunc {
  dae2_lift_for_analysis(
    input,
    context,
    index,
    record_local_accesses=true,
    record_capture_sources=true,
  ).unwrap()
}

///|
fn dae2_writer_cut_test_analyze(
  source : Dae2Graph,
  replay : Dae2RawReplayState,
  infos : Array[Dae2Function],
  index : Int32,
  type_infos : Array[Int32],
  func : @ir.HotFunc,
  original : @lib.Func,
  builds : Array[Int32],
) -> Unit {
  let cut = dae2_writer_cut_prepare(source, infos[index], func, original)
  match cut {
    Some(cut) => {
      @ir.hot_verify_all_or_abort(func)
      cut.seed(replay.graph, infos[index])
    }
    None => ()
  }
  dae2_analyze_function(
    replay.graph,
    infos,
    index,
    type_infos,
    func,
    local_graph_builds=Some(builds),
    writer_cut=cut,
  )
}

///|
fn dae2_writer_cut_fixture(mode : Int32) -> @lib.Module {
  let body = match mode {
    0 =>
      "local.get 0 if i32.const 11 local.set 1 else i32.const 12 local.set 1 end local.get 1"
    1 => "local.get 0 local.tee 1 i32.const 7 local.set 1 local.get 1 i32.add"
    2 =>
      "block i32.const 3 call $effect local.get 0 if i32.const 11 local.set 1 else i32.const 12 local.set 1 end local.get 1 i32.add call $effect drop end local.get 1"
    3 =>
      "i32.const 0 local.set 1 loop local.get 0 if local.get 1 i32.const 1 i32.add local.set 1 local.get 0 i32.const 1 i32.sub local.set 0 br 1 end end local.get 1"
    _ =>
      "local.get 0 i32.load loop local.get 0 call $effect local.set 1 end local.get 1 i32.add"
  }
  pass_test_module_from_wat(
    "(module (import \"m\" \"effect\" (func $effect (param i32) (result i32))) " +
    "(memory 1) (func $h (param i64) (result i32) i32.const 10) " +
    "(func (export \"run\") (param i32) (result i32) (local i32) " +
    // This scalar control value is dead. It is retained by the current raw
    // header contract; full HOT remains the intended rewrite for this test.
    "local.get 0 if (result i32) i32.const 1 else i32.const 2 end drop " +
    body +
    " call $effect i64.extend_i32_s call $h))",
  )
}

///|
fn dae2_writer_cut_check(
  input : @lib.Module,
  journal_fault~ : Int32 = 0,
) -> Unit raise {
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  for closed_world in [false, true] {
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
    let saved_used = source.used.copy()
    let saved_edges = source.edges.copy()
    let saved_work = source.work.copy()
    let index = indices.length() - 1
    let info = infos[index]
    let expected_func = dae2_writer_cut_test_lift(input, context, index)
    let actual_func = dae2_writer_cut_test_lift(input, context, index)
    assert_eq(
      @ir.hot_node_count(actual_func),
      @ir.hot_node_count(expected_func),
    )
    assert_eq(
      @ir.hot_local_count(actual_func),
      @ir.hot_local_count(expected_func),
    )
    assert_eq(actual_func.children, expected_func.children)
    assert_eq(actual_func.roots, expected_func.roots)
    if journal_fault == 1 {
      let journal = @ir.hot_lift_local_accesses(actual_func)
      let (local, node) = journal.writes[0]
      journal.writes[0] = (local + 1, node)
    } else if journal_fault == 2 {
      @ir.hot_revision_bump(actual_func)
    }
    let revision = @ir.hot_revision_current(actual_func)
    let expected = Dae2RawReplayState::new(source, boundary_count)
    info.assign_node_locations(
      expected.graph,
      @ir.hot_node_count(expected_func),
    )
    let old_builds = [0]
    dae2_analyze_function(
      expected.graph,
      infos,
      index,
      type_infos,
      expected_func,
      local_graph_builds=Some(old_builds),
    )
    assert_true(expected.solve_function(info, infos))
    let expected_base = info.node_location_base
    let expected_nodes = Array::makei(info.node_count, fn(node) {
      expected.graph.used[expected_base + node]
    })
    // Establish the cut contract before testing the resource bound. A raw
    // writer-bit mismatch is a behavior failure, never an admissible shortcut.
    let accesses = @ir.hot_lift_local_accesses(expected_func)
    let raw_writes = info.raw_write_locations.unwrap_or([])
    assert_eq(accesses.writes.length(), raw_writes.length())
    for write in 0..<raw_writes.length() {
      let (local, location) = raw_writes[write]
      let (hot_local, node) = accesses.writes[write]
      assert_eq(local, hot_local)
      if node >= 0 {
        assert_eq(
          expected.graph.used[expected_base + node],
          source.used[location],
        )
      } else {
        assert_false(source.used[location])
      }
    }
    let actual = Dae2RawReplayState::new(source, boundary_count)
    info.assign_node_locations(actual.graph, @ir.hot_node_count(actual_func))
    let builds = [0]
    dae2_writer_cut_test_analyze(
      source,
      actual,
      infos,
      index,
      type_infos,
      actual_func,
      input.code_sec.unwrap().0[index - imported],
      builds,
    )
    assert_true(actual.solve_function(info, infos))
    for node in 0..<info.node_count {
      assert_eq(
        actual.graph.used[info.node_location_base + node],
        expected_nodes[node],
      )
      @debug.assert_eq(
        @ir.hot_node_get(actual_func, node),
        @ir.hot_node_get(expected_func, node),
      )
    }
    for location in 0..<boundary_count {
      assert_eq(actual.graph.used[location], expected.graph.used[location])
      assert_eq(actual.graph.used[location], source.used[location])
    }
    assert_eq(@ir.hot_revision_current(actual_func), revision)
    assert_eq(source.used, saved_used)
    assert_eq(source.edges, saved_edges)
    assert_eq(source.work, saved_work)
    assert_eq(@binary.encode_module(input).unwrap(), saved)
    // Force the real HOT rewrite route in both controls. Only raw-origin
    // rewrite analysis may use the new cut; direct/suffix shapes are excluded.
    let output = dae2_run_module_pass(
      input,
      closed_world,
      raw_rewrite=false,
      stack_suffix_rewrite=false,
    ).unwrap()
    let reference = dae2_run_module_pass(
      input,
      closed_world,
      raw_analysis=false,
      raw_rewrite=false,
      stack_suffix_rewrite=false,
    ).unwrap()
    @validate.validate_module(output).unwrap()
    @validate.validate_module(reference).unwrap()
    assert_eq(
      @binary.encode_module(output).unwrap(),
      @binary.encode_module(reference).unwrap(),
    )
    let original_run = input.code_sec.unwrap().0[input.code_sec.unwrap().0.length() -
      1]
    let output_run = output.code_sec.unwrap().0[output.code_sec.unwrap().0.length() -
      1]
    let @lib.Func(_, @lib.Expr(original_body)) = original_run
    let @lib.Func(_, @lib.Expr(output_body)) = output_run
    assert_eq(
      dae2_writer_cut_effect_count(output_body),
      dae2_writer_cut_effect_count(original_body),
    )
    if !closed_world {
      let dispatched = run_hot_pipeline(input, HotPipelineOptions::new(), [
        "dae2",
      ]).unwrap()
      let direct = dae2_run_module_pass(input, false).unwrap()
      @validate.validate_module(dispatched).unwrap()
      assert_eq(
        @binary.encode_module(dispatched).unwrap(),
        @binary.encode_module(direct).unwrap(),
      )
    }
    assert_eq(@binary.encode_module(input).unwrap(), saved)
    // Actual full CFG/local-source construction must be reached by the old
    // analyzer before claiming a resource RED. No guessed work counter.
    assert_eq(old_builds[0], 1)
    assert_eq(builds[0], if journal_fault == 0 { 0 } else { 1 })
  }
}

///|
fn dae2_writer_cut_effect_count(body : Array[@lib.Instruction]) -> Int32 {
  let mut count = 0
  for instr in body {
    match instr {
      @lib.Call(index) => if dae_func_idx_slot(index) == 0 { count += 1 }
      @lib.Block(_, @lib.Expr(child)) | @lib.Loop(_, @lib.Expr(child)) =>
        count += dae2_writer_cut_effect_count(child)
      @lib.If(_, yes, no) => {
        count += dae2_writer_cut_effect_count(yes)
        match no {
          Some(child) => count += dae2_writer_cut_effect_count(child)
          None => ()
        }
      }
      _ => ()
    }
  }
  count
}
