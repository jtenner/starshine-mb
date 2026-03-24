///|
test "low level hot_build_node applies canonical flags and child spans" {
  let func = HotFunc::new()
  let child = hot_build_const_i32(func, @lib.I32(1))
  let ty = hot_type_intern_value(func, @lib.ValType::i32())
  let id = hot_build_node(func, HotOp::Call, ty, imm0=9, imm1=4, children=[
    child,
  ])
  let node = hot_node_get(func, id)

  assert_eq(node.op, HotOp::Call)
  assert_eq(node.ty, ty)
  assert_eq(node.flags, hot_default_flags_for_op(HotOp::Call))
  assert_eq(node.imm0, 9)
  assert_eq(node.imm1, 4)
  assert_eq(hot_child_count(func, id), 1)
  assert_eq(hot_child_get(func, id, 0), child)
}
