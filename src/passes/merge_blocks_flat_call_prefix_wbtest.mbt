///|
test "merge-blocks flat call-prefix moves preserve output and original body" {
  let body : Array[@lib.Instruction] = []
  let expected : Array[@lib.Instruction] = []
  for idx in 0..<2 {
    body.push(@lib.Instruction::i32_const(@lib.I32(idx)))
    body.push(@lib.Instruction::i32_const(@lib.I32(idx + 1)))
    body.push(@lib.Instruction::global_set(@lib.GlobalIdx::new(0U)))
    body.push(@lib.Instruction::i32_const(@lib.I32(idx + 2)))
    body.push(@lib.Instruction::call(@lib.FuncIdx::new(0U)))
    expected.push(@lib.Instruction::i32_const(@lib.I32(idx + 1)))
    expected.push(@lib.Instruction::global_set(@lib.GlobalIdx::new(0U)))
    expected.push(@lib.Instruction::i32_const(@lib.I32(idx)))
    expected.push(@lib.Instruction::i32_const(@lib.I32(idx + 2)))
    expected.push(@lib.Instruction::call(@lib.FuncIdx::new(0U)))
  }
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i32()], []),
          ),
        ),
      ]),
    )
    .with_global_sec(
      @lib.GlobalSec::new([
        @lib.Global::new(
          @lib.GlobalType::new(@lib.ValType::i32(), true),
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
        ),
      ]),
    )
    .with_func_sec(
      @lib.FuncSec::new([@lib.TypeIdx::new(1U), @lib.TypeIdx::new(0U)]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body)),
      ]),
    )
  assert_true(@validate.validate_module(input) is Ok(_))
  let output = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["merge-blocks"]) {
    Ok(mod_) => mod_
    Err(err) => fail("merge-blocks flat call-prefix fixture failed: \{err}")
  }
  assert_true(@validate.validate_module(output) is Ok(_))
  match output.code_sec {
    Some(@lib.CodeSec([_, @lib.Func(_, @lib.Expr(after))])) =>
      @debug.assert_eq(after, expected)
    _ => fail("expected two functions after merge-blocks")
  }
  match input.code_sec {
    Some(@lib.CodeSec([_, @lib.Func(_, @lib.Expr(original))])) =>
      @debug.assert_eq(original, body)
    _ => fail("expected original two-function module")
  }
}
