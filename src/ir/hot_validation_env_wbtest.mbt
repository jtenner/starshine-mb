///|
test "module validation context reuses metadata while isolating sibling body state" {
  let input = @wast.wast_to_binary_module(
    "(module (global $g i64 (i64.const 11)) (func (param i32) (result i32) local.get 0) (func (param i64) (result i64) local.get 0) (func (result i64) global.get $g))",
  ).unwrap()
  let context = hot_module_context_from_module(input)
  let env : @validate.Env = hot_module_context_validation_env(context)
  for index in 0..<3 {
    let signature = hot_module_resolve_func_type(
      context,
      @lib.FuncIdx::new(index.to_uint()),
    ).unwrap()
    @validate.validate_func_body_against_functype(
      env,
      signature,
      input.code_sec.unwrap().0[index],
    ).unwrap()
    assert_eq(env.labels.length(), 0)
    assert_eq(env.locals.length(), 0)
    assert_true(env.return_type is None)
  }
  let invalid = @lib.Func::new(
    @lib.Locals::new([]),
    @lib.Expr::new([@lib.Instruction::drop()]),
  )
  // An intentionally invalid body must still fail with the reusable context.
  assert_true(
    @validate.validate_func_body_against_functype(
      env,
      @lib.FuncType::new([], []),
      invalid,
    ).is_err(),
  )
}
