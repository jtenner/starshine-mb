///|
test "DAE2 compact node locations preserve graph numbering and invalid-node boundaries" {
  let graph = Dae2Graph::new()
  let first = graph.location()
  let base = graph.locations(4)
  let last = graph.location()
  assert_eq((first, base, last), (0, 1, 5))
  let info = Dae2Function::new(graph, [@lib.ValType::i32()], [
    @lib.ValType::i32(),
  ])
  info.assign_node_locations(graph, 3)
  assert_eq(info.node_count, 3)
  assert_eq(dae2_node_location(info, 0), 8)
  assert_eq(dae2_node_location(info, 2), 10)
  assert_eq(dae2_node_location(info, -1), -1)
  assert_eq(dae2_node_location(info, 3), -1)
  assert_eq(graph.first_edge, Array::make(11, -1))
  assert_eq(graph.last_edge, Array::make(11, -1))
  assert_eq(graph.used, Array::make(11, false))
  graph.edge(last, base)
  graph.edge(base, dae2_node_location(info, 2))
  graph.observe(last)
  graph.solve()
  assert_true(graph.used[base])
  assert_true(graph.used[10])
  assert_false(graph.used[first])
  assert_false(graph.used[8])
}

///|
test "DAE2 bulk graph allocation keeps spare capacity across neighboring bodies" {
  let graph = Dae2Graph::new()
  assert_eq(graph.locations(5), 0)
  assert_eq(graph.locations(1), 5)
  let capacity = graph.used.capacity()
  assert_eq(graph.locations(1), 6)
  assert_eq(graph.used.capacity(), capacity)
  assert_eq(graph.first_edge.capacity(), capacity)
  assert_eq(graph.last_edge.capacity(), capacity)
  assert_eq(graph.used.length(), 7)
}

///|
test "DAE2 dependency analysis records repeated callees for rewrite admission" {
  let input = pass_test_module_from_wat(
    "(module (func $h (param i32 i32) (result i32) local.get 1) (func (param i32) (result i32) i32.const 9 local.get 0 call $h drop i32.const 8 local.get 0 call $h))",
  )
  let graph = Dae2Graph::new()
  let helper = Dae2Function::new(
    graph,
    [@lib.ValType::i32(), @lib.ValType::i32()],
    [@lib.ValType::i32()],
  )
  let caller = Dae2Function::new(graph, [@lib.ValType::i32()], [
    @lib.ValType::i32(),
  ])
  let funcs = [
    @ir.hot_lift_func(input, @lib.FuncIdx::new(0U)),
    @ir.hot_lift_func(input, @lib.FuncIdx::new(1U)),
  ]
  let infos = [helper, caller]
  for index in 0..<2 {
    infos[index].assign_node_locations(graph, @ir.hot_node_count(funcs[index]))
    dae2_analyze_function(graph, infos, index, [], funcs[index])
  }
  assert_eq(caller.call_infos, [0, 0])
  graph.observe(caller.param_locations[0])
  graph.observe(caller.result_location)
  graph.solve()
  assert_false(graph.used[helper.param_locations[0]])
  assert_true(graph.used[helper.param_locations[1]])
  assert_true(dae2_function_needs_rewrite(graph, infos, caller))
}
