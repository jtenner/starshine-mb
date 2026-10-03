///|
test "lift scalar results reuse only the caller scratch and clear empty results" {
  let scratch = [@lib.ValType::i64()]
  let state = @validate.make_state(@validate.empty_env(), [])
  let first = hot_lift_impl_typecheck_data_instruction(
    @lib.Instruction::i32_const(@lib.I32(7)),
    state,
    scalar_results=Some(scratch),
  )
  assert_true(first.error is None)
  assert_eq(scratch, [@lib.ValType::i32()])
  assert_true(physical_equal(first.pushed, scratch))
  assert_false(physical_equal(first.state.stack, scratch))
  let second = hot_lift_impl_typecheck_data_instruction(
    @lib.Instruction::drop(),
    first.state,
    scalar_results=Some(scratch),
  )
  assert_true(second.error is None)
  assert_eq(second.pushed, [])
  assert_true(physical_equal(second.pushed, scratch))
  assert_eq(second.state.stack, [])
}

///|
test "lift scalar scratch releases old types when typechecking fails" {
  let scratch = [@lib.ValType::i64()]
  let checked = hot_lift_impl_typecheck_data_instruction(
    @lib.Instruction::i32_add(),
    @validate.make_state(@validate.empty_env(), []),
    scalar_results=Some(scratch),
  )
  assert_true(checked.error is Some(HotLiftError::TypecheckFailure(_, _)))
  assert_eq(scratch, [])
}

///|
test "lift multi results keep owned interned types across scalar scratch reuse" {
  let module_ = @wast.wast_to_binary_module(
    "(module (func (result i32 i64) i32.const 7 i64.const 9))",
  ).unwrap()
  let scratch : Array[@lib.ValType] = []
  let state = @validate.make_state(@validate.Env::new().with_module(module_), [])
  let pair = hot_lift_impl_typecheck_data_instruction(
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    state,
    scalar_results=Some(scratch),
  )
  assert_true(pair.error is None)
  assert_false(physical_equal(pair.pushed, scratch))
  let func = HotFunc::new()
  let ty = hot_lift_impl_result_type(func, pair.pushed)
  let next = hot_lift_impl_typecheck_data_instruction(
    @lib.Instruction::f64_const(@lib.F64(1.5)),
    pair.state,
    scalar_results=Some(scratch),
  )
  assert_true(next.error is None)
  assert_eq(pair.pushed, [@lib.ValType::i32(), @lib.ValType::i64()])
  assert_eq(
    hot_type_get(func, ty),
    HotTypeInfo::Results([@lib.ValType::i32(), @lib.ValType::i64()]),
  )
  assert_eq(next.pushed, [@lib.ValType::f64()])
}
