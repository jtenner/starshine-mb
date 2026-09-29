///|
test "DAE2 solved storage keeps demanded values and releases unused adjacency capacity" {
  let graph = Dae2Graph::new()
  ignore(graph.locations(16))
  graph.edge(0, 1)
  graph.edge(1, 2)
  graph.edge(4, 5)
  graph.edge(5, 4)
  graph.observe(0)
  graph.solve()
  assert_true(graph.used[0] && graph.used[1] && graph.used[2])
  assert_false(graph.used[4] || graph.used[5])
  let solved = graph.used.copy()
  let graph = graph.for_solved_rewrite()
  assert_eq(graph.used, solved)
  assert_eq(graph.edges.capacity(), 0)
  assert_eq(graph.next_edge.capacity(), 0)
  assert_eq(graph.first_edge.capacity(), 0)
  assert_eq(graph.last_edge.capacity(), 0)
  assert_eq(graph.work.capacity(), 0)
}

///|
test "DAE2 dependency storage release preserves active control and call signature changes" {
  let input = pass_test_module_from_wat(
    "(module (func $h (param i32 i32) (result i32) local.get 1) (func (export \"run\") (param i32) (result i32) block (result i32) i32.const 9 local.get 0 call $h end))",
  )
  let saved = @binary.encode_module(input).unwrap()
  for pass in ["dae2", "dae2-optimizing"] {
    let output = run_hot_pipeline(input, HotPipelineOptions::new(), [pass]).unwrap()
    @validate.validate_module(output).unwrap()
    assert_eq(
      @ir.hot_module_resolve_func_type(
        @ir.hot_module_context_from_module(output),
        @lib.FuncIdx::new(0U),
      ),
      Some(@lib.FuncType::new([@lib.ValType::i32()], [@lib.ValType::i32()])),
    )
    let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[1]
    assert_eq(body, [
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    ])
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}
