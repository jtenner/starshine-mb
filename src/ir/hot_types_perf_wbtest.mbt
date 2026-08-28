///|
test "hot block-result type interning uses a typed cache" {
  let func = HotFunc::new()
  let block_type = @lib.BlockType::val_type(@lib.ValType::i32())
  let first = hot_type_intern_block_result(func, block_type)
  let second = hot_type_intern_block_result(func, block_type)

  @debug.assert_eq(first, second)
  @debug.assert_eq(func.types.length(), 2)
  @debug.assert_eq(func.block_type_ids.length(), 1)
}

///|
test "hot scalar type interning bypasses string keys" {
  let func = HotFunc::new()
  let first = hot_type_intern_value(func, @lib.ValType::i32())
  let second = hot_type_intern_value(func, @lib.ValType::i32())

  @debug.assert_eq(first, second)
  @debug.assert_eq(func.types.length(), 2)
  @debug.assert_eq(func.value_type_ids.length(), 1)
}
