///|
fn ssa_nomerge_continuation_liveness_input() -> @lib.Module {
  let cont_sig = @lib.TypeIdx::new(0U)
  let cont = @lib.TypeIdx::new(1U)
  let tag_sig = @lib.TypeIdx::new(2U)
  let func_sig = @lib.TypeIdx::new(3U)
  let cont_ref = @lib.ValType::ref_null(@lib.HeapType::new(cont))
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::cont(cont_sig)),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
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
            @lib.Instruction::block(
              @lib.BlockType::val_type(cont_ref),
              @lib.Expr::new([
                @lib.Instruction::i32_const(7),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
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
  match @validate.validate_module(input) {
    Ok(_) => input
    Err(err) => abort("invalid SSA continuation-liveness fixture: \{err}")
  }
}

///|
test "raw ssa-nomerge rejects continuation handler liveness" {
  let input = ssa_nomerge_continuation_liveness_input()
  let func = match input.code_sec {
    Some(@lib.CodeSec([func])) => func
    _ => abort("expected one defined function")
  }
  let cont_ref = @lib.ValType::ref_null(
    @lib.HeapType::new(@lib.TypeIdx::new(1U)),
  )
  match
    run_hot_pipeline_raw_ssa_nomerge_structured(
      func,
      @ir.hot_module_context_from_module(input),
      [cont_ref],
    ) {
    None => ()
    Some(rewritten) =>
      fail(
        "continuation handler exits must reject legacy raw SSA rewriting: \{rewritten}",
      )
  }
}
