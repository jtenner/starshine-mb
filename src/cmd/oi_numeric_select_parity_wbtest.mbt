///|
test "optimize-instructions command numeric select parity removes redundant atomic-path annotation" {
  let input = @passes.pass_test_module_from_wat(
    "(module (memory 1 1 shared) (func (param i32 i32 i32) (result i32) i32.const 0 i32.atomic.load drop local.get 0 local.get 1 local.get 2 select (result i32)))",
  )
  let output = optimize_module_with_pass_flags(
    input,
    ["optimize-instructions"],
    OptimizeOptions::new(),
  ).unwrap()
  assert_true(@validate.validate_module(output).is_ok())
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(body.last(), Some(@lib.Instruction::select()))
  let @lib.Func(_, @lib.Expr(before)) = input.code_sec.unwrap().0[0]
  @debug.assert_eq(
    body[0:body.length() - 1].to_array(),
    before[0:before.length() - 1].to_array(),
  )
}
