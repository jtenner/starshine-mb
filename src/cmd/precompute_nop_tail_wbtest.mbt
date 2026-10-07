///|
test "dispatcher precompute removes a long nop tail" {
  let source = StringBuilder::new()
  source.write_string("(module (func (export \"run\") (result i32) ")
  for _ in 0..<512 {
    source.write_string("nop ")
  }
  source.write_string("i32.const 7))")
  let input = @passes.pass_test_module_from_wat(source.to_string())
  let output = optimize_module_with_pass_flags(
    input,
    ["precompute"],
    OptimizeOptions::new(),
  ).unwrap()
  @validate.validate_module(output).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(body, [@lib.Instruction::i32_const(@lib.I32(7))])
}
