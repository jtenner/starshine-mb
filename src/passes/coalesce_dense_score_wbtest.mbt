///|
test "coalesce dense coloring stops after the earliest maximum-score slot" {
  let types = Array::make(32, @lib.ValType::i32())
  let order = Array::makei(24, fn(index) { index + 8 })
  let conflicts = CLBitMatrix::new(32)
  let weights = CLCopyWeights::new(32)
  let visits = [0]
  let actual = cl_color_with_order(
    order,
    types,
    8,
    conflicts,
    weights,
    slot_visits=Some(visits),
  )
  let expected = cl_color_with_order_reference(
    order, types, 8, conflicts, weights,
  )
  assert_eq(actual.old_to_new, expected.old_to_new)
  assert_eq(actual.slot_types, expected.slot_types)
  assert_eq(actual.removed_copies, expected.removed_copies)
  for index in 8..<32 {
    assert_eq(actual.old_to_new[index], 0)
  }
  assert_eq(visits[0], order.length())
}

///|
test "coalesce dense coloring preserves weighted ties types and conflicts" {
  let types = Array::make(32, @lib.ValType::i32())
  types[0] = @lib.ValType::i64()
  types[29] = @lib.ValType::i64()
  let order = Array::makei(24, fn(index) { 31 - index })
  let conflicts = CLBitMatrix::new(32)
  let weights = CLCopyWeights::new(32)
  for local in 8..<32 {
    cl_copy_weight_add(weights, local, 2, 3)
    cl_copy_weight_add(weights, local, 5, 3)
    cl_bit_matrix_set(conflicts, local, 2, local % 2 == 0)
    cl_bit_matrix_set(conflicts, local, 5, local % 3 == 0)
  }
  let actual = cl_color_with_order(order, types, 8, conflicts, weights)
  let expected = cl_color_with_order_reference(
    order, types, 8, conflicts, weights,
  )
  assert_eq(actual.old_to_new, expected.old_to_new)
  assert_eq(actual.slot_types, expected.slot_types)
  assert_eq(actual.removed_copies, expected.removed_copies)
  for lhs in 0..<32 {
    for rhs in (lhs + 1)..<32 {
      if actual.old_to_new[lhs] == actual.old_to_new[rhs] {
        assert_eq(types[lhs], types[rhs])
        assert_false(cl_bit_matrix_get(conflicts, lhs, rhs))
      }
    }
  }
}
