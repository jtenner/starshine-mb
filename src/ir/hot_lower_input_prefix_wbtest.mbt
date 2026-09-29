///|
test "HOT input prefix reuses an existing tuple with one comparison per lane" {
  let stack : Array[HotLowerStackValue] = Array::makei(32, fn(_) {
    { node_id: 7, val_type: @lib.ValType::i32(), }
  })
  let inputs = Array::make(32, 7)
  let comparisons = [0]
  assert_eq(
    hot_lower_impl_matching_input_prefix(
      stack,
      inputs[:],
      comparisons=Some(comparisons),
    ),
    32,
  )
  assert_eq(comparisons[0], 32)
  assert_eq(stack.length(), 32)
  assert_eq(inputs, Array::make(32, 7))
}

///|
test "HOT input prefix selects the longest suffix without losing repeated lanes" {
  for
    (nodes, inputs, expected) in [
      ([], [1, 2], 0),
      ([1, 2], [], 0),
      ([9, 1, 2, 3], [1, 2, 3, 4], 3),
      ([1, 2, 1], [1, 2, 1, 2], 3),
      ([1, 2, 1], [1, 2], 1),
      ([1, 1, 2], [1, 1], 0),
      ([1, 1, 1], [1, 1], 2),
    ] {
    let stack : Array[HotLowerStackValue] = nodes.map(fn(node_id) {
      { node_id, val_type: @lib.ValType::i32(), }
    })
    assert_eq(hot_lower_impl_matching_input_prefix(stack, inputs[:]), expected)
    assert_eq(stack.map(fn(value) { value.node_id }), nodes)
  }
}
