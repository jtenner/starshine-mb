///|
test "command optimize-instructions shortens unsigned sign-bit division" {
  let input = @wast.wast_to_binary_module(
    "(module (func (param i32) (result i32) local.get 0 i32.const -2147483648 i32.div_u))",
    filename="sign-bit.wat",
  ).unwrap()
  let output = optimize_module_with_pass_flags(input, ["optimize-instructions"], OptimizeOptions::new()).unwrap()
  @validate.validate_module(output).unwrap()
  let @lib.CodeSec(codes) = output.code_sec.unwrap()
  let @lib.Func(_, @lib.Expr(body)) = codes[0]
  @debug.assert_eq(body, [@lib.Instruction::local_get(@lib.LocalIdx::new(0U)), @lib.Instruction::i32_const(@lib.I32(31)), @lib.Instruction::i32_shr_u()])
  assert_true(@binary.encode_module(output).unwrap().length() < @binary.encode_module(input).unwrap().length())
}
