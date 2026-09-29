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
  assert_eq(graphs[0], 0)
  assert_eq(writes[0], 0)
}

///|
test "dae2 immutable reads retain parameter dependencies without local flow" {
  let input = pass_test_module_from_wat(
    "(module (func $helper (param i32 i32) (result i32) (local i32) local.get 1 local.get 2 i32.add) (func (export \"run\") (param i32) (result i32) i32.const 9 local.get 0 call $helper))",
  )
  let graphs = [0]
  let output = dae2_run_module_pass(
    input,
    false,
    local_graph_builds=Some(graphs),
  ).unwrap()
  @validate.validate_module(output).unwrap()
  let context = @ir.hot_module_context_from_module(output)
  assert_eq(
    @ir.hot_module_resolve_func_type(context, @lib.FuncIdx::new(0U)),
    Some(@lib.FuncType::new([@lib.ValType::i32()], [@lib.ValType::i32()])),
  )
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[1]
  assert_eq(body, [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
  ])
  assert_eq(graphs[0], 0)
  let dispatched = run_hot_pipeline(input, HotPipelineOptions::new(), ["dae2"]).unwrap()
  assert_eq(dispatched.code_sec, output.code_sec)
  assert_eq(dispatched.func_sec, output.func_sec)
}

///|
test "dae2 mutable branch reads still retain reaching writes" {
  let input = pass_test_module_from_wat(
    "(module (func $helper (param i32 i32 i32) (result i32) local.get 0 if local.get 1 local.set 2 end local.get 2) (func (export \"run\") (param i32 i32 i32) (result i32) local.get 0 local.get 1 local.get 2 call $helper))",
  )
  let graphs = [0]
  let output = dae2_run_module_pass(
    input,
    false,
    local_graph_builds=Some(graphs),
  ).unwrap()
  @validate.validate_module(output).unwrap()
  assert_eq(output.code_sec, input.code_sec)
  assert_eq(output.func_sec, input.func_sec)
  assert_eq(graphs[0], 1)
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
  let info = Dae2Function::new(graph, [@lib.ValType::i32()], [])
  info.assign_node_locations(graph, @ir.hot_node_count(func))
  let param = info.param_locations[0]
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
    assert_true(
      dae2_test_dependencies(graph, dae2_node_location(info, read)).contains(
        param,
      ),
    )
    assert_true(
      dae2_test_dependencies(graph, dae2_node_location(info, read)).contains(
        dae2_node_location(info, write),
      ),
    )
  }
  assert_eq(graphs[0], 1)
  assert_eq(writes[0], 1)
}
