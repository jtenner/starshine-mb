///|
test "command optimize-instructions shortens unsigned sign-bit division" {
  let input = @wast.wast_to_binary_module(
    "(module (func (param i32) (result i32) local.get 0 i32.const -2147483648 i32.div_u))",
    filename="sign-bit.wat",
  ).unwrap()
  let output = optimize_module_with_pass_flags(
    input,
    ["optimize-instructions"],
    OptimizeOptions::new(),
  ).unwrap()
  @validate.validate_module(output).unwrap()
  let @lib.CodeSec(codes) = output.code_sec.unwrap()
  let @lib.Func(_, @lib.Expr(body)) = codes[0]
  @debug.assert_eq(body, [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32(31)),
    @lib.Instruction::i32_shr_u(),
  ])
  assert_true(
    @binary.encode_module(output).unwrap().length() <
    @binary.encode_module(input).unwrap().length(),
  )
}

///|
test "command raw constant folding also rewrites sign-bit arithmetic" {
  let input = @wast.wast_to_binary_module(
    "(module (func (param i32) (result i32) i32.const 7 i32.const 0 i32.add drop local.get 0 i32.const -2147483648 i32.div_u))",
    filename="raw-sign-bit.wat",
  ).unwrap()
  let output = optimize_module_with_pass_flags(
    input,
    ["optimize-instructions"],
    OptimizeOptions::new(),
  ).unwrap()
  @validate.validate_module(output).unwrap()
  let @lib.CodeSec(codes) = output.code_sec.unwrap()
  let @lib.Func(_, @lib.Expr(body)) = codes[0]
  assert_false(body.contains(@lib.Instruction::i32_div_u()))
  assert_true(body.contains(@lib.Instruction::i32_shr_u()))
}

///|
test "command raw sign-bit arithmetic covers both widths" {
  for
    (width, minimum) in [
      ("i32", "-2147483648"),
      ("i64", "-9223372036854775808"),
    ] {
    for op in ["mul", "div_u", "rem_u"] {
      let input = @wast.wast_to_binary_module(
        "(module (func (param \{width}) (result \{width}) i32.const 7 i32.const 0 i32.add drop local.get 0 \{width}.const \{minimum} \{width}.\{op}))",
        filename="raw-sign-bit-width.wat",
      ).unwrap()
      let output = optimize_module_with_pass_flags(
        input,
        ["optimize-instructions"],
        OptimizeOptions::new(),
      ).unwrap()
      @validate.validate_module(output).unwrap()
      let @lib.CodeSec(codes) = output.code_sec.unwrap()
      let @lib.Func(_, @lib.Expr(body)) = codes[0]
      let expected = match (width, op) {
        ("i32", "mul") => @lib.Instruction::i32_shl()
        ("i32", "div_u") => @lib.Instruction::i32_shr_u()
        ("i32", _) => @lib.Instruction::i32_and()
        ("i64", "mul") => @lib.Instruction::i64_shl()
        ("i64", "div_u") => @lib.Instruction::i64_shr_u()
        _ => @lib.Instruction::i64_and()
      }
      assert_true(body.contains(expected))
    }
  }
}
