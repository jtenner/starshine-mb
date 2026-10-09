///|
test "branch and catch side tables do not expose mutable target arrays" {
  let func = HotFunc::new()
  let targets = [1, 2]
  let table_id = hot_alloc_branch_table(func, HotBranchTable::new(targets, 3))
  targets[0] = 9
  assert_eq(hot_branch_table_targets(func, table_id), [1, 2])
  let returned_targets = hot_branch_table_targets(func, table_id)
  returned_targets[1] = 9
  assert_eq(hot_branch_table_targets(func, table_id), [1, 2])

  let catches = [HotCatchArm::all(1)]
  let catch_id = hot_alloc_catch_info(func, HotCatchInfo::new(catches))
  catches[0] = HotCatchArm::all(9)
  assert_eq(hot_catch_info_get(func, catch_id).catches, [HotCatchArm::all(1)])
  let returned_catches = hot_catch_info_get(func, catch_id)
  returned_catches.catches[0] = HotCatchArm::all(9)
  assert_eq(hot_catch_info_get(func, catch_id).catches, [HotCatchArm::all(1)])
}

///|
test "side-table allocation takes ownership of retained payload objects" {
  let func = HotFunc::new()
  let table = HotBranchTable::new([1, 2], 3)
  let table_id = hot_alloc_branch_table(func, table)
  table.targets[0] = 9
  assert_eq(hot_branch_table_targets(func, table_id), [1, 2])

  let info = HotCatchInfo::new([HotCatchArm::all(1)])
  let catch_id = hot_alloc_catch_info(func, info)
  info.catches[0] = HotCatchArm::all(9)
  assert_eq(hot_catch_info_get(func, catch_id).catches, [HotCatchArm::all(1)])
}
