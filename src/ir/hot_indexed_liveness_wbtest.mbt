///|
test "HOT liveness uses maintained tombstones without repeated free-list scans" {
  let func = HotFunc::new()
  for _ in 0..<128 {
    ignore(hot_build_nop(func))
  }
  for node in 0..<16 {
    hot_delete_node(func, node)
  }
  let revision = hot_revision_current(func)
  let free = func.free_nodes.copy()
  let checks = [0]
  for node in 0..<128 {
    assert_eq(
      hot_node_is_live_impl(func, node, free_list_checks=Some(checks)),
      node >= 16,
    )
    assert_eq(hot_node_is_live(func, node), node >= 16)
  }
  assert_eq(checks[0], 0)
  assert_eq(func.free_nodes, free)
  assert_eq(hot_revision_current(func), revision)
  let next = hot_build_nop(func)
  assert_eq(next, 128)
  assert_true(hot_node_is_live(func, next))
  assert_false(hot_node_is_live(func, 0))
  assert_false(hot_node_is_live(func, -1))
  assert_false(hot_node_is_live(func, 129))
  let @lib.Func(_, @lib.Expr(body)) = hot_lower_func_unverified(func)
  assert_eq(body, [])
}
