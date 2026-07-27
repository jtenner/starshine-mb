///|
test "memory-packing segment-limit guard allows exact wasm maximum only" {
  assert_false(mp_data_segment_limit_exceeded(99999, 1, 0))
  assert_false(mp_data_segment_limit_exceeded(99998, 1, 1))
  assert_true(mp_data_segment_limit_exceeded(99999, 2, 0))
}

///|
fn mp_wbtest_void_type_sec() -> @lib.TypeSec {
  @lib.TypeSec::new([
    @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
  ])
}

///|
fn mp_wbtest_first_func_body(mod_ : @lib.Module) -> Array[@lib.Instruction] {
  match mod_.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(body))])) => body
    _ => abort("expected one function body")
  }
}

///|
fn mp_wbtest_instrs_have_memory_init(instrs : Array[@lib.Instruction]) -> Bool {
  for instr in instrs {
    if instr is @lib.MemoryInit(_, _) {
      return true
    }
  }
  false
}

///|
fn mp_wbtest_assert_active_memory_init_operand_rewrite(
  dest_and_effects : Array[@lib.Instruction],
) -> Unit raise {
  let body = dest_and_effects.copy()
  body.push(@lib.Instruction::i32_const(@lib.I32(0)))
  body.push(@lib.Instruction::i32_const(@lib.I32(1)))
  body.push(
    @lib.Instruction::memory_init(@lib.DataIdx::new(0U), @lib.MemIdx::new(0U)),
  )
  let input = @lib.Module::new()
    .with_type_sec(mp_wbtest_void_type_sec())
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_mem_sec(
      @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, None))]),
    )
    .with_data_sec(
      @lib.DataSec::new([
        @lib.Data::new(
          @lib.DataMode::active(
            @lib.MemIdx::new(0U),
            @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
          ),
          b"\x00\x00\x00\x00",
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body)),
      ]),
    )
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(validate_final_module=false),
      ["memory-packing"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected public memory-packing pipeline success: \{err}")
  }
  let out = mp_wbtest_first_func_body(optimized)
  assert_false(
    mp_wbtest_instrs_have_memory_init(out),
    msg="expected public pipeline operand extraction to remove memory.init",
  )
  match out[out.length() - 1] {
    @lib.Nop | @lib.If(_, _, _) => ()
    other =>
      fail(
        "expected active memory.init to become nop or a bounds check, got \{other}",
      )
  }
}

///|
test "memory-packing operand scanner uses exact validator stack deltas" {
  let heap = @lib.HeapType::abs(@lib.AbsHeapType::any())
  @debug.assert_eq(
    mp_instr_stack_counts(@lib.Instruction::table_set(@lib.TableIdx::new(0U))),
    Some((2, 0)),
  )
  @debug.assert_eq(
    mp_instr_stack_counts(
      @lib.Instruction::array_copy(@lib.TypeIdx::new(0U), @lib.TypeIdx::new(0U)),
    ),
    Some((5, 0)),
  )
  @debug.assert_eq(
    mp_instr_stack_counts(@lib.Instruction::br_on_null(@lib.LabelIdx::new(0U))),
    Some((1, 1)),
  )
  @debug.assert_eq(
    mp_instr_stack_counts(@lib.Instruction::ref_test_desc(false, heap)),
    Some((2, 1)),
  )
  @debug.assert_eq(
    mp_instr_stack_counts(@lib.Instruction::ref_cast_desc_eq(false, heap)),
    Some((2, 1)),
  )
}

///|
test "memory-packing public pipeline rewrites active memory.init across corrected stack effects" {
  let heap = @lib.HeapType::abs(@lib.AbsHeapType::any())
  mp_wbtest_assert_active_memory_init_operand_rewrite([
    @lib.Instruction::i32_const(@lib.I32(9)),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::ref_null(heap),
    @lib.Instruction::table_set(@lib.TableIdx::new(0U)),
  ])
  mp_wbtest_assert_active_memory_init_operand_rewrite([
    @lib.Instruction::i32_const(@lib.I32(9)),
    @lib.Instruction::ref_null(heap),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::ref_null(heap),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::array_copy(@lib.TypeIdx::new(0U), @lib.TypeIdx::new(0U)),
  ])
  mp_wbtest_assert_active_memory_init_operand_rewrite([
    @lib.Instruction::i32_const(@lib.I32(9)),
    @lib.Instruction::ref_null(heap),
    @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
    @lib.Instruction::drop(),
  ])
  mp_wbtest_assert_active_memory_init_operand_rewrite([
    @lib.Instruction::i32_const(@lib.I32(9)),
    @lib.Instruction::ref_null(heap),
    @lib.Instruction::ref_null(heap),
    @lib.Instruction::ref_test_desc(false, heap),
    @lib.Instruction::drop(),
  ])
  mp_wbtest_assert_active_memory_init_operand_rewrite([
    @lib.Instruction::i32_const(@lib.I32(9)),
    @lib.Instruction::ref_null(heap),
    @lib.Instruction::ref_null(heap),
    @lib.Instruction::ref_cast_desc_eq(false, heap),
    @lib.Instruction::drop(),
  ])
}
