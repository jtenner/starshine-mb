///|
test "batched detached node deletion preflights every scalar target" {
  let func = HotFunc::new()
  let detached = hot_build_nop(func)
  let referenced = hot_build_nop(func)
  let owner = hot_build_drop(func, referenced)
  hot_root_append(func, owner)
  let revision_before = hot_revision_current(func)

  assert_false(
    hot_mutate_delete_detached_nodes_if_unreferenced(func, [
      detached, referenced,
    ]),
  )
  @debug.assert_eq(hot_revision_current(func), revision_before)
  assert_true(hot_node_is_live(func, detached))
  assert_true(hot_node_is_live(func, referenced))
  assert_true(hot_node_is_live(func, owner))
}
