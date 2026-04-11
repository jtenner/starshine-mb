///|
test "label_stack_storage_index maps top-first indices into storage order" {
  assert_eq(label_stack_storage_index(0, 0), None)
  assert_eq(label_stack_storage_index(2, -1), None)
  assert_eq(label_stack_storage_index(2, 0), Some(1))
  assert_eq(label_stack_storage_index(2, 1), Some(0))
  assert_eq(label_stack_storage_index(2, 2), None)
}
