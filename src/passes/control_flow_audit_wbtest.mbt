///|
test "DCE treats every tail call as nonfallthrough" {
  let func = @ir.HotFunc::new()
  let callee = @ir.hot_build_const_i32(func, 0)
  let nodes = [
    @ir.hot_build_return_call(func, 0, []),
    @ir.hot_build_return_call_indirect(
      func,
      @lib.TypeIdx::new(0U),
      @lib.TableIdx::new(0U),
      [],
      callee,
    ),
    @ir.hot_build_return_call_ref(func, @lib.TypeIdx::new(0U), [], callee),
  ]
  for node in nodes {
    assert_false(
      dead_code_elimination_op_has_fallthrough_edge(@ir.hot_node_op(func, node)),
    )
  }
}

///|
test "RUB counts a br_table default target once" {
  let input = pass_test_module_from_wat(
    "(module (func (param i32) (block (local.get 0) (br_table 0))))",
  )
  let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(0U))
  let block_id = @ir.hot_root_get(func, 0)
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  let label_id = @ir.hot_control_node_label(func, block_id)
  assert_eq(
    remove_unused_brs_count_label_uses_in_region(func, body_ref, label_id),
    1,
  )
}
