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

///|
test "shared type cleanup scans module roots once across 256 groups" {
  let groups : Array[@lib.RecType] = []
  for _ in 0..<255 {
    groups.push(
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::struct_([]))),
    )
  }
  groups.push(
    @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
  )
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new(groups))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(255U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
      ]),
    )
  let root_scans = [0]
  let output = pass_cleanup_unused_type_groups(
    input,
    root_scans=Some(root_scans),
  )
  assert_eq(root_scans[0], 1)
  match output.type_sec {
    Some(@lib.TypeSec(kept)) => assert_eq(kept.length(), 1)
    None => fail("expected retained function type")
  }
  assert_eq(output.func_sec, Some(@lib.FuncSec::new([@lib.TypeIdx::new(0U)])))
  assert_true(@validate.validate_module(output) is Ok(_))
}
