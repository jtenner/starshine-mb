///|
test "OI write-set analysis includes writes through a no-else control subtree" {
  let input = pass_test_module_from_wat(
    "(module (global (mut i32) (i32.const 0)) (func (param i32) local.get 0 if i32.const 7 global.set 0 end))",
  )
  let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(0U))
  @ir.hot_verify_core(func).unwrap()
  @ir.hot_verify_control(func).unwrap()
  let fact = OiStateWriteSetFact::from_value_subtree(func, func.roots[0])
  assert_true(fact.writes_global(0))
  assert_false(fact.writes_local(0))
}
