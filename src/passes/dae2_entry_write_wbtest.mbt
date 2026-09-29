///|
test "DAE2 single entry writes retain earlier parameter reads without building local flow" {
  let input = pass_test_module_from_wat(
    "(module (func $h (param i32 i32 i32) (result i32) local.get 1 i32.const 1 i32.add local.set 1 local.get 1) (func (export \"run\") (param i32) (result i32) i32.const 9 local.get 0 i32.const 8 call $h))",
  )
  let graphs = [0]
  let output = dae2_run_module_pass(
    input,
    false,
    local_graph_builds=Some(graphs),
  ).unwrap()
  @validate.validate_module(output).unwrap()
  assert_eq(graphs[0], 0)
  assert_eq(
    @ir.hot_module_resolve_func_type(
      @ir.hot_module_context_from_module(output),
      @lib.FuncIdx::new(0U),
    ),
    Some(@lib.FuncType::new([@lib.ValType::i32()], [@lib.ValType::i32()])),
  )
  let @lib.Func(_, @lib.Expr(caller)) = output.code_sec.unwrap().0[1]
  assert_eq(caller, [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
  ])
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_eq(body, [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  ])
}

///|
test "DAE2 entry-write proof excludes conditional and repeated writes" {
  for
    body in [
      "local.get 0 if local.get 1 local.set 2 end local.get 2", "local.get 1 local.set 2 local.get 0 if local.get 0 local.set 2 end local.get 2",
    ] {
    let input = pass_test_module_from_wat(
      "(module (func $h (param i32 i32 i32 i32) (result i32) \{body}) (func (export \"run\") (param i32 i32 i32) (result i32) local.get 0 local.get 1 local.get 2 i32.const 9 call $h))",
    )
    let graphs = [0]
    let output = dae2_run_module_pass(
      input,
      false,
      local_graph_builds=Some(graphs),
    ).unwrap()
    @validate.validate_module(output).unwrap()
    assert_eq(graphs[0], 1)
    let expected_params = if body.starts_with("local.get 0") { 3 } else { 2 }
    let params = match
      @ir.hot_module_resolve_func_type(
        @ir.hot_module_context_from_module(output),
        @lib.FuncIdx::new(0U),
      ) {
      Some(@lib.FuncType(params, _)) => params
      _ => fail("missing helper signature")
    }
    assert_eq(params.length(), expected_params)
  }
}
