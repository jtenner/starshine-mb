///|
test "dispatcher memory-packing preserves unaffected function bodies" {
  let source = StringBuilder::new()
  source.write_string("(module (memory 1) (data \"dead\") ")
  source.write_string("(func (data.drop 0)) ")
  for _ in 0..<128 {
    source.write_string("(func (result i32) i32.const 7) ")
  }
  source.write_string(")")
  let input = @passes.pass_test_module_from_wat(source.to_string())
  let output = optimize_module_with_pass_flags(
    input,
    ["memory-packing"],
    OptimizeOptions::new(),
  ).unwrap()
  @validate.validate_module(output).unwrap()
  let @lib.CodeSec(original) = input.code_sec.unwrap()
  let @lib.CodeSec(rewritten) = output.code_sec.unwrap()
  let @lib.Func(_, @lib.Expr(first_body)) = rewritten[0]
  @debug.assert_eq(first_body, [@lib.Instruction::nop()])
  for i = 1; i < original.length(); i = i + 1 {
    @debug.assert_eq(rewritten[i], original[i])
  }
}
