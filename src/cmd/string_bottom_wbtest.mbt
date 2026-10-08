///|
test "optimize-casts dispatcher folds nullable noextern to nullable string test" {
  let source = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::no_extern())),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([source], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_test(
              true,
              @lib.HeapType::abs(@lib.AbsHeapType::string_()),
            ),
          ]),
        ),
      ]),
    )
  @validate.validate_module(input).unwrap()
  let output = optimize_module_with_pass_flags(
    input,
    ["optimize-casts"],
    OptimizeOptions::new(),
  ).unwrap()
  @validate.validate_module(output).unwrap()
  match output.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(body))])) => {
      for instruction in body {
        assert_false(instruction is @lib.RefTest(_, _, _))
      }
      assert_eq(
        body.get(body.length() - 1),
        Some(@lib.Instruction::i32_const(@lib.I32(1))),
      )
    }
    _ => fail("expected one optimized function")
  }
}
