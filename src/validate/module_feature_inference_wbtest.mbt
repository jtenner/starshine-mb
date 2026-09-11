///|
test "module allocation inference preserves ordinary and exact reference targets" {
  for exact in [false, true] {
    let result = @lib.ValType::ref_type(
      @lib.RefType::new(
        false,
        @lib.HeapType::new(@lib.TypeIdx::new(0U)),
        exact~,
      ),
    )
    let input = @lib.Module::new()
      .with_type_sec(
        @lib.TypeSec::new([
          @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::struct_([]))),
          @lib.RecType::new(
            @lib.SubType::comp_type(@lib.CompType::func([], [result])),
          ),
        ]),
      )
      .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
      .with_code_sec(
        @lib.CodeSec::new([
          @lib.Func::new(
            @lib.Locals::from_types([]),
            @lib.Expr::new([
              @lib.Instruction::struct_new_default(@lib.TypeIdx::new(0U)),
            ]),
          ),
        ]),
      )
    @debug.assert_eq(@lib.module_uses_custom_descriptors(input), exact)
    ignore(validate_module(input).unwrap())
    let env = empty_env().with_module(input)
    let state = Typecheck::typecheck(
      @lib.Instruction::struct_new_default(@lib.TypeIdx::new(0U)),
      tc_state_new(env, [], true, NoTcEscape),
    ).unwrap()
    @debug.assert_eq(state.stack, [result])
  }
}
