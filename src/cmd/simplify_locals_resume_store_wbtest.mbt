///|
test "command simplify-locals keeps post-resume write path-specific" {
  let input = simplify_locals_command_resume_store_module()
  assert_true(@validate.validate_module(input) is Ok(_))
  let output = cmd_deep_audit_run_module(input, "simplify-locals")
  assert_true(@validate.validate_module(output) is Ok(_))
  let body = cmd_deep_audit_body(output)
  assert_true(
    body[body.length() - 1] is @lib.LocalGet(@lib.LocalIdx(1U)),
    msg=body.to_string(),
  )
}

///|
fn simplify_locals_command_resume_store_module() -> @lib.Module {
  let cont_sig = @lib.TypeIdx::new(0U)
  let cont = @lib.TypeIdx::new(1U)
  let tag_sig = @lib.TypeIdx::new(2U)
  let func_sig = @lib.TypeIdx::new(3U)
  let cont_ref = @lib.ValType::ref_null(@lib.HeapType::new(cont))
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::comp_type(
          @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
        ),
      ),
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::cont(cont_sig))),
      @lib.RecType::new(
        @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
      ),
      @lib.RecType::new(
        @lib.SubType::comp_type(
          @lib.CompType::func([cont_ref], [@lib.ValType::i32()]),
        ),
      ),
    ]),
  )
  .with_func_sec(@lib.FuncSec::new([func_sig]))
  .with_tag_sec(@lib.TagSec::new([@lib.TagType::new(tag_sig)]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::from_types([@lib.ValType::i32()]),
        @lib.Expr::new([
          @lib.Instruction::i32_const(1),
          @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
          @lib.Instruction::block(
            @lib.BlockType::val_type(cont_ref),
            @lib.Expr::new([
              @lib.Instruction::i32_const(0),
              @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
              @lib.Instruction::resume_(cont, [
                @lib.ResumeHandler::on_label(
                  @lib.TagIdx::new(0U),
                  @lib.LabelIdx::new(0U),
                ),
              ]),
              @lib.Instruction::drop(),
              @lib.Instruction::i32_const(9),
              @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
              @lib.Instruction::ref_null(@lib.HeapType::new(cont)),
            ]),
          ),
          @lib.Instruction::drop(),
          @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        ]),
      ),
    ]),
  )
}
