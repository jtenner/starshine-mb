///|
fn dae2_lazy_children_fixture(
  observed : Bool,
) -> (Dae2Graph, Array[Dae2Function], @ir.HotFunc, Int, HotPipelineLowerState) {
  let input = pass_test_module_from_wat(
    "(module (func (result i32) i32.const 7 i32.const 11 i32.add))",
  )
  let func = dae2_lift_for_analysis(
    input,
    @ir.hot_module_context_from_module(input),
    0,
  ).unwrap()
  let graph = Dae2Graph::new()
  let info = Dae2Function::new(graph, [], [@lib.ValType::i32()])
  info.assign_node_locations(graph, @ir.hot_node_count(func))
  dae2_analyze_function(graph, [info], 0, [], func)
  if observed {
    graph.observe(info.result_location)
  }
  graph.solve()
  let state : HotPipelineLowerState = {
    next_type_sec: input.type_sec,
    type_sec_changed: false,
  }
  (graph, [info], func, @ir.hot_root_get(func, 0), state)
}

///|
test "DAE2 unchanged child rewrites borrow slots and preserve the original encoded expression" {
  let (graph, infos, func, root, state) = dae2_lazy_children_fixture(true)
  let saved = @ir.hot_lower_func_unverified(func)
  let revision = @ir.hot_revision_current(func)
  let memo = Array::make(@ir.hot_node_count(func), -1)
  let arities = Array::makei(memo.length(), fn(node) {
    @ir.hot_node_result_arity(func, node)
  })
  assert_true(
    dae2_rewrite_children(graph, infos, 0, func, root, memo, arities, state, [])
    is None,
  )
  assert_eq(@ir.hot_revision_current(func), revision)
  assert_eq(@ir.hot_lower_func_unverified(func), saved)
  @ir.hot_verify_core(func).unwrap()
}

///|
test "DAE2 changed child rewrites own one independent replacement snapshot" {
  let (graph, infos, func, root, state) = dae2_lazy_children_fixture(false)
  let saved = @ir.hot_child_span(func, root)
  let memo = Array::make(@ir.hot_node_count(func), -1)
  let arities = Array::makei(memo.length(), fn(node) {
    @ir.hot_node_result_arity(func, node)
  })
  let replacements = dae2_rewrite_children(
    graph,
    infos,
    0,
    func,
    root,
    memo,
    arities,
    state,
    [],
  ).unwrap()
  assert_eq(replacements.length(), saved.length())
  for child in replacements {
    assert_true(@ir.hot_node_op(func, child) is @ir.Nop)
  }
  assert_eq(@ir.hot_child_span(func, root), saved)
  replacements[0] = saved[0]
  assert_eq(@ir.hot_child_span(func, root), saved)
  @ir.hot_verify_core(func).unwrap()
}
