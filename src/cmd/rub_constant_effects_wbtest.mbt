///|
test "command remove-unused-brs keeps condition call while dropping equal-constant branch" {
  let input = @wast.wast_to_binary_module(
    "(module (import \"m\" \"c\" (func (result i32))) (func (result i32) (block $b (result i32) (drop (br_if $b (i32.const 7) (call 0))) (i32.const 7))))",
    filename="constant-branch.wat",
  ).unwrap()
  let output = optimize_module_with_pass_flags(input, ["remove-unused-brs"], OptimizeOptions::new()).unwrap()
  @validate.validate_module(output).unwrap()
  let @lib.CodeSec(codes) = output.code_sec.unwrap()
  let @lib.Func(_, @lib.Expr(body)) = codes[0]
  @debug.assert_eq(body, [@lib.Instruction::call(@lib.FuncIdx::new(0U)), @lib.Instruction::drop(), @lib.Instruction::i32_const(@lib.I32(7))])
}
