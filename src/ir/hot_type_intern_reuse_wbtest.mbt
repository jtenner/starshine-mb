///|
test "small HOT type tables reuse resolved and tuple ids without formatting keys" {
  let func = HotFunc::new()
  let results = [@lib.ValType::i32(), @lib.ValType::i64()]
  let params = [@lib.ValType::f32()]
  let block = @lib.BlockType::type_idx(@lib.TypeIdx::new(0U))
  let tuple_id = hot_type_intern_results(func, results)
  let block_id = hot_type_intern_resolved_block_result(
    func, block, params, results,
  )
  let before = func.types.length()
  let formats = [0]
  for _ in 0..<8 {
    assert_eq(
      hot_intern_type(
        func,
        HotTypeInfo::Results(results.copy()),
        key_formats=Some(formats),
      ),
      tuple_id,
    )
    assert_eq(
      hot_intern_type(
        func,
        HotTypeInfo::BlockResultResolved(block, params.copy(), results.copy()),
        key_formats=Some(formats),
      ),
      block_id,
    )
  }
  assert_eq(func.types.length(), before)
  assert_eq(formats[0], 0)
  assert_true(
    hot_type_intern_resolved_block_result(func, block, [], results) != block_id,
  )
  assert_true(
    hot_type_intern_results(func, [@lib.ValType::i64(), @lib.ValType::i32()]) !=
    tuple_id,
  )
  hot_verify_core(func).unwrap()
}
