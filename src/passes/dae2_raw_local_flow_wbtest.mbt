///|
test "DAE2 demand-driven local flow preserves every eager boundary and writer demand" {
  for
    body in [
      "local.get 1 local.set 4 block $out local.get 0 br_if $out local.get 2 local.set 4 end local.get 4",
      "block $out local.get 0 br_if $out local.get 1 local.set 4 end local.get 4",
      "local.get 1 local.set 4 loop $again local.get 4 local.set 5 local.get 2 local.set 4 local.get 0 br_if $again end local.get 5",
      "block $out loop $again local.get 4 local.get 5 local.set 4 local.set 5 local.get 0 br_if $out local.get 2 br_if $again end end local.get 5",
      "local.get 0 if local.get 1 local.set 4 else local.get 2 local.set 4 end block local.get 0 br_if 0 end local.get 4",
      "block $out block $inner local.get 1 local.set 4 local.get 0 br_table $inner $out $inner end local.get 2 local.set 4 end local.get 4",
      "local.get 1 block $out (result i32) local.get 2 local.get 0 br_if $out drop i32.const 7 end i32.add",
      "local.get 1 local.get 0 br_if 0 drop local.get 2", "block $out local.get 0 if local.get 1 local.set 4 br $out else local.get 2 local.set 4 end end local.get 4",
    ] {
    let input = dae2_first_input_fixture(body)
    @validate.validate_module(input).unwrap()
    let saved = @binary.encode_module(input).unwrap()
    for closed_world in [false, true] {
      let writes = []
      let old_writes = []
      let hot_writes = []
      let (actual, admitted) = raw_conditional_boundary_bits(
        input,
        true,
        closed_world~,
        forward_flow=Some(true),
        write_demands=Some(writes),
      )
      let (old, _) = raw_conditional_boundary_bits(
        input,
        true,
        closed_world~,
        forward_flow=Some(false),
        write_demands=Some(old_writes),
      )
      let (hot, _) = raw_conditional_boundary_bits(
        input,
        false,
        closed_world~,
        write_demands=Some(hot_writes),
      )
      assert_eq(actual, old)
      assert_eq(actual, hot)
      assert_eq(writes, old_writes)
      assert_eq(writes, hot_writes)
      assert_eq(admitted, 2)
      assert_eq(@binary.encode_module(input).unwrap(), saved)
    }
  }
}

///|
test "DAE2 local flow resolves never-written parameters without predecessor expansion" {
  let input = pass_test_module_from_wat(
    "(module (func (param i32 i32 i32) (result i32) (local i32) local.get 0 if i32.const 1 local.set 3 else i32.const 2 local.set 3 end local.get 1))",
  )
  @validate.validate_module(input).unwrap()
  let context = @ir.hot_module_context_from_module(input)
  let @lib.FuncType(params, results) = @ir.hot_module_resolve_func_type(
    context,
    @lib.FuncIdx::new(0U),
  ).unwrap()
  let graph = Dae2Graph::new()
  let info = Dae2Function::new(graph, params, results)
  let plan = Dae2RawPlan::new(graph.used.length())
  let flow = Dae2RawLocalFlow::new(
    Dae2RawControlState::new(plan, [info], 0, [], 1, None, Some(context)),
    info.param_locations,
    1000,
  )
  let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  assert_eq(flow.body(body, 0, 1), Some(true))
  let queries = flow.query_blocks.length()
  plan.edge(info.result_location, flow.state.stack[0])
  assert_true(flow.resolve())
  plan.commit(graph)
  graph.observe(info.result_location)
  graph.solve()
  assert_eq(info.param_locations.map(fn(location) { graph.used[location] }), [
    true, true, false,
  ])
  assert_eq(
    plan.write_locations.unwrap().map(fn(write) { graph.used[write.1] }),
    [false, false],
  )
  assert_eq(flow.query_blocks.length(), queries)
}
