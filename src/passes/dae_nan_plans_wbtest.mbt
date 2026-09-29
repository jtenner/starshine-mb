///|
test "DAE transaction commits unchanged shared NaN bodies while pruning arguments" {
  let input = pass_test_module_from_wat(
    "(module (func $h (param i32 i32) (result i32) local.get 1) (func (export \"run\") (param i32) (result i32) i32.const 9 local.get 0 call $h) (func (export \"nan\") (result f32) f32.const nan:0x400001))",
  )
  let saved = @binary.encode_module(input).unwrap()
  let original = dae_collect_original_boundary_snapshot(input)
  let graph = dae_current_boundary_graph_new(input)
  let local_use = dae_local_use_for_callee(graph.snapshot.funcs[0], 2, 0, 2)
  let plan = dae_build_scalar_unused_param_rewrite_plan(
    input,
    original,
    graph,
    0,
    [true, false],
    local_use,
    1,
    [1],
  ).unwrap()
  let application = dae_apply_rewrite_plan(input, graph, plan)
  assert_true(application.applied)
  let output = application.result.mod_out
  @validate.validate_module(output).unwrap()
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
  let @lib.Func(_, @lib.Expr(before_nan)) = input.code_sec.unwrap().0[2]
  let @lib.Func(_, @lib.Expr(after_nan)) = output.code_sec.unwrap().0[2]
  assert_eq(after_nan.length(), 1)
  assert_true(pass_const_instruction_bits_equal(before_nan[0], after_nan[0]))
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}
