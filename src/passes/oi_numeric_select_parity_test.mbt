///|
test "optimize-instructions numeric select parity removes redundant atomic-path annotation" {
  let input = pass_test_module_from_wat(
    "(module (memory 1 1 shared) (func (param i32 i32 i32) (result i32) i32.const 0 i32.atomic.load drop local.get 0 local.get 1 local.get 2 select (result i32)))",
  )
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "optimize-instructions",
  ]).unwrap()
  assert_true(@validate.validate_module(output).is_ok())
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(body.last(), Some(@lib.Instruction::select()))
  let @lib.Func(_, @lib.Expr(before)) = input.code_sec.unwrap().0[0]
  @debug.assert_eq(
    body[0:body.length() - 1].to_array(),
    before[0:before.length() - 1].to_array(),
  )
}

///|
test "optimize-instructions numeric select parity covers wide and floating scalars" {
  for ty in ["i64", "f32", "f64"] {
    let input = pass_test_module_from_wat(
      "(module (memory 1 1 shared) (func (param " +
      ty +
      " " +
      ty +
      " i32) (result " +
      ty +
      ") i32.const 0 i32.atomic.load drop local.get 0 local.get 1 local.get 2 select (result " +
      ty +
      ")))",
    )
    let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
      "optimize-instructions",
    ]).unwrap()
    assert_true(@validate.validate_module(output).is_ok())
    let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
    @debug.assert_eq(body.last(), Some(@lib.Instruction::select()))
    let @lib.Func(_, @lib.Expr(before)) = input.code_sec.unwrap().0[0]
    @debug.assert_eq(
      body[0:body.length() - 1].to_array(),
      before[0:before.length() - 1].to_array(),
    )
  }
}

///|
test "optimize-instructions numeric select parity preserves required reference annotation" {
  let input = pass_test_module_from_wat(
    "(module (memory 1 1 shared) (func (param anyref anyref i32) (result anyref) i32.const 0 i32.atomic.load drop local.get 0 local.get 1 local.get 2 select (result anyref)))",
  )
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "optimize-instructions",
  ]).unwrap()
  assert_true(@validate.validate_module(output).is_ok())
  let @lib.Func(_, @lib.Expr(before)) = input.code_sec.unwrap().0[0]
  let @lib.Func(_, @lib.Expr(after)) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(after.last(), before.last())
}
