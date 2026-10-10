///|
test "dispatcher merge-blocks keeps nested loop control valid" {
  let source = StringBuilder::new()
  source.write_string("(module (func (export \"run\") ")
  for _ in 0..<64 {
    source.write_string("block ")
  }
  source.write_string("loop nop end ")
  for _ in 0..<64 {
    source.write_string("end ")
  }
  source.write_string("))")
  let input = @passes.pass_test_module_from_wat(source.to_string())
  let output = optimize_module_with_pass_flags(
    input,
    ["merge-blocks"],
    OptimizeOptions::new(),
  ).unwrap()
  @validate.validate_module(output).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(locals.length(), 0)
  @debug.assert_eq(body, [
    @lib.Instruction::loop_(@lib.BlockType::void_(), @lib.Expr::new([])),
  ])
}
