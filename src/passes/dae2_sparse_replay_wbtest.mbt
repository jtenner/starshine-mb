///|
test "DAE2 sparse replay retains only an owned boundary mask after analysis" {
  let source = Dae2Graph::new()
  ignore(source.locations(4))
  source.observe(1)
  let base = source.locations(32)
  source.edge(1, base)
  source.solve()
  let saved = source.used.copy()
  let replay = Dae2RawReplayState::new(source, 4)
  // Expression locations and adjacency must die with module analysis instead
  // of surviving through finalization via the reusable replay workspace.
  assert_eq(replay.source.used.length(), 4)
  assert_false(physical_equal(replay.source.used, source.used))
  assert_eq(replay.source.used, [false, true, false, false])
  assert_true(replay.source.edges.is_empty())
  assert_true(replay.source.first_edge.is_empty())
  assert_false(physical_equal(replay.source.used, replay.graph.used))
  replay.graph.observe(0)
  assert_false(replay.solve())
  replay.reset()
  assert_eq(replay.graph.used, [false, true, false, false])
  assert_eq(source.used, saved)
}

///|
test "DAE2 replay queues only live boundary consumers of the current body" {
  let source = Dae2Graph::new()
  ignore(source.locations(128))
  for location in 0..<128 {
    if location != 0 {
      source.observe(location)
    }
  }
  source.solve()
  let saved = source.used.copy()
  let replay = Dae2RawReplayState::new(source, 128)
  // An idle workspace must not queue unrelated live function/type boundaries.
  assert_eq(replay.graph.work.length(), 0)
  for consumer in [1, 127, 2] {
    replay.reset()
    assert_eq(replay.graph.work.length(), 0)
    let base = replay.graph.locations(3)
    replay.graph.edge(consumer, base)
    replay.graph.edge(base, base + 1)
    replay.graph.edge(0, base + 2)
    replay.register(consumer)
    replay.register(consumer)
    replay.register(0)
    assert_true(replay.solve())
    assert_eq(replay.graph.work.length(), 3)
    assert_eq(replay.graph.used[base], true)
    assert_eq(replay.graph.used[base + 1], true)
    assert_eq(replay.graph.used[base + 2], false)
    for location in 0..<128 {
      assert_eq(replay.graph.used[location], saved[location])
      assert_eq(
        replay.graph.first_edge[location] >= 0,
        location == consumer || location == 0,
      )
    }
  }
  assert_eq(source.used, saved)
  assert_true(source.edges.is_empty())
}

///|
test "DAE2 sparse replay rejects newly live boundaries and restores failed workspaces" {
  let source = Dae2Graph::new()
  ignore(source.locations(3))
  source.observe(2)
  source.solve()
  let replay = Dae2RawReplayState::new(source, 3)
  let base = replay.graph.locations(2)
  replay.graph.edge(2, base)
  replay.graph.edge(base, 0)
  replay.graph.edge(0, base + 1)
  replay.register(2)
  replay.register(0)
  assert_false(replay.solve())
  assert_eq(replay.graph.used[0], true)
  assert_eq(source.used, [false, false, true])
  replay.reset()
  assert_eq(replay.graph.used, source.used)
  assert_eq(replay.graph.first_edge, [-1, -1, -1])
  assert_eq(replay.graph.work.length(), 0)
  let base = replay.graph.locations(1)
  replay.graph.edge(2, base)
  replay.register(2)
  assert_true(replay.solve())
  assert_eq(replay.graph.used, [false, false, true, true])
  // Invalid or incomplete metadata intentionally requests full HOT fallback.
  replay.reset()
  replay.register(-1)
  assert_false(replay.solve())
  replay.reset()
  replay.register(3)
  assert_false(replay.solve())
  replay.reset()
  let info = Dae2Function::new(Dae2Graph::new(), [], [])
  assert_false(replay.solve_function(info, [info]))
  replay.reset()
  info.call_infos_ready = true
  info.call_infos.push(1)
  assert_false(replay.solve_function(info, [info]))
}

///|
test "DAE2 sparse replay resets duplicate consumer marks across epoch wrap" {
  let source = Dae2Graph::new()
  ignore(source.locations(2))
  source.observe(1)
  source.solve()
  let replay = Dae2RawReplayState::new(source, 2)
  replay.epoch = 2147483647
  replay.register(1)
  replay.register(1)
  assert_eq(replay.touched, [1])
  let base = replay.graph.locations(1)
  replay.graph.edge(1, base)
  assert_true(replay.solve())
  replay.reset()
  assert_eq(replay.epoch, 1)
  assert_eq(replay.epochs, [0, 0])
  assert_eq(replay.graph.first_edge, [-1, -1])
  replay.register(1)
  replay.register(1)
  assert_eq(replay.touched, [1])
}

///|
fn dae2_sparse_replay_compare(input : @lib.Module) -> Unit raise {
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let input = dae2_prepare_legacy_handlers(input).unwrap()
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
    input, context, source, infos, exposure, false,
  )
  let boundaries = source.used.length()
  let intrinsic_imports = dae2_intrinsic_import_mask(context)
  for index in imported..<indices.length() {
    let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[index -
      imported]
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
    let func = dae2_lift_for_analysis(input, context, index).unwrap()
    infos[index].assign_node_locations(source, @ir.hot_node_count(func))
    dae2_analyze_function(
      source,
      infos,
      index,
      type_infos,
      func,
      intrinsic_imports~,
    )
  }
  source.solve()
  let saved_used = source.used.copy()
  let saved_work = source.work.copy()
  let saved_edges = source.edges.copy()
  let replay = Dae2RawReplayState::new(source, boundaries)
  // Revisit in reverse order, then forward, to expose stale rows/capacity.
  for reverse in [true, false] {
    for ordinal in imported..<indices.length() {
      let index = if reverse {
        indices.length() - 1 - ordinal + imported
      } else {
        ordinal
      }
      let func = dae2_lift_for_analysis(input, context, index).unwrap()
      replay.reset()
      infos[index].assign_node_locations(replay.graph, @ir.hot_node_count(func))
      dae2_analyze_function(
        replay.graph,
        infos,
        index,
        type_infos,
        func,
        intrinsic_imports~,
      )
      let reference = Dae2RawReplayState::new(source, boundaries, sparse=false)
      infos[index].assign_node_locations(
        reference.graph,
        @ir.hot_node_count(func),
      )
      dae2_analyze_function(
        reference.graph,
        infos,
        index,
        type_infos,
        func,
        intrinsic_imports~,
      )
      assert_true(reference.solve_function(infos[index], infos))
      assert_true(replay.solve_function(infos[index], infos))
      assert_eq(replay.graph.used, reference.graph.used)
      assert_eq(replay.graph.edges, reference.graph.edges)
      assert_eq(replay.graph.next_edge, reference.graph.next_edge)
      assert_eq(replay.graph.first_edge, reference.graph.first_edge)
      assert_eq(replay.graph.last_edge, reference.graph.last_edge)
    }
  }
  assert_eq(source.used, saved_used)
  assert_eq(source.work, saved_work)
  assert_eq(source.edges, saved_edges)
  for closed_world in [false, true] {
    let actual = match
      dae2_run_module_pass(input, closed_world, raw_rewrite=false) {
      Ok(output) => output
      Err(error) =>
        fail(
          "DAE2 sparse replay rewrite failed (optimizing=\{closed_world}): \{error}; input=\{input}",
        )
    }
    let reference = dae2_run_module_pass(
      input,
      closed_world,
      raw_rewrite=false,
      raw_sparse_replay=false,
    ).unwrap()
    @validate.validate_module(actual).unwrap()
    assert_eq(
      @binary.encode_module(actual).unwrap(),
      @binary.encode_module(reference).unwrap(),
    )
  }
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "DAE2 sparse replay matches all HOT expression and boundary dependencies across call families" {
  for
    wat in [
      "(module (global $g (mut i32) (i32.const 0)) (func $a (param i32 i32) (result i32) local.get 1 i32.const 7 i32.add) (func $b (param i32 i32) local.get 0 global.set $g local.get 1 drop) (func (export \"run\") (param i32) (result i32) i32.const 8 local.get 0 call $a drop local.get 0 i32.const 11 call $b local.get 0 i32.const 9 call $a))",
      "(module (import \"m\" \"f\" (func $f (param i32 i64) (result i32))) (func (export \"run\") (param i32) (result i32) local.get 0 i64.const 7 call $f))",
      "(module (func $f (param i32 i32) (result i32) local.get 0 if (result i32) local.get 0 i32.const 1 i32.sub local.get 1 call $f else local.get 1 end) (func (export \"run\") (param i32) (result i32) local.get 0 i32.const 9 call $f))",
      "(module (type $s (func (param i32 i32) (result i32))) (table 1 funcref) (func $f (type $s) local.get 1) (elem (i32.const 0) $f) (func (export \"run\") (param i32) (result i32) i32.const 3 local.get 0 i32.const 0 call_indirect (type $s)))",
      "(module (type $s (func (param i32 i32) (result i32))) (func $f (type $s) local.get 1) (elem declare func $f) (func (export \"run\") (param i32) (result i32) i32.const 3 local.get 0 ref.func $f call_ref $s))",
      "(module (func $f (param i32 i32) (result i32) local.get 1) (func $h (param i32 i32) (result i32) local.get 0 local.get 1 return_call $f) (func (export \"run\") (param i32) (result i32) i32.const 9 local.get 0 call $h))",
      "(module (func $f (param i32 i64) (result i32 i64) local.get 0 local.get 1) (func (export \"run\") (param i32) (result i32) local.get 0 i64.const 7 call $f drop))",
      "(module (memory 1) (func $f (param i32 i32) (result i32) (local i32) block loop local.get 0 local.tee 2 drop local.get 1 br_if 1 br 1 end end local.get 2 i32.load) (func (export \"run\") (param i32) (result i32) local.get 0 i32.const 0 call $f))",
      "(module (type $s (struct (field i32))) (func $f (param i32 i32) (result (ref $s)) local.get 0 if (result (ref $s)) local.get 1 struct.new $s else i32.const 9 struct.new $s end) (func (export \"run\") (param i32) (result i32) local.get 0 i32.const 7 call $f struct.get $s 0))",
    ] {
    dae2_sparse_replay_compare(pass_test_module_from_wat(wat))
  }
}
