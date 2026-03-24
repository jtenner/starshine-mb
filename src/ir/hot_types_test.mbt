///|
test "type interning reuses canonical ids and exposes result queries" {
  let func = HotFunc::new()

  let void_ty = hot_type_intern_void(func)
  let void_ty_again = hot_type_intern_void(func)
  let value_ty = hot_type_intern_value(func, @lib.ValType::i32())
  let value_ty_again = hot_type_intern_value(func, @lib.ValType::i32())
  let block_ty = hot_type_intern_block_result(
    func,
    @lib.BlockType::val_type(@lib.ValType::i64()),
  )
  let block_ty_again = hot_type_intern_block_result(
    func,
    @lib.BlockType::val_type(@lib.ValType::i64()),
  )
  let results_ty = hot_type_intern_results(func, [
    @lib.ValType::i32(),
    @lib.ValType::i64(),
  ])
  let results_ty_again = hot_type_intern_results(func, [
    @lib.ValType::i32(),
    @lib.ValType::i64(),
  ])

  assert_eq(void_ty, void_ty_again)
  assert_eq(value_ty, value_ty_again)
  assert_eq(block_ty, block_ty_again)
  assert_eq(results_ty, results_ty_again)

  assert_true(hot_type_is_void(func, void_ty))
  assert_false(hot_type_is_void(func, value_ty))
  assert_eq(hot_type_result_arity(func, void_ty), 0)
  assert_eq(hot_type_result_arity(func, value_ty), 1)
  assert_eq(hot_type_result_arity(func, block_ty), 1)
  assert_eq(hot_type_result_arity(func, results_ty), 2)
  assert_eq(hot_type_results(func, void_ty).length(), 0)
  assert_eq(hot_type_results(func, value_ty), [@lib.ValType::i32()])
  assert_eq(hot_type_results(func, block_ty), [@lib.ValType::i64()])
  assert_eq(hot_type_results(func, results_ty), [
    @lib.ValType::i32(),
    @lib.ValType::i64(),
  ])
  match hot_type_get(func, results_ty) {
    Results(values) =>
      assert_eq(values, [@lib.ValType::i32(), @lib.ValType::i64()])
    _ => fail("expected multi-result type")
  }
}

///|
test "local metadata helpers expose parameter and local types" {
  let func = HotFunc::new(
    locals=HotLocals::new(params=[@lib.ValType::i32(), @lib.ValType::i64()], locals=[
      @lib.ValType::f32(),
    ]),
  )

  assert_eq(hot_param_count(func), 2)
  assert_eq(hot_local_count(func), 3)
  assert_eq(hot_local_type(func, 0), Some(@lib.ValType::i32()))
  assert_eq(hot_local_type(func, 1), Some(@lib.ValType::i64()))
  assert_eq(hot_local_type(func, 2), Some(@lib.ValType::f32()))
  assert_eq(hot_local_type(func, 3), None)
}

///|
test "hot lift reuses canonical block-result type ids" {
  let func = hot_lift_body(
    @lib.Expr::new([
      @lib.Instruction::block(
        @lib.BlockType::val_type(@lib.ValType::i32()),
        @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(1))]),
      ),
      @lib.Instruction::block(
        @lib.BlockType::val_type(@lib.ValType::i32()),
        @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(2))]),
      ),
    ]),
    HotLocals::new(param_count=0, locals=[]),
  )

  let first_block = hot_root_get(func, 0)
  let second_block = hot_root_get(func, 1)
  let canonical_ty = hot_type_intern_block_result(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
  )

  assert_eq(hot_node_get(func, first_block).ty, canonical_ty)
  assert_eq(hot_node_get(func, second_block).ty, canonical_ty)
}
