///|
fn dae2_preflight_test_plan(
  input : @lib.Module,
  route : Int32,
) -> (Dae2Graph, Dae2Function, Dae2RawPlan?) {
  let context = @ir.hot_module_context_from_module(input)
  let @lib.FuncType(params, results) = @ir.hot_module_resolve_func_type(
    context,
    @lib.FuncIdx::new(0U),
  ).unwrap()
  let graph = Dae2Graph::new()
  let info = Dae2Function::new(graph, params, results)
  let body = input.code_sec.unwrap().0[0]
  let @lib.Func(_, @lib.Expr(instructions)) = body
  let count = dae2_raw_forward_instruction_count(instructions, Some(context))
  let plan = match route {
    0 =>
      dae2_raw_local_flow_dependency_plan(
        graph,
        [info],
        0,
        [],
        body,
        None,
        Some(context),
      )
    1 =>
      dae2_raw_local_flow_dependency_plan_with_count(
        graph,
        [info],
        0,
        [],
        body,
        None,
        Some(context),
        count,
      )
    2 =>
      dae2_raw_forward_dependency_plan(
        graph,
        [info],
        0,
        [],
        body,
        None,
        Some(context),
      )
    3 =>
      dae2_raw_forward_dependency_plan_with_count(
        graph,
        [info],
        0,
        [],
        body,
        None,
        Some(context),
        count,
      )
    4 =>
      dae2_raw_conditional_dependency_plan(
        graph,
        [info],
        0,
        [],
        body,
        None,
        Some(context),
      )
    _ =>
      dae2_raw_dependency_plan(
        graph,
        [info],
        0,
        [],
        body,
        None,
        module_context=Some(context),
      )
  }
  (graph, info, plan)
}

///|
fn dae2_preflight_assert_plan(
  actual : Dae2RawPlan,
  expected : Dae2RawPlan,
) -> Unit raise {
  assert_eq(actual.base, expected.base)
  assert_eq(actual.count, expected.count)
  assert_eq(actual.consumers, expected.consumers)
  assert_eq(actual.sources, expected.sources)
  assert_eq(actual.observations, expected.observations)
  assert_eq(actual.write_locations, expected.write_locations)
}

///|
test "DAE2 shared preflight workers preserve standalone plans and uncommitted graphs" {
  for
    body in [
      "local.get 1", "local.get 0 if (result i32) local.get 1 else local.get 2 end",
      "local.get 1 local.set 3 block $out local.get 0 br_if $out local.get 2 local.set 3 end local.get 3",
      "block $out block $inner local.get 1 local.set 3 local.get 0 br_table $inner $out $inner end local.get 2 local.set 3 end local.get 3",
      "local.get 1 loop (type $scalar) end",
    ] {
    let input = pass_test_module_from_wat(
      "(module (type $scalar (func (param i32) (result i32))) (func (param i32 i32 i32) (result i32) (local i32) \{body}))",
    )
    @validate.validate_module(input).unwrap()
    let saved = @binary.encode_module(input).unwrap()
    for route in [0, 2] {
      let (graph, info, standalone) = dae2_preflight_test_plan(input, route)
      let (shared_graph, shared_info, shared) = dae2_preflight_test_plan(
        input,
        route + 1,
      )
      dae2_preflight_assert_plan(shared.unwrap(), standalone.unwrap())
      for (graph, info) in [(graph, info), (shared_graph, shared_info)] {
        assert_eq(graph.used.length(), info.params.length() + 1)
        assert_true(graph.edges.is_empty())
        assert_true(graph.work.is_empty())
      }
    }
    raw_conditional_compare_boundaries(input, 1)
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
test "DAE2 shared preflight intentionally rejects a late unsupported instruction without graph changes" {
  let prefix = Array::make(64, "nop").join(" ")
  let input = pass_test_module_from_wat(
    "(module (memory 1) (func (param i32 i32 i32) (result i32) block local.get 0 br_if 0 end \{prefix} i32.const 0 i32.const 0 i32.const 0 memory.copy local.get 1))",
  )
  @validate.validate_module(input).unwrap()
  let context = @ir.hot_module_context_from_module(input)
  let @lib.Func(_, @lib.Expr(instructions)) = input.code_sec.unwrap().0[0]
  assert_false(dae2_raw_conditional_qualified(instructions, Some(context)))
  assert_eq(dae2_raw_forward_instruction_count(instructions, Some(context)), -1)
  // Standalone admission and both dispatch levels must leave HOT fallback a
  // pristine graph. Counted workers require successful preflight, so omit them.
  for route in [0, 2, 4, 5] {
    let (graph, info, plan) = dae2_preflight_test_plan(input, route)
    assert_true(plan is None)
    assert_eq(graph.used.length(), info.params.length() + 1)
    assert_true(graph.edges.is_empty())
    assert_true(graph.work.is_empty())
  }
  raw_conditional_compare_boundaries(input, 0)
}

///|
test "DAE2 shared preflight gives forward fallback a fresh budget after local flow exhausts its own" {
  let initial = Array::makei(32, fn(i) { "local.get 1 local.set \{i + 4}" }).join(
    " ",
  )
  let exits = Array::make(64, "local.get 2 local.set 4 local.get 0 br_if $out").join(
    " ",
  )
  let result = Array::makei(32, fn(i) { "local.get \{i + 4} i32.add" }).join(
    " ",
  )
  let input = dae2_first_input_fixture(
    "\{initial} block $out \{exits} end i32.const 0 \{result}",
    locals=32,
  )
  @validate.validate_module(input).unwrap()
  let context = @ir.hot_module_context_from_module(input)
  let @lib.Func(_, @lib.Expr(instructions)) = input.code_sec.unwrap().0[0]
  assert_false(dae2_raw_conditional_qualified(instructions, Some(context)))
  assert_true(
    dae2_raw_forward_instruction_count(instructions, Some(context)) > 0,
  )
  for route in [0, 1] {
    let (graph, info, plan) = dae2_preflight_test_plan(input, route)
    assert_true(plan is None)
    assert_eq(graph.used.length(), info.params.length() + 1)
    assert_true(graph.edges.is_empty())
    assert_true(graph.work.is_empty())
  }
  let (_, _, expected) = dae2_preflight_test_plan(input, 2)
  for route in [3, 4, 5] {
    let (graph, info, plan) = dae2_preflight_test_plan(input, route)
    let plan = plan.unwrap()
    dae2_preflight_assert_plan(plan, expected.unwrap())
    plan.commit(graph)
    graph.observe(info.result_location)
    graph.solve()
    assert_eq(info.param_locations.map(fn(location) { graph.used[location] }), [
      true, true, true, false,
    ])
  }
  raw_conditional_compare_boundaries(input, 2)
}
