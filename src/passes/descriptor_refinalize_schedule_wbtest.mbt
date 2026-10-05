///|
test "descriptor refinalize schedules child ids without a materialized span" {
  let func = pass_test_lift_first_func(
    "(module (func i32.const 1 i32.const 2 i32.add drop))",
  )
  let root = @ir.hot_root_get(func, 0)
  let work : Array[(Int, Bool)] = []

  pass_refinalize_descriptor_schedule_children(func, root, work)

  assert_eq(work.length(), @ir.hot_child_count(func, root))
  for slot = 0; slot < work.length(); slot = slot + 1 {
    assert_eq(work[slot].0, @ir.hot_child_get(func, root, slot))
    assert_false(work[slot].1)
  }
}
