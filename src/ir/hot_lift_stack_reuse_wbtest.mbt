///|
test "HOT known-arity typechecking consumes its owned stack without copying" {
  let stack = [@lib.ValType::i64(), @lib.ValType::i32(), @lib.ValType::i32()]
  let state = @validate.make_state_owned(@validate.empty_env(), stack)
  let (after, popped, pushed) = hot_lift_impl_typecheck_data_instruction(
    @lib.Instruction::i32_add(),
    state,
  ).unwrap()
  assert_eq(popped, 2)
  assert_eq(pushed, [@lib.ValType::i32()])
  assert_eq(after.stack, [@lib.ValType::i64(), @lib.ValType::i32()])
  assert_true(physical_equal(after.stack, stack))
}

///|
test "HOT owned-stack typechecking preserves typed control and rejects invalid operands" {
  let source = "(module (func (param i32) (result i32) local.get 0 if (result i32) i32.const 4 i32.const 3 i32.add else i32.const 4 i32.const 2 i32.add end))"
  let module_ = @wast.wast_to_binary_module(source).unwrap()
  @validate.validate_module(module_).unwrap()
  let original_bytes = @binary.encode_module(module_).unwrap()
  let original = module_.code_sec.unwrap().0[0]
  let context = hot_module_context_from_module(module_)
  let func = hot_lift_func_with_context_result(
    module_,
    @lib.FuncIdx::new(0U),
    context,
  ).unwrap()
  let lowered = hot_lower_func(func)
  match
    @validate.validate_module(
      module_.with_code_sec(@lib.CodeSec::new([lowered])),
    ) {
    Ok(_) => ()
    Err(err) => fail("lowered stack fixture: \{err}")
  }
  assert_eq(module_.code_sec.unwrap().0[0], original)
  assert_eq(@binary.encode_module(module_).unwrap(), original_bytes)
  let state = @validate.make_state_owned(@validate.empty_env(), [
    @lib.ValType::i64(),
    @lib.ValType::i32(),
  ])
  assert_true(
    hot_lift_impl_typecheck_data_instruction(@lib.Instruction::i32_add(), state)
    is Err(_),
  )
}

///|
test "HOT region stacks preserve shared exception payload signatures" {
  let module_ = @wast.wast_to_binary_module(
    "(module (tag $e (param i32)) (func (result i32) (try (result i32) (do (i32.const 7) (throw $e)) (catch $e (i32.const 1) (i32.add)))))",
  ).unwrap()
  let original_bytes = @binary.encode_module(module_).unwrap()
  let context = hot_module_context_from_module(module_)
  for _ in 0..<2 {
    let func = hot_lift_func_with_context_result(
      module_,
      @lib.FuncIdx::new(0U),
      context,
    ).unwrap()
    let lowered = hot_lower_func(func)
    match
      @validate.validate_module(
        module_.with_code_sec(@lib.CodeSec::new([lowered])),
      ) {
      Ok(_) => ()
      Err(err) => fail("lowered stack fixture: \{err}")
    }
    assert_eq(@binary.encode_module(module_).unwrap(), original_bytes)
  }
}
