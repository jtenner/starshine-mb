///|
test "local cse treats continuation execution as a nested reuse barrier" {
  let output = audit_run_module(
    local_cse_stack_switch_barrier_module(),
    "local-cse",
  )
  assert_true(@validate.validate_module(output) is Ok(_))
  let counts : Array[Int] = []
  for idx = 0; idx < 3; idx = idx + 1 {
    counts.push(
      audit_count(audit_body(output, index=idx), fn(instr) {
        instr is @lib.GlobalGet(_)
      }),
    )
  }
  @debug.assert_eq(counts, [2, 2, 2])
}

///|
fn local_cse_stack_switch_read_after(
  prefix : Array[@lib.Instruction],
) -> @lib.Func {
  let nested = prefix.copy()
  nested.append([
    @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
    @lib.Instruction::i32_const(1),
    @lib.Instruction::i32_add(),
  ])
  @lib.Func::new(
    @lib.Locals::empty(),
    @lib.Expr::new([
      @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
      @lib.Instruction::i32_const(1),
      @lib.Instruction::i32_add(),
      @lib.Instruction::drop(),
      @lib.Instruction::block(
        @lib.BlockType::val_type(@lib.ValType::i32()),
        @lib.Expr::new(nested),
      ),
    ]),
  )
}

///|
fn local_cse_stack_switch_barrier_module() -> @lib.Module {
  let suspend_sig = @lib.TypeIdx::new(0U)
  let void_sig = @lib.TypeIdx::new(1U)
  let target_cont = @lib.TypeIdx::new(2U)
  let source_sig = @lib.TypeIdx::new(3U)
  let source_cont = @lib.TypeIdx::new(4U)
  let resume_func_sig = @lib.TypeIdx::new(5U)
  let switch_func_sig = @lib.TypeIdx::new(6U)
  let target_cont_ref = @lib.ValType::ref_null(@lib.HeapType::new(target_cont))
  let source_cont_ref = @lib.ValType::ref_null(@lib.HeapType::new(source_cont))
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
      ),
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::cont(void_sig))),
      @lib.RecType::new(
        @lib.SubType::comp_type(@lib.CompType::func([target_cont_ref], [])),
      ),
      @lib.RecType::new(
        @lib.SubType::comp_type(@lib.CompType::cont(source_sig)),
      ),
      @lib.RecType::new(
        @lib.SubType::comp_type(
          @lib.CompType::func([target_cont_ref], [@lib.ValType::i32()]),
        ),
      ),
      @lib.RecType::new(
        @lib.SubType::comp_type(
          @lib.CompType::func([source_cont_ref], [@lib.ValType::i32()]),
        ),
      ),
    ]),
  )
  .with_func_sec(
    @lib.FuncSec::new([suspend_sig, resume_func_sig, switch_func_sig]),
  )
  .with_tag_sec(
    @lib.TagSec::new([
      @lib.TagType::new(suspend_sig),
      @lib.TagType::new(void_sig),
    ]),
  )
  .with_global_sec(
    @lib.GlobalSec::new([
      @lib.Global::new(
        @lib.GlobalType::new(@lib.ValType::i32(), true),
        @lib.Expr::new([@lib.Instruction::i32_const(0)]),
      ),
    ]),
  )
  .with_code_sec(
    @lib.CodeSec::new([
      local_cse_stack_switch_read_after([
        @lib.Instruction::suspend(@lib.TagIdx::new(0U)),
        @lib.Instruction::drop(),
      ]),
      local_cse_stack_switch_read_after([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::resume_(target_cont, []),
      ]),
      local_cse_stack_switch_read_after([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::stack_switch(source_cont, @lib.TagIdx::new(1U)),
      ]),
    ]),
  )
}
