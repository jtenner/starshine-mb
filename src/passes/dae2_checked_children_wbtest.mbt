///|
fn dae2_checked_children_dependencies(func : @ir.HotFunc) -> (Bool, Bool) raise {
  let graph = Dae2Graph::new()
  let info = Dae2Function::new(
    graph,
    [@lib.ValType::i32(), @lib.ValType::i32()],
    [@lib.ValType::i32()],
  )
  info.assign_node_locations(graph, @ir.hot_node_count(func))
  let revision = @ir.hot_revision_current(func)
  let children = func.children.copy()
  let lowered = @ir.hot_lower_func(func)
  dae2_analyze_function(graph, [info], 0, [], func)
  graph.observe(info.result_location)
  graph.solve()
  assert_eq(@ir.hot_revision_current(func), revision)
  assert_eq(func.children, children)
  assert_eq(@ir.hot_lower_func(func), lowered)
  (graph.used[info.param_locations[0]], graph.used[info.param_locations[1]])
}

///|
test "DAE2 checked child analysis reads current slots after edits and skips deleted nodes" {
  let input = pass_test_module_from_wat(
    "(module (func (param i32 i32) (result i32) local.get 0 local.get 1 i32.add))",
  )
  let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(0U))
  let mut second = -1
  let mut binary = -1
  for id in 0..<@ir.hot_node_count(func) {
    let node = @ir.hot_node_get(func, id)
    if node.op is @ir.LocalGet && node.imm0 == 1 {
      second = id
    }
    if node.op is @ir.Binary {
      binary = id
    }
  }
  assert_true(second >= 0 && binary >= 0)
  let detached = @ir.hot_build_nop(func)
  @ir.hot_delete_detached_node(func, detached)
  assert_eq(dae2_checked_children_dependencies(func), (true, true))
  @ir.hot_child_set(func, binary, 0, second)
  assert_eq(dae2_checked_children_dependencies(func), (false, true))
}
