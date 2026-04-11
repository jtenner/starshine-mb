///|
test "label_stack_storage_index maps top-first indices into storage order" {
  assert_eq(label_stack_storage_index(0, 0), None)
  assert_eq(label_stack_storage_index(2, -1), None)
  assert_eq(label_stack_storage_index(2, 0), Some(1))
  assert_eq(label_stack_storage_index(2, 1), Some(0))
  assert_eq(label_stack_storage_index(2, 2), None)
}

///|
test "latest_stack_index points at the most recent frame" {
  assert_eq(latest_stack_index(0), None)
  assert_eq(latest_stack_index(1), Some(0))
  assert_eq(latest_stack_index(3), Some(2))
}

///|
test "group_relative_absolute_index offsets a valid relative index" {
  assert_eq(group_relative_absolute_index(10, 0, 0), None)
  assert_eq(group_relative_absolute_index(10, 2, -1), None)
  assert_eq(group_relative_absolute_index(10, 2, 0), Some(10))
  assert_eq(group_relative_absolute_index(10, 2, 1), Some(11))
  assert_eq(group_relative_absolute_index(10, 2, 2), None)
}

///|
test "group_member_relative_index recovers the local slot when abs is in range" {
  assert_eq(group_member_relative_index(10, 0, 10), None)
  assert_eq(group_member_relative_index(10, 2, 9), None)
  assert_eq(group_member_relative_index(10, 2, 10), Some(0))
  assert_eq(group_member_relative_index(10, 2, 11), Some(1))
  assert_eq(group_member_relative_index(10, 2, 12), None)
}

///|
test "defined_func_body_index strips the imported prefix for defined bodies" {
  assert_eq(defined_func_body_index(0, 0), Some(0))
  assert_eq(defined_func_body_index(2, 0), None)
  assert_eq(defined_func_body_index(2, 1), None)
  assert_eq(defined_func_body_index(2, 2), Some(0))
  assert_eq(defined_func_body_index(2, 4), Some(2))
}

///|
test "defined_func_absolute_index rebuilds the module index from a body slot" {
  assert_eq(defined_func_absolute_index(0, 0), 0)
  assert_eq(defined_func_absolute_index(2, 0), 2)
  assert_eq(defined_func_absolute_index(2, 3), 5)
}

///|
test "bounded_index returns the original slot only when it is in range" {
  assert_eq(bounded_index(0, 0), None)
  assert_eq(bounded_index(2, -1), None)
  assert_eq(bounded_index(2, 0), Some(0))
  assert_eq(bounded_index(2, 1), Some(1))
  assert_eq(bounded_index(2, 2), None)
}

///|
test "defined_body_func_index maps a valid code-body ordinal to a module function index" {
  assert_eq(defined_body_func_index(0, 0, 0), None)
  assert_eq(defined_body_func_index(2, 3, -1), None)
  assert_eq(defined_body_func_index(2, 3, 0), Some(2))
  assert_eq(defined_body_func_index(2, 3, 2), Some(4))
  assert_eq(defined_body_func_index(2, 3, 3), None)
}
