///|
test "merge-locals stack-carried preflight scans a flat copy region once" {
  let count = 64
  let copies = Array::make(count, "local.get 0 local.set 1").join(" ")
  let func = pass_test_lift_first_func(
    "(module (func (param i32) (local i32) " + copies + "))",
  )
  let visits = [0]

  assert_false(
    merge_locals_region_has_stack_carried_copy(
      func,
      @ir.HotRegionRef::root(),
      visits=Some(visits),
    ),
  )
  assert_true(visits[0] <= count * 3, msg="visits=\{visits[0]}")
}
