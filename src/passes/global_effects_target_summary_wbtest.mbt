///|
test "GlobalEffects caches target suspension summaries" {
  let funcs = [
    @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([@lib.Instruction::nop()]),
    ),
    @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([@lib.Instruction::call(@lib.FuncIdx::new(0U))]),
    ),
  ]
  let cached : Array[Bool?] = Array::make(2, None)
  assert_true(ge_target_cannot_suspend(funcs, 0, cached))
  assert_eq(cached[0], Some(true))
  assert_false(ge_target_cannot_suspend(funcs, 1, cached))
  assert_eq(cached[1], Some(false))
}
