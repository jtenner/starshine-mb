///|
test "HOT result arity avoids materializing result arrays and preserves owned queries" {
  let func = HotFunc::new()
  let values = [@lib.ValType::i32(), @lib.ValType::i64(), @lib.ValType::f64()]
  let multi = hot_type_intern_results(func, values)
  let resolved = hot_type_intern_resolved_block_result(
    func,
    @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
    [@lib.ValType::f32()],
    values,
  )
  let ids = [
    hot_type_intern_void(func),
    hot_type_intern_value(func, @lib.ValType::i32()),
    hot_type_intern_block_result(func, @lib.BlockType::void_()),
    hot_type_intern_block_result(
      func,
      @lib.BlockType::val_type(@lib.ValType::i64()),
    ),
    multi,
    resolved,
  ]
  let counts = [0]
  for index = 0; index < ids.length(); index = index + 1 {
    let expected = [0, 1, 0, 1, 3, 3][index]
    assert_eq(
      hot_type_result_arity_impl(func, ids[index], Some(counts)),
      expected,
    )
    assert_eq(hot_type_result_arity(func, ids[index]), expected)
    assert_eq(hot_type_results(func, ids[index]).length(), expected)
  }
  assert_eq(counts[0], 0)
  let owned = hot_type_results(func, multi)
  owned[0] = @lib.ValType::f32()
  owned.push(@lib.ValType::i32())
  assert_eq(hot_type_results(func, multi), values)
  assert_eq(hot_type_results(func, resolved), values)
  assert_eq(hot_type_result_arity(func, multi), 3)
}
