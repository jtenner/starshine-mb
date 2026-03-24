///|
test "root mutation helpers splice insert remove and bump revision once per edit" {
  let func = HotFunc::new()
  let first = hot_build_nop(func)
  let second = hot_build_unreachable(func)
  let third = hot_build_drop(func, hot_build_const_i32(func, @lib.I32(9)))

  let rev0 = hot_revision_current(func)
  hot_root_append(func, first)
  assert_eq(hot_revision_current(func), rev0 + 1)
  assert_eq(hot_root_count(func), 1)
  assert_eq(hot_root_get(func, 0), first)

  let rev1 = hot_revision_current(func)
  hot_root_insert(func, 0, second)
  assert_eq(hot_revision_current(func), rev1 + 1)
  assert_eq(hot_root_count(func), 2)
  assert_eq(hot_root_get(func, 0), second)
  assert_eq(hot_root_get(func, 1), first)

  let rev2 = hot_revision_current(func)
  let removed = hot_root_splice(func, 1, 1, [third, first])
  assert_eq(hot_revision_current(func), rev2 + 1)
  assert_eq(removed, [first])
  assert_eq(hot_root_count(func), 3)
  assert_eq(hot_root_get(func, 0), second)
  assert_eq(hot_root_get(func, 1), third)
  assert_eq(hot_root_get(func, 2), first)

  let rev3 = hot_revision_current(func)
  let removed_root = hot_root_remove(func, 0)
  assert_eq(hot_revision_current(func), rev3 + 1)
  assert_eq(removed_root, second)
  assert_eq(hot_root_count(func), 2)
  assert_eq(hot_root_get(func, 0), third)
  assert_eq(hot_root_get(func, 1), first)
}

///|
test "child span replacement rewires node children and returns replaced slots" {
  let func = HotFunc::new()
  let first = hot_build_const_i32(func, @lib.I32(1))
  let second = hot_build_const_i32(func, @lib.I32(2))
  let third = hot_build_const_i32(func, @lib.I32(3))
  let block = hot_build_block(func, @lib.BlockType::void_(), [first])

  let rev0 = hot_revision_current(func)
  let replaced = hot_replace_child_span(func, block, [first, second, third])
  assert_eq(hot_revision_current(func), rev0 + 1)
  assert_eq(replaced, [first])
  assert_eq(hot_child_count(func, block), 3)
  assert_eq(hot_child_get(func, block, 0), first)
  assert_eq(hot_child_get(func, block, 1), second)
  assert_eq(hot_child_get(func, block, 2), third)
}

///|
test "node deletion records tombstones without immediate free-list reuse" {
  let func = HotFunc::new()
  let deleted = hot_build_nop(func)
  let survivor = hot_build_unreachable(func)

  hot_root_append(func, survivor)
  let rev0 = hot_revision_current(func)
  hot_delete_node(func, deleted)
  assert_eq(hot_revision_current(func), rev0 + 1)
  assert_false(hot_node_is_live(func, deleted))
  assert_true(hot_node_is_live(func, survivor))

  let next = hot_build_unreachable(func)
  assert_eq(next, 2)

  let rev1 = hot_revision_current(func)
  hot_revision_bump(func)
  assert_eq(hot_revision_current(func), rev1 + 1)
}
