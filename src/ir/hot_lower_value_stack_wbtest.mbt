///|
test "lower value stack preserves mixed values across growth copies and index writes" {
  let reference = ValType::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::any()))
  let stack = hot_lower_value_stack_new()
  for i in 0..<19 {
    stack.push({
      node_id: i,
      val_type: if i % 2 == 0 {
        reference
      } else {
        ValType::i64()
      },
    })
  }
  let copy = stack.copy()
  stack[7] = { node_id: 90, val_type: ValType::f64(), }
  assert_eq(copy[7].node_id, 7)
  assert_eq(copy[7].val_type, ValType::i64())
  let retained = stack.iter()
  stack.truncate(3)
  assert_eq(stack.length(), 3)
  let mut retained_count = 0
  for value in retained {
    assert_eq(
      value.node_id,
      if retained_count == 7 {
        90
      } else {
        retained_count
      },
    )
    assert_eq(
      value.val_type,
      if retained_count == 7 {
        ValType::f64()
      } else if retained_count % 2 == 0 {
        reference
      } else {
        ValType::i64()
      },
    )
    retained_count += 1
  }
  assert_eq(retained_count, 19)
  for i in 0..<3 {
    assert_eq(stack[i].node_id, i)
  }
  stack.push({ node_id: 99, val_type: reference, })
  let popped = stack.pop().unwrap()
  assert_eq(popped.node_id, 99)
  assert_eq(popped.val_type, reference)
  assert_eq(stack.last().unwrap().node_id, 2)
  assert_true(stack.any(fn(value) { value.val_type == reference }))
  stack.clear()
  assert_true(stack.is_empty())
  assert_true(stack.pop() is None)
  assert_eq(copy.length(), 19)
  for i in 0..<19 {
    assert_eq(copy[i].node_id, i)
    assert_eq(
      copy[i].val_type,
      if i % 2 == 0 {
        reference
      } else {
        ValType::i64()
      },
    )
  }
}

///|
#cfg(target="native")
test "native lower value stack capacity saturates at the exact requirement" {
  assert_eq(hot_lower_value_stack_growth_capacity(0, 0), 8)
  assert_eq(hot_lower_value_stack_growth_capacity(8, 8), 16)
  assert_eq(
    hot_lower_value_stack_growth_capacity(0x40000000, 0x40000000),
    0x40000001,
  )
}
