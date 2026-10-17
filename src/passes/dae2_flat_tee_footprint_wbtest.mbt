///|
fn dae2_flat_tee_footprint_fixture(mode : Int32, width : Int32) -> @lib.Module {
  let body = []
  if mode == 1 {
    body.push("i32.const 0")
  }
  for _ in 0..<width {
    body.push("local.get 0 local.tee 2")
    if mode == 1 {
      body.push("i32.add")
    } else if mode == 2 {
      body.push("i32.const 0 i32.div_s global.set $g")
    } else {
      body.push("global.set $g")
    }
  }
  if mode == 1 {
    body.push("global.set $g")
  }
  pass_test_module_from_wat(
    "(module (global $g (export \"g\") (mut i32) (i32.const 0)) (func $h (param i32 i64) (local i32) \{body.join(" ")}) (func (export \"run\") (param i32) local.get 0 i64.const 9 call $h))",
  )
}

///|
fn dae2_flat_tee_footprint_plan(
  input : @lib.Module,
) -> (Dae2Graph, Dae2Function, Dae2RawPlan) {
  let context = @ir.hot_module_context_from_module(input)
  let graph = Dae2Graph::new()
  let @lib.FuncType(params, results) = @ir.hot_module_resolve_func_type(
    context,
    @lib.FuncIdx::new(0U),
  ).unwrap()
  let info = Dae2Function::new(graph, params, results)
  let plan = dae2_raw_dependency_plan(
    graph,
    [info],
    0,
    [],
    input.code_sec.unwrap().0[0],
    None,
    module_context=Some(context),
  ).unwrap()
  plan.commit(graph)
  graph.solve()
  (graph, info, plan)
}

///|
fn dae2_flat_tee_footprint_check(
  input : @lib.Module,
  width : Int32,
) -> Unit raise {
  let saved = @binary.encode_module(input).unwrap()
  for closed_world in [false, true] {
    let analysis = [0]
    let rewrite = [0]
    let actual = dae2_run_module_pass(
      input,
      closed_world,
      analysis_lifts=Some(analysis),
      rewrite_lifts=Some(rewrite),
    ).unwrap()
    let expected = dae2_run_module_pass(
      input,
      closed_world,
      raw_analysis=false,
      raw_rewrite=false,
    ).unwrap()
    @validate.validate_module(actual).unwrap()
    assert_eq(analysis[0], 0)
    assert_eq(rewrite[0], 0)
    assert_eq(
      @ir.hot_module_resolve_func_type(
        @ir.hot_module_context_from_module(actual),
        @lib.FuncIdx::new(0U),
      ),
      Some(@lib.FuncType::new([@lib.ValType::i32()], [])),
    )
    assert_eq(actual.code_sec, expected.code_sec)
    assert_eq(
      @binary.encode_module(actual).unwrap(),
      @binary.encode_module(expected).unwrap(),
    )
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
  let (graph, info, plan) = dae2_flat_tee_footprint_plan(input)
  // Reusing a Tee write can make later binary joins distinct. Bound both the
  // existing write rows and those joins, instead of claiming zero allocation.
  assert_true(plan.count <= 2 * width)
  assert_true(plan.sources.length() <= 3 * width)
  assert_true(plan.observations.length() <= 3 * width + 1)
  assert_true(graph.work.length() <= 2 * width + 1)
  assert_eq(graph.cursor, graph.work.length())
  assert_true(graph.used[info.param_locations[0]])
  assert_false(graph.used[info.param_locations[1]])
  let writes = plan.write_locations.unwrap()
  assert_eq(writes.length(), width)
  for (local_id, location) in writes {
    assert_eq(local_id, 2)
    assert_true(graph.used[location])
  }
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "DAE2 flat Tee direct consumers keep complete demand and linear graph work" {
  for width in [1, 8, 32] {
    dae2_flat_tee_footprint_check(
      dae2_flat_tee_footprint_fixture(0, width),
      width,
    )
  }
}

///|
test "DAE2 flat Tee chained joins keep complete demand and linear graph work" {
  for width in [1, 8, 32] {
    dae2_flat_tee_footprint_check(
      dae2_flat_tee_footprint_fixture(1, width),
      width,
    )
  }
}

///|
test "DAE2 flat Tee trapping consumers keep complete demand effects and linear graph work" {
  for width in [1, 8, 32] {
    dae2_flat_tee_footprint_check(
      dae2_flat_tee_footprint_fixture(2, width),
      width,
    )
  }
}
