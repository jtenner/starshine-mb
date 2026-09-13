///|
test "audit merge blocks retains owner used by branch condition" {
  let func = pass_test_lift_first_func(
    "(module (func (param i32) block $outer block (result i32) local.get 0 br_if $outer i32.const 1 end br_if $outer end))",
  )
  assert_false(
    merge_blocks_try_remove_o4z_self_br_if_void_block(
      func,
      @ir.HotRegionRef::root(),
      0,
    ),
  )
}
