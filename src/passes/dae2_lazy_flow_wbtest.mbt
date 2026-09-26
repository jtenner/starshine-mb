///|
test "dae2 skips local analyses when signature pruning has no local reads" {
  let input = pass_test_module_from_wat(
    "(module (func $helper (param i32) (result i32) i32.const 7) (func (export \"run\") (result i32) i32.const 8 call $helper))",
  )
  let graphs = [0]
  let writes = [0]
  let output = dae2_run_module_pass(
    input,
    false,
    local_graph_builds=Some(graphs),
    fallback_write_builds=Some(writes),
  ).unwrap()
  @validate.validate_module(output).unwrap()
  let context = @ir.hot_module_context_from_module(output)
  assert_eq(
    @ir.hot_module_resolve_func_type(context, @lib.FuncIdx::new(0U)),
    Some(@lib.FuncType::new([], [@lib.ValType::i32()])),
  )
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[1]
  assert_eq(body, [@lib.Instruction::call(@lib.FuncIdx::new(0U))])
  assert_eq(graphs[0], 0)
  assert_eq(writes[0], 0)
}

///|
test "dae2 resolved parameter reads do not need a fallback write index" {
  let input = pass_test_module_from_wat(
    "(module (func $helper (param i32) (result i32) local.get 0) (func (export \"run\") (param i32) (result i32) local.get 0 call $helper))",
  )
  let graphs = [0]
  let writes = [0]
  let output = dae2_run_module_pass(
    input,
    false,
    local_graph_builds=Some(graphs),
    fallback_write_builds=Some(writes),
  ).unwrap()
  @validate.validate_module(output).unwrap()
  assert_eq(output.code_sec, input.code_sec)
  assert_eq(output.func_sec, input.func_sec)
  assert_eq(graphs[0], 2)
  assert_eq(writes[0], 0)
}

///|
test "dae2 intentionally unrepresented reads retain entry and write dependencies" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()]),
  )
  // Deliberately omit roots so these live nodes have no represented CFG source.
  let write = @ir.hot_build_local_set(
    func,
    0,
    @ir.hot_build_const_i32(func, @lib.I32(11)),
  )
  let get = @ir.hot_build_local_get(func, 0)
  let other = @ir.hot_build_local_get(func, 0)
  let graph = Dae2Graph::new()
  let param = graph.location()
  let result = graph.location()
  let info : Dae2Function = {
    params: [@lib.ValType::i32()],
    results: [],
    param_locations: [param],
    result_location: result,
    node_locations: Array::makei(@ir.hot_node_count(func), fn(_) {
      graph.location()
    }),
    call_infos: [],
  }
  let graphs = [0]
  let writes = [0]
  dae2_analyze_function(
    graph,
    [info],
    0,
    [],
    func,
    local_graph_builds=Some(graphs),
    fallback_write_builds=Some(writes),
  )
  for read in [get, other] {
    assert_true(graph.edges[info.node_locations[read]].contains(param))
    assert_true(
      graph.edges[info.node_locations[read]].contains(
        info.node_locations[write],
      ),
    )
  }
  assert_eq(graphs[0], 1)
  assert_eq(writes[0], 1)
}
