///|
test "parity followup DFE interns live signatures when distinct functions remain" {
  let signature = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([signature, signature]))
    .with_func_sec(
      @lib.FuncSec::new([@lib.TypeIdx::new(0U), @lib.TypeIdx::new(1U)]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::i32_const(7)]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::i32_const(9)]),
        ),
      ]),
    )
  assert_true(@validate.validate_module(input) is Ok(_))
  for public_dispatch in [false, true] {
    let output = if public_dispatch {
      run_hot_pipeline(input, HotPipelineOptions::new(), [
        "duplicate-function-elimination",
      ]).unwrap()
    } else {
      dfe_run_module_pass(input)
    }
    assert_eq(output.type_sec.unwrap().0.length(), 1)
    assert_eq(output.func_sec.unwrap().0, [
      @lib.TypeIdx::new(0U),
      @lib.TypeIdx::new(0U),
    ])
    assert_eq(output.code_sec, input.code_sec)
    assert_true(@validate.validate_module(output) is Ok(_))
    assert_eq(
      @binary.encode_module(output).unwrap().length(),
      @binary.encode_module(input).unwrap().length() - 4,
    )
  }
}

///|
test "parity followup DFE prunes unused plain signatures and remaps function and tag roots" {
  let plain = fn(params) {
    @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func(params, [])))
  }
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        plain([@lib.ValType::f64(), @lib.ValType::f64()]),
        plain([]),
        plain([@lib.ValType::i64()]),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_tag_sec(@lib.TagSec::new([@lib.TagType::new(@lib.TypeIdx::new(2U))]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
      ]),
    )
  assert_true(@validate.validate_module(input) is Ok(_))
  for public_dispatch in [false, true] {
    let output = if public_dispatch {
      run_hot_pipeline(input, HotPipelineOptions::new(), [
        "duplicate-function-elimination",
      ]).unwrap()
    } else {
      dfe_run_module_pass(input)
    }
    assert_eq(output.type_sec.unwrap().0.length(), 2)
    assert_eq(output.func_sec.unwrap().0[0], @lib.TypeIdx::new(0U))
    assert_eq(
      output.tag_sec.unwrap().0[0],
      @lib.TagType::new(@lib.TypeIdx::new(1U)),
    )
    assert_true(@validate.validate_module(output) is Ok(_))
    assert_eq(
      @binary.encode_module(output).unwrap().length(),
      @binary.encode_module(input).unwrap().length() - 5,
    )
  }
}
