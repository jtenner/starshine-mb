///|
test "HOT maintained node reads avoid repeated fallback validation" {
  let func = HotFunc::new()
  for _ in 0..<128 {
    ignore(hot_build_nop(func))
  }
  for id in 0..<16 {
    hot_delete_node(func, id)
  }
  let revision = hot_revision_current(func)
  let free = func.free_nodes.copy()
  let deleted = func.deleted_nodes.copy()
  let checks = [0]
  for id in 16..<128 {
    let node = hot_node_get_impl(func, id, Some(checks))
    assert_eq(node, func.nodes[id])
    assert_eq(node.op, HotOp::Nop)
    assert_eq(hot_node_get(func, id), node)
  }
  assert_eq(checks[0], 0)
  assert_eq(hot_revision_current(func), revision)
  assert_eq(func.free_nodes, free)
  assert_eq(func.deleted_nodes, deleted)
  for id in 0..<16 {
    assert_false(hot_node_is_live(func, id))
  }
  assert_false(hot_node_is_live(func, -1))
  assert_false(hot_node_is_live(func, 128))
}

///|
test "HOT reads retain incomplete deletion-index fallback behavior" {
  let func = HotFunc::new()
  for _ in 0..<64 {
    ignore(hot_build_nop(func))
  }
  hot_delete_node(func, 0)
  // An incomplete internal fixture intentionally requires the free-list path.
  func.deleted_nodes.clear()
  assert_false(hot_node_is_live(func, 0))
  let checks = [0]
  assert_eq(hot_node_get_impl(func, 63, Some(checks)), func.nodes[63])
  assert_eq(checks[0], 1)
  func.free_nodes.clear()
  checks[0] = 0
  assert_eq(hot_node_get_impl(func, 63, Some(checks)), func.nodes[63])
  assert_eq(checks[0], 0)
}
