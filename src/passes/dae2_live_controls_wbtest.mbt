///|
fn dae2_live_control_fixture(
  depth : Int,
  debris : Bool,
) -> (Dae2Graph, Array[Dae2Function], @ir.HotFunc, Int, HotPipelineLowerState) {
  let parts : Array[String] = ["(module (func (result i32)"]
  for _ in 0..<depth {
    parts.push("(block (result i32) (loop (result i32)")
    if debris {
      parts.push("(drop (i64.const 99))")
    }
    parts.push("(if (result i32) (i32.const 1) (then")
  }
  parts.push("(i32.const 7)")
  for _ in 0..<depth {
    parts.push(") (else (i32.const 11)))))")
  }
  parts.push("))")
  let input = pass_test_module_from_wat(parts.join(""))
  let func = dae2_lift_for_analysis(
    input,
    @ir.hot_module_context_from_module(input),
    0,
  ).unwrap()
  let graph = Dae2Graph::new()
  let info = Dae2Function::new(graph, [], [@lib.ValType::i32()])
  info.assign_node_locations(graph, @ir.hot_node_count(func))
  dae2_analyze_function(graph, [info], 0, [], func)
  graph.observe(info.result_location)
  graph.solve()
  let state : HotPipelineLowerState = {
    next_type_sec: input.type_sec,
    type_sec_changed: false,
  }
  (graph, [info], func, @ir.hot_root_get(func, 0), state)
}

///|
test "DAE2 live control rewrites keep complete unchanged nested bodies" {
  let (graph, infos, func, root, state) = dae2_live_control_fixture(3, false)
  let saved = @ir.hot_lower_func_unverified(func)
  let revision = @ir.hot_revision_current(func)
  let memo = Array::make(@ir.hot_node_count(func), -1)
  let arities = Array::makei(memo.length(), fn(node) {
    @ir.hot_node_result_arity(func, node)
  })
  assert_eq(
    dae2_rewrite_node(graph, infos, 0, func, root, memo, arities, state, []),
    root,
  )
  // Every original descendant is still visited, including both arms.
  for node in 0..<memo.length() {
    assert_eq(memo[node], node)
  }
  assert_eq(@ir.hot_revision_current(func), revision)
  assert_eq(@ir.hot_lower_func_unverified(func), saved)
  @ir.hot_verify_core(func).unwrap()
}

///|
test "DAE2 live controls retain child cleanup before keeping the parent" {
  let (graph, infos, func, root, state) = dae2_live_control_fixture(2, true)
  let saved = @ir.hot_lower_func_unverified(func)
  let memo = Array::make(@ir.hot_node_count(func), -1)
  let arities = Array::makei(memo.length(), fn(node) {
    @ir.hot_node_result_arity(func, node)
  })
  assert_eq(
    dae2_rewrite_node(graph, infos, 0, func, root, memo, arities, state, []),
    root,
  )
  let mut changed = 0
  for node in 0..<memo.length() {
    assert_true(memo[node] >= 0)
    if memo[node] != node {
      changed += 1
    }
  }
  assert_true(changed >= 4)
  assert_true(@ir.hot_lower_func_unverified(func) != saved)
  assert_eq(@ir.hot_node_result_arity(func, root), 1)
  @ir.hot_verify_core(func).unwrap()
}
