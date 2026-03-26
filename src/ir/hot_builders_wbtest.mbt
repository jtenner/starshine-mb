///|
test "low level hot_build_node applies canonical flags and child spans" {
  let func = HotFunc::new()
  let child = hot_build_const_i32(func, @lib.I32(1))
  let ty = hot_type_intern_value(func, @lib.ValType::i32())
  let rev0 = hot_revision_current(func)
  let id = hot_build_node(func, HotOp::Call, ty, imm0=9, imm1=4, children=[
    child,
  ])
  let node = hot_node_get(func, id)

  assert_eq(hot_revision_current(func), rev0 + 1)
  assert_eq(node.op, HotOp::Call)
  assert_eq(node.ty, ty)
  assert_eq(node.flags, hot_default_flags_for_op(HotOp::Call))
  assert_eq(node.imm0, 9)
  assert_eq(node.imm1, 4)
  assert_eq(hot_child_count(func, id), 1)
  assert_eq(hot_child_get(func, id, 0), child)
}

///|
test "fixed-arity hot_build_node3 attaches children in order with one revision bump" {
  let func = HotFunc::new()
  let first = hot_build_const_i32(func, @lib.I32(1))
  let second = hot_build_const_i32(func, @lib.I32(2))
  let third = hot_build_const_i32(func, @lib.I32(3))
  let ty = hot_type_intern_value(func, @lib.ValType::i32())
  let rev0 = hot_revision_current(func)
  let id = hot_build_node3(func, HotOp::If, ty, first, second, third, imm0=7)
  let node = hot_node_get(func, id)

  assert_eq(hot_revision_current(func), rev0 + 1)
  assert_eq(node.op, HotOp::If)
  assert_eq(node.ty, ty)
  assert_eq(node.flags, hot_default_flags_for_op(HotOp::If))
  assert_eq(node.imm0, 7)
  assert_eq(node.imm1, 0)
  assert_eq(hot_child_count(func, id), 3)
  assert_eq(hot_child_get(func, id, 0), first)
  assert_eq(hot_child_get(func, id, 1), second)
  assert_eq(hot_child_get(func, id, 2), third)
}
