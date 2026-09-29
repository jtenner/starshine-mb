///|
test "shared type cleanup preserves opaque custom-section type indices" {
  let input = @lib.Module::new()
    .with_custom_secs([
      @lib.CustomSec::new(@lib.Name::new("reloc.CODE"), b"\x00"),
    ])
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::struct_([]))),
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::nop()]),
        ),
      ]),
    )
  assert_true(@validate.validate_module(input) is Ok(_))
  let output = pass_cleanup_unused_type_groups(input)
  @debug.assert_eq(output.custom_secs, input.custom_secs)
  @debug.assert_eq(output.type_sec, input.type_sec)
}
