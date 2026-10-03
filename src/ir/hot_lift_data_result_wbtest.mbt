///|
fn lift_data_check_unwrap(
  checked : HotLiftDataCheck,
) -> (TcState, Int, Array[ValType]) {
  match checked.error {
    Some(error) => abort("unexpected lift typecheck error: \{error}")
    None => (checked.state, checked.pop_count, checked.pushed)
  }
}

///|
test "lift data results preserve call lanes and independent pushed types" {
  let module_ = @wast.wast_to_binary_module(
    "(module (func (param i32) (result i32 i64) local.get 0 i64.const 9))",
  ).unwrap()
  let env = @validate.Env::new().with_module(module_)
  let stack = [@lib.ValType::f64(), @lib.ValType::i32()]
  let (after, popped, pushed) = hot_lift_impl_typecheck_data_instruction(
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
      @validate.make_state_owned(env, stack),
    )
    |> lift_data_check_unwrap
  assert_eq(popped, 1)
  assert_eq(pushed, [@lib.ValType::i32(), @lib.ValType::i64()])
  assert_eq(after.stack, [
    @lib.ValType::f64(),
    @lib.ValType::i32(),
    @lib.ValType::i64(),
  ])
  assert_true(physical_equal(after.stack, stack))
  after.stack.clear()
  assert_eq(pushed, [@lib.ValType::i32(), @lib.ValType::i64()])
}

///|
test "lift data results retain operand errors and polymorphic fallback" {
  let env = @validate.empty_env()
  let state = @validate.make_state(env, [@lib.ValType::i64()])
  assert_true(
    hot_lift_impl_typecheck_data_instruction(@lib.Instruction::i32_eqz(), state).error
    is Some(HotLiftError::TypecheckFailure(_, _)),
  )
  let state = hot_lift_impl_typecheck(
    @lib.Instruction::unreachable_(),
    @validate.make_state(env, []),
  ).unwrap()
  let (after, _, _) = hot_lift_impl_typecheck_data_instruction(
      @lib.Instruction::i32_add(),
      state,
    )
    |> lift_data_check_unwrap
  assert_false(after.reachable)
}
