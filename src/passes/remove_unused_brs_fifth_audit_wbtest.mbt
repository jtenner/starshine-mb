///|
test "fifth audit HOT one sided select retains condition ordering" {
  let func = pass_test_lift_first_func(
    "(module (func (result i32) (local i32) (if (result i32) (local.tee 0 (i32.const 1)) (then (return (local.get 0))) (else (i32.const 7)))))",
  )
  let ctx = remove_unused_brs_wbtest_ctx()
  let cache = Array::make(@ir.hot_node_count(func), 0)
  let labels = Array::make(func.labels.length(), 0)
  assert_false(
    remove_unused_brs_try_rewrite_one_sided_stack_tail_if_to_select(
      ctx,
      func,
      @ir.HotRegionRef::root(),
      cache,
      labels,
    ),
  )
}
