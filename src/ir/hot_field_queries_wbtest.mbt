///|
test "HOT scalar opcode queries preserve current live-node fields and arena ownership" {
  let func = HotFunc::new()
  let nop = hot_build_nop(func)
  let left = hot_build_const_i32(func, @lib.I32(7))
  let right = hot_build_const_i32(func, @lib.I32(11))
  let sum = hot_build_binary(func, @lib.ValType::i32(), left, right)
  for node in [nop, left, right, sum] {
    assert_eq(hot_node_op(func, node), hot_node_get(func, node).op)
    assert_eq(hot_node_type(func, node), hot_node_get(func, node).ty)
    assert_eq(hot_child_count(func, node), hot_node_get(func, node).child_count)
  }
  let revision = hot_revision_current(func)
  assert_eq(hot_child_get(func, sum, 0), left)
  assert_eq(hot_child_get(func, sum, 1), right)
  assert_eq(hot_revision_current(func), revision)
  let saved = hot_node_get(func, nop)
  hot_node_set(func, nop, hot_node_get(func, left))
  assert_eq(saved.op, HotOp::Nop)
  assert_eq(hot_node_op(func, nop), HotOp::Const)
}

///|
test "HOT scalar field queries retain incomplete deletion-index fallback" {
  let func = HotFunc::new()
  let deleted = hot_build_nop(func)
  let left = hot_build_const_i32(func, @lib.I32(7))
  let right = hot_build_const_i32(func, @lib.I32(11))
  let sum = hot_build_binary(func, @lib.ValType::i32(), left, right)
  hot_delete_node(func, deleted)
  func.deleted_nodes.clear()
  let free = func.free_nodes.copy()
  let revision = hot_revision_current(func)
  assert_false(hot_node_is_live(func, deleted))
  assert_eq(hot_node_op(func, sum), HotOp::Binary)
  assert_eq(hot_node_type(func, sum), hot_node_get(func, sum).ty)
  assert_eq(hot_child_count(func, sum), 2)
  assert_eq(hot_child_get(func, sum, 1), right)
  assert_eq(func.free_nodes, free)
  assert_eq(hot_revision_current(func), revision)
}
