///|
test "label_stack_storage_index maps top-first indices into storage order" {
  @debug.assert_eq(label_stack_storage_index(0, 0), None)
  @debug.assert_eq(label_stack_storage_index(2, -1), None)
  @debug.assert_eq(label_stack_storage_index(2, 0), Some(1))
  @debug.assert_eq(label_stack_storage_index(2, 1), Some(0))
  @debug.assert_eq(label_stack_storage_index(2, 2), None)
}

///|
test "latest_stack_index points at the most recent frame" {
  @debug.assert_eq(latest_stack_index(0), None)
  @debug.assert_eq(latest_stack_index(1), Some(0))
  @debug.assert_eq(latest_stack_index(3), Some(2))
}

///|
test "group_relative_absolute_index offsets a valid relative index" {
  @debug.assert_eq(group_relative_absolute_index(10, 0, 0), None)
  @debug.assert_eq(group_relative_absolute_index(10, 2, -1), None)
  @debug.assert_eq(group_relative_absolute_index(10, 2, 0), Some(10))
  @debug.assert_eq(group_relative_absolute_index(10, 2, 1), Some(11))
  @debug.assert_eq(group_relative_absolute_index(10, 2, 2), None)
}

///|
test "group_member_relative_index recovers the local slot when abs is in range" {
  @debug.assert_eq(group_member_relative_index(10, 0, 10), None)
  @debug.assert_eq(group_member_relative_index(10, 2, 9), None)
  @debug.assert_eq(group_member_relative_index(10, 2, 10), Some(0))
  @debug.assert_eq(group_member_relative_index(10, 2, 11), Some(1))
  @debug.assert_eq(group_member_relative_index(10, 2, 12), None)
}

///|
test "defined_func_body_index strips the imported prefix for defined bodies" {
  @debug.assert_eq(defined_func_body_index(0, 0), Some(0))
  @debug.assert_eq(defined_func_body_index(2, 0), None)
  @debug.assert_eq(defined_func_body_index(2, 1), None)
  @debug.assert_eq(defined_func_body_index(2, 2), Some(0))
  @debug.assert_eq(defined_func_body_index(2, 4), Some(2))
}

///|
test "defined_func_absolute_index rebuilds the module index from a body slot" {
  @debug.assert_eq(defined_func_absolute_index(0, 0), 0)
  @debug.assert_eq(defined_func_absolute_index(2, 0), 2)
  @debug.assert_eq(defined_func_absolute_index(2, 3), 5)
}

///|
test "bounded_index returns the original slot only when it is in range" {
  @debug.assert_eq(bounded_index(0, 0), None)
  @debug.assert_eq(bounded_index(2, -1), None)
  @debug.assert_eq(bounded_index(2, 0), Some(0))
  @debug.assert_eq(bounded_index(2, 1), Some(1))
  @debug.assert_eq(bounded_index(2, 2), None)
}

///|
test "defined_body_func_index maps a valid code-body ordinal to a module function index" {
  @debug.assert_eq(defined_body_func_index(0, 0, 0), None)
  @debug.assert_eq(defined_body_func_index(2, 3, -1), None)
  @debug.assert_eq(defined_body_func_index(2, 3, 0), Some(2))
  @debug.assert_eq(defined_body_func_index(2, 3, 2), Some(4))
  @debug.assert_eq(defined_body_func_index(2, 3, 3), None)
}

///|
test "suffix_start_index finds the start of a valid suffix" {
  @debug.assert_eq(suffix_start_index(0, 0), Some(0))
  @debug.assert_eq(suffix_start_index(2, 1), Some(1))
  @debug.assert_eq(suffix_start_index(2, 2), Some(0))
  @debug.assert_eq(suffix_start_index(2, 3), None)
}

///|
test "rectype_suffix_member_index maps suffix-local members into absolute indices" {
  @debug.assert_eq(rectype_suffix_member_index(4, 0, 0), None)
  @debug.assert_eq(rectype_suffix_member_index(4, 2, -1), None)
  @debug.assert_eq(rectype_suffix_member_index(4, 2, 0), Some(2))
  @debug.assert_eq(rectype_suffix_member_index(4, 2, 1), Some(3))
  @debug.assert_eq(rectype_suffix_member_index(4, 2, 2), None)
  @debug.assert_eq(rectype_suffix_member_index(1, 2, 0), None)
}

///|
test "stack discipline helpers preserve push and pop lengths" {
  @debug.assert_eq(stack_len_after_push1(0), 1)
  @debug.assert_eq(stack_len_after_push_types(2, 0), 2)
  @debug.assert_eq(stack_len_after_push_types(2, 3), 5)
  @debug.assert_eq(stack_len_after_pop1(0), None)
  @debug.assert_eq(stack_len_after_pop1(3), Some(2))
  @debug.assert_eq(stack_len_after_pop_types(2, 3), None)
  @debug.assert_eq(stack_len_after_pop_types(2, 2), Some(0))
  @debug.assert_eq(stack_len_after_pop_types(4, 1), Some(3))
  @debug.assert_eq(stack_suffix_start_after_end_check(2, 3), None)
  @debug.assert_eq(stack_suffix_start_after_end_check(5, 2), Some(3))
}
