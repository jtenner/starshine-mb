///|
test "remove-unused-names label inventory finds nested outer continue" {
  let fixture = @ir.ir_test_build_hot_from_wat(
    "(module (func (loop (loop (br 1)))))",
  )
  let func = fixture.hot_func
  let used = remove_unused_names_compute_live_label_uses(func)
  let outer = @ir.hot_root_get(func, 0)
  let outer_label = @ir.hot_control_node_label(func, outer)
  let body_ref = @ir.hot_region_body_ref(func, outer)
  let inner = @ir.hot_region_get(func, body_ref, 0)
  let inner_label = @ir.hot_control_node_label(func, inner)
  @debug.assert_eq(used[outer_label], true)
  @debug.assert_eq(used[inner_label], false)
}

///|
test "remove-unused-names label inventory leaves branch-free loops unused" {
  let fixture = @ir.ir_test_build_hot_from_wat(
    "(module (func (loop (loop nop))))",
  )
  let func = fixture.hot_func
  let used = remove_unused_names_compute_live_label_uses(func)
  let outer = @ir.hot_root_get(func, 0)
  let inner = @ir.hot_region_get(func, @ir.hot_region_body_ref(func, outer), 0)
  @debug.assert_eq(used[@ir.hot_control_node_label(func, outer)], false)
  @debug.assert_eq(used[@ir.hot_control_node_label(func, inner)], false)
}
