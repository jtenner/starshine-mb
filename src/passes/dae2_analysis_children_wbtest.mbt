///|
test "dae2 immutable analysis avoids child snapshots while retaining dependency order" {
  let input = pass_test_module_from_wat(
    "(module (func (param i32 i32) (result i32) local.get 0 drop local.get 1 i32.const 7 i32.add))",
  )
  let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(0U))
  let revision = @ir.hot_revision_current(func)
  let before = @ir.hot_lower_func(func)
  let graph = Dae2Graph::new()
  let info = Dae2Function::new(
    graph,
    [@lib.ValType::i32(), @lib.ValType::i32()],
    [@lib.ValType::i32()],
  )
  info.assign_node_locations(graph, @ir.hot_node_count(func))
  let first = info.param_locations[0]
  let second = info.param_locations[1]
  let result = info.result_location
  let snapshots = [0]
  dae2_analyze_function(
    graph,
    [info],
    0,
    [],
    func,
    analysis_child_snapshots=Some(snapshots),
  )
  graph.observe(result)
  graph.solve()
  assert_false(graph.used[first])
  assert_true(graph.used[second])
  assert_eq(@ir.hot_revision_current(func), revision)
  assert_eq(@ir.hot_lower_func(func), before)
  assert_eq(snapshots[0], 0)
}
