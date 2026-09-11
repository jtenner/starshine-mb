///|
test "Binaryen 132 waitqueue HOT preserves allocation synchronization and operands" {
  let i32 = @lib.ValType::i32()
  let ti = @lib.TypeIdx::new(0U)
  let receiver = @lib.ValType::ref_null(@lib.HeapType::new(ti))
  let body = [
    @lib.Instruction::waitqueue_new(),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::waitqueue_notify(),
    @lib.Instruction::drop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::waitqueue_new(),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i64_const(@lib.I64(1L)),
    @lib.Instruction::struct_wait(ti, @lib.U32(0U)),
  ]
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::struct_([
              @lib.FieldType::new(
                @lib.StorageType::val_type(i32),
                @lib.Mut::var_(),
              ),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([receiver], [i32])),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::from_types([]), @lib.Expr::new(body)),
      ]),
    )
  let hot = hot_lift_func_with_context_result(
    input,
    @lib.FuncIdx::new(0U),
    hot_module_context_from_module(input),
  ).unwrap()
  hot_verify_core(hot).unwrap()
  let mut count = 0
  for node = 0; node < hot_node_count(hot); node = node + 1 {
    match hot_node_exact_instr(hot, node) {
      Some(@lib.WaitqueueNew) => {
        @debug.assert_eq(hot_child_span(hot, node).length(), 0)
        assert_false(effects_is_pure(effects_for_node(hot, node)))
        count += 1
      }
      Some(@lib.WaitqueueNotify) => {
        @debug.assert_eq(hot_child_span(hot, node).length(), 2)
        assert_true(effects_writes_memory(effects_for_node(hot, node)))
        assert_true((effects_for_node(hot, node) & EFFECT_MASK_SEQ_CST) != 0U)
        count += 1
      }
      Some(@lib.StructWait(_, _)) => {
        @debug.assert_eq(hot_child_span(hot, node).length(), 4)
        assert_true(effects_reads_memory(effects_for_node(hot, node)))
        assert_true((effects_for_node(hot, node) & EFFECT_MASK_SEQ_CST) != 0U)
        assert_true((effects_for_node(hot, node) & EFFECT_MASK_CONTROL) != 0U)
        assert_true(effects_writes_memory(effects_for_node(hot, node)))
        count += 1
      }
      _ => ()
    }
  }
  @debug.assert_eq(count, 4)
  @debug.assert_eq(hot_lower_func_unverified(hot), input.code_sec.unwrap().0[0])
}
