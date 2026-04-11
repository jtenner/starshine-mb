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
